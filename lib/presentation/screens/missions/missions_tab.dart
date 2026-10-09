import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/mission.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import 'mission_card.dart';
import 'mission_detail_screen.dart';
import 'mission_form_screen.dart';

class MissionsTab extends ConsumerWidget {
  const MissionsTab({super.key, this.onScanRequested});

  /// Para presentadores, cuyo botón flotante muestra el QR en lugar de escanear.
  final VoidCallback? onScanRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final missions = ref.watch(visibleMissionsProvider);
    final owned = ref.watch(ownedMissionIdsProvider);
    final now = ref.watch(clockProvider)();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(missionsProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              child: PageHeader(
                title: 'Misiones',
                subtitle: 'Proyectos de intercesión programados para nuestros cultos.',
                trailing: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (role.isAdmin)
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionFormScreen())),
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Crear misión'),
                      ),
                    if (role.canPresentQr && onScanRequested != null)
                      OutlinedButton.icon(
                        onPressed: onScanRequested,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Escanear un sello'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          missions.when(
            skipLoadingOnReload: true,
            loading: () => const SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(error: error, onRetry: () => ref.invalidate(missionsProvider)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.travel_explore_rounded,
                    title: 'No hay misiones programadas',
                    message: 'Pronto se anunciarán nuevas misiones.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 120),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final mission = list[index];
                    return ResponsiveCenter(
                      child: MissionCard(
                        mission: mission,
                        now: now,
                        owned: owned.contains(mission.id),
                        onTap: () => _openDetail(context, mission),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Mission mission) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MissionDetailScreen(missionId: mission.id)));
  }
}
