import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/text_utils.dart';
import '../../domain/models/auth_identity.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../firebase_error_mapper.dart';

/// Los usuarios inician sesión con un nombre de usuario; internamente se usa un
/// correo ficticio `usuario@cmo.com` (formato heredado, no se puede cambiar sin
/// migrar cuentas).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._functions);

  static const internalDomain = '@cmo.com';
  static final _usernamePattern = RegExp(r'^[a-z0-9._-]{3,30}$');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final Map<String, UserRole> _lastKnownRoles = {};

  /// Compatibilidad: la app siempre eliminó los espacios de la contraseña.
  static String normalizePassword(String raw) => raw.replaceAll(' ', '');

  @override
  AuthIdentity? get currentIdentity {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthIdentity(uid: user.uid, username: _usernameOf(user), role: _lastKnownRoles[user.uid] ?? UserRole.user);
  }

  @override
  Stream<AuthIdentity?> watchIdentity() => _auth.idTokenChanges().asyncMap(_toIdentity);

  Future<AuthIdentity?> _toIdentity(User? user) async {
    if (user == null) return null;
    UserRole role;
    try {
      final token = await user.getIdTokenResult();
      role = UserRole.fromClaim(token.claims?['role']);
      _lastKnownRoles[user.uid] = role;
    } catch (error) {
      // Sin conexión con un token vencido: se conserva el último rol conocido.
      debugPrint('No se pudo leer el rol: $error');
      role = _lastKnownRoles[user.uid] ?? UserRole.user;
    }
    return AuthIdentity(uid: user.uid, username: _usernameOf(user), role: role);
  }

  String _usernameOf(User user) => (user.email ?? '').split('@').first;

  @override
  Future<String?> login(String username, String password) async {
    final clean = normalizeUsername(username);
    if (clean.isEmpty) return 'Escribe tu nombre de usuario.';
    try {
      await _auth.signInWithEmailAndPassword(email: '$clean$internalDomain', password: normalizePassword(password));
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'network-request-failed' => const NetworkException().message,
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
        'user-disabled' => 'Esta cuenta está desactivada. Escríbenos por WhatsApp para ayudarte.',
        _ => 'Usuario o contraseña incorrectos.',
      };
    } catch (_) {
      return const UnknownException().message;
    }
  }

  @override
  Future<String?> register(String username, String password) async {
    final clean = normalizeUsername(username);
    if (!_usernamePattern.hasMatch(clean)) {
      return 'El usuario debe tener de 3 a 30 caracteres: letras, números, punto, guion o guion bajo.';
    }
    final cleanPassword = normalizePassword(password);
    if (cleanPassword.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';
    try {
      await _auth.createUserWithEmailAndPassword(email: '$clean$internalDomain', password: cleanPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' => 'Este nombre de usuario ya está en uso. Prueba con otro.',
        'weak-password' => 'La contraseña es muy débil. Usa al menos 6 caracteres.',
        'invalid-email' => 'El nombre de usuario tiene caracteres no permitidos.',
        'network-request-failed' => const NetworkException().message,
        _ => 'No se pudo crear la cuenta. Inténtalo de nuevo.',
      };
    } catch (_) {
      return const UnknownException().message;
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  @override
  Future<void> refreshClaims() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (error) {
      debugPrint('No se pudo refrescar el token: $error');
    }
  }

  @override
  Future<PasswordRecoveryResult> recoverWithCode({
    required String username,
    required String code,
    required String newPassword,
  }) {
    return guardFirebase(() async {
      final result = await _functions.httpsCallable('redeemRecoveryCode').call<Object?>({
        'username': normalizeUsername(username),
        'code': code.trim(),
        'newPassword': normalizePassword(newPassword),
      });
      final data = result.data;
      final status = data is Map ? data['status'] : null;
      return switch (status) {
        'ok' => PasswordRecoveryResult.success,
        'weakPassword' => PasswordRecoveryResult.weakPassword,
        _ => PasswordRecoveryResult.invalidCode,
      };
    });
  }
}
