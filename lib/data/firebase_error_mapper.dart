import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';

/// Traduce errores de Firebase a excepciones de dominio con mensajes amigables.
AppException mapFirebaseError(Object error) {
  if (error is AppException) return error;
  if (error is TimeoutException) return const NetworkException();

  if (error is FirebaseFunctionsException) {
    final serverMessage = error.message;
    return switch (error.code) {
      'unavailable' ||
      'deadline-exceeded' ||
      'internal' when _looksLikeNetwork(serverMessage) => const NetworkException(),
      'unavailable' || 'deadline-exceeded' => const NetworkException(),
      'unauthenticated' => const UnauthenticatedException(),
      'permission-denied' => const PermissionDeniedException(),
      'not-found' => const NotFoundException(),
      'invalid-argument' ||
      'failed-precondition' => ValidationException(_safeServerMessage(serverMessage), field: _fieldFrom(error.details)),
      _ => const UnknownException(),
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' || 'network-request-failed' || 'deadline-exceeded' => const NetworkException(),
      'permission-denied' || 'unauthorized' => const PermissionDeniedException(),
      'unauthenticated' || 'unauthenticated-user' => const UnauthenticatedException(),
      'not-found' || 'object-not-found' => const NotFoundException(),
      _ => const UnknownException(),
    };
  }

  debugPrint('Error no controlado: $error');
  return const UnknownException();
}

bool _looksLikeNetwork(String? message) {
  final text = (message ?? '').toLowerCase();
  return text.contains('network') || text.contains('failed to fetch') || text.contains('socket');
}

/// Los mensajes de `invalid-argument` del servidor están escritos en español
/// para el usuario; si no hay mensaje se usa uno genérico.
String _safeServerMessage(String? message) {
  final text = message?.trim() ?? '';
  if (text.isEmpty || text.length > 200 || text.toUpperCase() == text) {
    return 'Algunos datos no son válidos. Revisa el formulario.';
  }
  return text;
}

String? _fieldFrom(Object? details) {
  if (details is Map && details['field'] is String) return details['field'] as String;
  return null;
}

/// Ejecuta [action] y convierte cualquier error en [AppException].
Future<T> guardFirebase<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw mapFirebaseError(error);
  }
}
