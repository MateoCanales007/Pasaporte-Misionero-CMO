import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/mission.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/common_widgets.dart';

/// Etiqueta de estado de una misión, con ícono y texto (no solo color).
Widget missionPhaseChip(MissionPhase phase) => switch (phase) {
  MissionPhase.open => StatusChip.success(phase.label, icon: Icons.radio_button_checked_rounded),
  MissionPhase.upcoming => StatusChip.info(phase.label, icon: Icons.event_rounded),
  MissionPhase.finished => StatusChip.neutral(phase.label, icon: Icons.event_available_rounded),
  MissionPhase.inactive => StatusChip.neutral(phase.label, icon: Icons.pause_circle_rounded),
  MissionPhase.draft => StatusChip.warning(phase.label, icon: Icons.edit_note_rounded),
};

/// Texto de la próxima cita o de la última fecha.
String missionDateText(Mission mission, DateTime now) {
  final next = mission.nextWindow(now);
  if (next != null) {
    return next.contains(now)
        ? 'Abierta hasta las ${BusinessTime.formatTime(next.end)}'
        : 'Próxima cita: ${BusinessTime.formatDateTime(next.start)}';
  }
  final last = mission.sortedSchedules.lastOrNull;
  return last == null ? 'Fecha por definir' : 'Fue el ${BusinessTime.formatLongDate(last.start)}';
}

class MissionCard extends StatelessWidget {
  const MissionCard({super.key, required this.mission, required this.now, this.owned = false, this.onTap});

  final Mission mission;
  final DateTime now;
  final bool owned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = mission.phaseAt(now);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: mission.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.navy,
                          child: const Icon(Icons.public_rounded, size: 64, color: Colors.white24),
                        )
                      : AppNetworkImage(url: mission.imageUrl, fallbackIcon: Icons.public_rounded),
                ),
                Positioned(top: AppSpacing.sm, right: AppSpacing.sm, child: missionPhaseChip(phase)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(mission.name, style: theme.textTheme.titleLarge)),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.goldDark, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          mission.isoCode,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(missionDateText(mission, now), style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                  if (owned) ...[
                    const SizedBox(height: AppSpacing.sm),
                    StatusChip.success('Ya tienes este sello', icon: Icons.verified_rounded),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
