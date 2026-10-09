import 'package:intl/intl.dart';

/// Hora de negocio de la iglesia: `America/El_Salvador` (UTC−6, sin horario de
/// verano). Los instantes se guardan siempre en UTC; esta clase solo convierte
/// para mostrar y capturar fechas, sin depender de la zona del teléfono.
abstract final class BusinessTime {
  static const zoneName = 'America/El_Salvador';
  static const zoneLabel = 'Hora de El Salvador';
  static const Duration utcOffset = Duration(hours: -6);

  /// Fecha/hora "de pared" en El Salvador para un instante. El resultado se
  /// representa como DateTime UTC cuyos campos son la hora local de negocio.
  static DateTime toWallClock(DateTime instant) => instant.toUtc().add(utcOffset);

  /// Instante (UTC) correspondiente a una fecha/hora de pared de El Salvador.
  static DateTime fromWallClock(int year, int month, int day, [int hour = 0, int minute = 0]) {
    return DateTime.utc(year, month, day, hour, minute).subtract(utcOffset);
  }

  /// "domingo 12 de octubre de 2026"
  static String formatLongDate(DateTime instant) =>
      DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(toWallClock(instant));

  /// "12 oct 2026"
  static String formatShortDate(DateTime instant) => DateFormat('d MMM y', 'es').format(toWallClock(instant));

  /// "7:30 p. m."
  static String formatTime(DateTime instant) => DateFormat('h:mm a', 'es').format(toWallClock(instant));

  /// "domingo 12 de octubre, 7:30 p. m."
  static String formatDateTime(DateTime instant) =>
      '${DateFormat("EEEE d 'de' MMMM", 'es').format(toWallClock(instant))}, ${formatTime(instant)}';

  /// "12/10/2026 19:30"
  static String formatCompact(DateTime instant) => DateFormat('dd/MM/y HH:mm', 'es').format(toWallClock(instant));
}
