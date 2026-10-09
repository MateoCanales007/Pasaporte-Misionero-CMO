import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/public_profile.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import 'testimonials_view.dart';
import 'user_detail_screen.dart';

enum _CommunitySection { missionaries, testimonials }

class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});

  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  _CommunitySection _section = _CommunitySection.missionaries;

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingTestimonialsProvider).value?.length ?? 0;
    // El encabezado se desplaza junto con la lista para dejar espacio con letra grande.
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: ResponsiveCenter(
            child: PageHeader(
              title: 'Comunidad Oasis',
              subtitle: 'Misioneros que comparten su recorrido y sus testimonios.',
              trailing: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_CommunitySection>(
                  segments: [
                    const ButtonSegment(
                      value: _CommunitySection.missionaries,
                      label: Text('Misioneros'),
                      icon: Icon(Icons.groups_rounded),
                    ),
                    ButtonSegment(
                      value: _CommunitySection.testimonials,
                      label: Text(pendingCount > 0 ? 'Testimonios ($pendingCount)' : 'Testimonios'),
                      icon: const Icon(Icons.forum_rounded),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) => setState(() => _section = value.first),
                ),
              ),
            ),
          ),
        ),
      ],
      body: _section == _CommunitySection.missionaries ? const _MissionariesList() : const TestimonialsView(),
    );
  }
}

class _MissionariesList extends ConsumerWidget {
  const _MissionariesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final myUid = ref.watch(currentUidProvider);
    return AsyncValueView<List<PublicProfile>>(
      value: ref.watch(communityProfilesProvider),
      onRetry: () => ref.invalidate(communityProfilesProvider),
      isEmpty: (list) => list.isEmpty,
      empty: const EmptyView(
        icon: Icons.groups_outlined,
        title: 'Aún no hay misioneros visibles',
        message: 'Cuando otros misioneros elijan aparecer en Comunidad, los verás aquí.',
      ),
      data: (profiles) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          return ResponsiveCenter(
            child: _ProfileCard(
              profile: profile,
              isMe: profile.uid == myUid,
              showHiddenBadge: isAdmin && !profile.communityVisible,
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.isMe, required this.showHiddenBadge});

  final PublicProfile profile;
  final bool isMe;
  final bool showHiddenBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (profile.cellName != null) 'Célula: ${profile.cellName}',
      if (profile.nationality != null) profile.nationality!,
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(profile: profile))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              InitialsAvatar(initials: profile.initials),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '${profile.displayName} (tú)' : profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.navy),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(details, style: theme.textTheme.bodySmall),
                    ],
                    if (showHiddenBadge) ...[
                      const SizedBox(height: AppSpacing.xs),
                      StatusChip.neutral('Oculto en Comunidad', icon: Icons.visibility_off_rounded),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label: '${profile.stampCount} sellos',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: profile.stampCount > 0 ? AppColors.warningSurface : AppColors.neutralSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.approval_rounded,
                        size: 22,
                        color: profile.stampCount > 0 ? AppColors.brown : AppColors.neutral,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.stampCount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: profile.stampCount > 0 ? AppColors.brown : AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
