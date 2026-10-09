import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';

/// Lectura tolerante pero honesta de documentos: los campos opcionales usan
/// valores por defecto; los obligatorios dañados lanzan [DataParseException].
/// Nunca se reemplaza una fecha dañada con la fecha actual.
abstract final class FirestoreParsers {
  /// Acepta `Timestamp`, `DateTime`, texto ISO-8601 o milisegundos.
  static DateTime? optionalDate(Object? value) {
    return switch (value) {
      Timestamp() => value.toDate(),
      DateTime() => value,
      String() => DateTime.tryParse(value),
      int() => DateTime.fromMillisecondsSinceEpoch(value),
      _ => null,
    };
  }

  static DateTime requiredDate(Object? value, String field) {
    final date = optionalDate(value);
    if (date == null) throw DataParseException('Fecha inválida en "$field": $value');
    return date;
  }

  static String requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) return value;
    throw DataParseException('Texto obligatorio ausente en "$field"');
  }

  static String string(Object? value, {String fallback = ''}) => value is String ? value : fallback;

  static String? optionalString(Object? value) => value is String && value.isNotEmpty ? value : null;

  static bool boolean(Object? value, {required bool fallback}) => value is bool ? value : fallback;

  static int integer(Object? value, {int fallback = 0}) => value is num ? value.toInt() : fallback;

  static int? optionalInt(Object? value) => value is num ? value.toInt() : null;

  static List<String> stringList(Object? value) =>
      value is List ? value.whereType<String>().toList(growable: false) : const [];

  static Map<String, Object?> map(Object? value) =>
      value is Map ? value.map((key, v) => MapEntry(key.toString(), v)) : const {};
}
