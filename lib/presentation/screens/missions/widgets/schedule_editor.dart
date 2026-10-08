import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../domain/models/mission.dart';
import '../../../../domain/use_cases/validate_mission_schedules.dart';

/// Pide fecha y hora (de El Salvador) y devuelve el instante UTC.
Future<DateTime?> pickBusinessDateTime(BuildContext context, {required DateTime initial, required String title}) async {
  final wall = BusinessTime.toWallClock(initial);
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(wall.year, wall.month, wall.day),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    helpText: '$title — fecha',
    cancelText: 'Cancelar',
    confirmText: 'Siguiente',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: wall.hour, minute: wall.minute),
    helpText: '$title — hora (${BusinessTime.zoneLabel})',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
  if (time == null) return null;
  return BusinessTime.fromWallClock(date.year, date.month, date.day, time.hour, time.minute);
}

/// Lista editable de ventanas de horario con validación inmediata.
class ScheduleEditor extends StatelessWidget {
  const ScheduleEditor({
    super.key,
    required this.schedules,
    required this.issues,
    required this.onChanged,
    required this.now,
  });

  final List<MissionSchedule> schedules;
  final List<ScheduleIssue> issues;
  final ValueChanged<List<MissionSchedule>> onChanged;
  final DateTime now;

  Future<void> _edit(BuildContext context, int index, {required bool start}) async {
    final current = schedules[index];
    final picked = await pickBusinessDateTime(
      context,
      initial: start ? current.start : current.end,
      title: start ? 'Inicio del horario ${index + 1}' : 'Fin del horario ${index + 1}',
    );
    if (picked == null) return;
    final updated = [...schedules];
    var schedule = start ? current.copyWith(start: picked) : current.copyWith(end: picked);
    // Al mover el inicio se conserva la duración para evitar errores comunes.
    if (start && !schedule.isValid) {
      schedule = schedule.copyWith(end: picked.add(current.end.difference(current.start)));
    }
    updated[index] = schedule;
    onChanged(updated);
  }

  /// Agrega una ventana: la primera en la próxima hora; las siguientes, una
  /// semana después de la última (lo habitual para cultos semanales).
  void _add() {
    if (schedules.isEmpty) {
      final start = defaultScheduleStart(now);
      onChanged([MissionSchedule(start: start, end: start.add(const Duration(hours: 3)))]);
      return;
    }
    final last = schedules.last;
    const week = Duration(days: 7);
    onChanged([...schedules, MissionSchedule(start: last.start.add(week), end: last.end.add(week))]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generalIssues = issues.where((i) => i.index < 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Todas las horas son en hora de El Salvador.', style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < schedules.length; i++)
          _ScheduleCard(
            index: i,
            schedule: schedules[i],
            issues: issues.where((issue) => issue.index == i).map((issue) => issue.message).toList(),
            onEditStart: () => _edit(context, i, start: true),
            onEditEnd: () => _edit(context, i, start: false),
            onRemove: () => onChanged([...schedules]..removeAt(i)),
          ),
        for (final issue in generalIssues)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(issue.message, style: const TextStyle(color: AppColors.error, fontSize: 16)),
          ),
        OutlinedButton.icon(
          onPressed: schedules.length >= ValidateMissionSchedules.maxWindows ? null : _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar horario'),
        ),
      ],
    );
  }
}

/// Próxima hora en punto (hora de El Salvador), como inicio sugerido.
DateTime defaultScheduleStart(DateTime now) {
  final wall = BusinessTime.toWallClock(now);
  return BusinessTime.fromWallClock(wall.year, wall.month, wall.day, wall.hour).add(const Duration(hours: 1));
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.index,
    required this.schedule,
    required this.issues,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onRemove,
  });

  final int index;
  final MissionSchedule schedule;
  final List<String> issues;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasIssues = issues.isNotEmpty;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(color: hasIssues ? AppColors.error : AppColors.border, width: hasIssues ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Horario ${index + 1}', style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Quitar'),
                ),
              ],
            ),
            _DateRow(label: 'Inicio', value: BusinessTime.formatDateTime(schedule.start), onPressed: onEditStart),
            const SizedBox(height: AppSpacing.sm),
            _DateRow(label: 'Fin', value: BusinessTime.formatDateTime(schedule.end), onPressed: onEditEnd),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.error_rounded, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(issue, style: const TextStyle(color: AppColors.error, fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value, required this.onPressed});

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value. Toca para cambiar.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    Text(value, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}
