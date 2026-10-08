import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../domain/models/stamp_redemption.dart';
import '../../../providers/content_providers.dart';
import '../../../widgets/app_network_image.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/state_views.dart';

/// Lista de sellos confirmados por el servidor.
class StampList extends StatelessWidget {
  const StampList({
    super.key,
    required this.stamps,
    this.onRetry,
    this.emptyMessage,
    this.showDates = true,
    this.title = 'Mis sellos',
    this.emptyTitle = 'Tu pasaporte está nuevo',
    this.showTitle = true,
  });

  final AsyncValue<List<StampRedemption>> stamps;
  final VoidCallback? onRetry;
  final String? emptyMessage;

  /// En perfiles ajenos no se conocen las fechas (no son públicas).
  final bool showDates;
  final String title;
  final String emptyTitle;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) SectionTitle(title, icon: Icons.approval_rounded),
        AsyncValueView<List<StampRedemption>>(
          value: stamps,
          onRetry: onRetry,
          isEmpty: (list) => list.isEmpty,
          empty: EmptyView(
            icon: Icons.flight_takeoff_rounded,
            title: emptyTitle,
            message: emptyMessage ?? 'Escanea tu primer sello en el culto con el botón "Escanear sello".',
          ),
          data: (list) => Column(
            children: [
              for (final stamp in list) ...[
                StampTile(stamp: stamp, showDate: showDates),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class StampTile extends ConsumerWidget {
  const StampTile({super.key, required this.stamp, this.showDate = true});

  final StampRedemption stamp;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(missionCatalogProvider)[stamp.missionId];
    final name = mission?.name ?? stamp.missionName ?? 'Proyecto misionero';
    final date = stamp.redeemedAt == null ? 'Fecha no disponible' : BusinessTime.formatLongDate(stamp.redeemedAt!);
    final theme = Theme.of(context);

    return Card(
      child: Semantics(
        label: showDate ? 'Sello de $name, obtenido el $date. Confirmado.' : 'Sello de $name.',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: AppNetworkImage(
                  url: mission?.imageUrl ?? '',
                  width: 72,
                  height: 72,
                  fallbackIcon: Icons.flight_land_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.navy)),
                    if (showDate) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(date, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded, color: AppColors.gold, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
