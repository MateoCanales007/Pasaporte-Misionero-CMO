import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/models/achievement.dart';
import '../../../providers/content_providers.dart';
import '../../../widgets/common_widgets.dart';

/// Progreso personal: misiones completadas e insignias. Sin rankings.
class AchievementsSection extends ConsumerWidget {
  const AchievementsSection({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamps = ref.watch(passportStampsProvider).value;
    if (stamps == null) return const SizedBox.shrink();
    final achievements = ref.watch(achievementsProvider);
    final unlocked = achievements.where((a) => a.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) const SectionTitle('Mi progreso', icon: Icons.emoji_events_rounded),
        if (!showTitle) const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _Stat(
                  value: '${stamps.length}',
                  label: stamps.length == 1 ? 'misión completada' : 'misiones completadas',
                ),
                const SizedBox(width: AppSpacing.md),
                _Stat(value: '$unlocked', label: unlocked == 1 ? 'insignia ganada' : 'insignias ganadas'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Cuadrícula vertical (sin desplazamiento lateral, más fácil de usar).
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            final width = (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final achievement in achievements)
                  SizedBox(
                    width: width,
                    child: _AchievementCard(achievement: achievement),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.navy),
            ),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final theme = Theme.of(context);
    return Semantics(
      label:
          '${achievement.title}. ${achievement.description} '
          '${unlocked ? 'Conseguida.' : 'Progreso ${achievement.current} de ${achievement.target}.'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unlocked ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: unlocked ? AppColors.gold : AppColors.border, width: unlocked ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              achievement.isChallenge ? Icons.flag_circle_rounded : Icons.workspace_premium_rounded,
              color: unlocked ? AppColors.gold : AppColors.textSecondary,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              achievement.title,
              style: theme.textTheme.titleSmall?.copyWith(color: unlocked ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (unlocked)
              const Text(
                '¡Conseguida!',
                style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
              )
            else ...[
              Text(
                '${achievement.current.clamp(0, achievement.target)} de ${achievement.target}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  minHeight: 8,
                  backgroundColor: AppColors.neutralSurface,
                  color: AppColors.amber,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
