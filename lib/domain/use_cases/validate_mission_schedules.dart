import '../models/mission.dart';

/// Problema detectado en una ventana de horario.
class ScheduleIssue {
  const ScheduleIssue(this.index, this.message);

  /// Índice de la ventana en la lista original.
  final int index;
  final String message;
}

/// Reglas de negocio del formulario de misiones. El servidor aplica las mismas
/// validaciones; aquí se usan para dar respuesta inmediata al administrador.
abstract final class ValidateMissionSchedules {
  static const maxWindows = 20;

  static List<ScheduleIssue> call(List<MissionSchedule> schedules, {required bool requireAtLeastOne}) {
    final issues = <ScheduleIssue>[];
    if (schedules.isEmpty && requireAtLeastOne) {
      issues.add(const ScheduleIssue(-1, 'Agrega al menos un horario para poder activar la misión.'));
    }
    if (schedules.length > maxWindows) {
      issues.add(const ScheduleIssue(-1, 'Puedes agregar como máximo $maxWindows horarios.'));
    }
    for (var i = 0; i < schedules.length; i++) {
      if (!schedules[i].isValid) {
        issues.add(ScheduleIssue(i, 'La hora de inicio debe ser anterior a la hora de fin.'));
      }
    }
    for (var i = 0; i < schedules.length; i++) {
      for (var j = i + 1; j < schedules.length; j++) {
        if (schedules[i].isValid && schedules[j].isValid && schedules[i].overlaps(schedules[j])) {
          issues.add(ScheduleIssue(j, 'Este horario se cruza con el horario ${i + 1}.'));
        }
      }
    }
    return issues;
  }
}
