import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/mission.dart';
import '../../../domain/models/service_photo.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/map_view.dart';
import '../../widgets/service_photos/service_photos_section.dart';
import '../../widgets/state_views.dart';
import '../journal/journal_entry_screen.dart';
import 'mission_card.dart';
import 'mission_form_screen.dart';

class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({super.key, required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionsProvider);
    final mission = ref.watch(missionCatalogProvider)[missionId];
    if (mission == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Misión')),
        body: missions.isLoading
            ? const LoadingView()
            : const EmptyView(icon: Icons.search_off_rounded, title: 'Esta misión ya no está disponible'),
      );
    }
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final owned = ref.watch(ownedMissionIdsProvider).contains(mission.id);
    final now = ref.watch(clockProvider)();
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            title: Text(mission.isoCode),
            flexibleSpace: FlexibleSpaceBar(
              background: mission.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.navy,
                      child: const Icon(Icons.public_rounded, size: 80, color: Colors.white24),
                    )
                  : AppNetworkImage(url: mission.imageUrl, semanticLabel: 'Imagen de ${mission.name}'),
            ),
          ),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        missionPhaseChip(mission.phaseAt(now)),
                        if (owned) StatusChip.success('Ya tienes este sello', icon: Icons.verified_rounded),
                      ],
                    ),
                    if (isAdmin) _AdminActions(mission: mission),
                    const SectionTitle('Horarios', icon: Icons.schedule_rounded),
                    _ScheduleList(mission: mission, now: now),
                    const SectionTitle('Mi diario', icon: Icons.edit_note_rounded),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JournalEntryScreen(missionId: mission.id, missionName: mission.name),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Escribir una reflexión'),
                    ),
                    if (mission.location != null) ...[
                      const SectionTitle('Ubicación', icon: Icons.place_rounded),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        child: SizedBox(
                          height: 240,
                          child: ref.watch(mapViewBuilderProvider)(
                            marker: mission.location,
                            center: mission.location!,
                            zoom: 11,
                          ),
                        ),
                      ),
                      _PlacePhotos(mission: mission),
                    ],
                    ServicePhotosSection(album: PhotoAlbum.mission(mission.id)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.mission, required this.now});

  final Mission mission;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final schedules = mission.sortedSchedules;
    if (schedules.isEmpty) {
      return const Text('Fecha por definir.');
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(BusinessTime.zoneLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        for (final schedule in schedules)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: Icon(
                schedule.contains(now) ? Icons.radio_button_checked_rounded : Icons.event_rounded,
                color: schedule.contains(now) ? AppColors.success : AppColors.navy,
                size: 30,
              ),
              title: Text(BusinessTime.formatLongDate(schedule.start)),
              subtitle: Text(
                'De ${BusinessTime.formatTime(schedule.start)} a ${BusinessTime.formatDateTime(schedule.end)}',
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminActions extends ConsumerStatefulWidget {
  const _AdminActions({required this.mission});

  final Mission mission;

  @override
  ConsumerState<_AdminActions> createState() => _AdminActionsState();
}

class _AdminActionsState extends ConsumerState<_AdminActions> {
  bool _busy = false;

  Future<void> _toggleStatus() async {
    final mission = widget.mission;
    final activate = mission.status != MissionStatus.active;
    final confirmed = await showConfirmDialog(
      context,
      title: activate ? '¿Activar la misión?' : '¿Desactivar la misión?',
      message: activate
          ? 'Los presentadores podrán mostrar el código QR durante sus horarios.'
          : 'Nadie podrá obtener este sello mientras esté desactivada.',
      confirmLabel: activate ? 'Activar' : 'Desactivar',
      destructive: !activate,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(missionRepositoryProvider)
          .setMissionStatus(mission.id, activate ? MissionStatus.active : MissionStatus.inactive);
      if (mounted) {
        showAppSnackBar(context, activate ? 'Misión activada.' : 'Misión desactivada.', type: SnackType.success);
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Opciones de administrador', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MissionFormScreen(initial: mission)),
                      ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar misión'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggleStatus,
                icon: Icon(mission.status == MissionStatus.active ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(mission.status == MissionStatus.active ? 'Desactivar' : 'Activar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MissionFormScreen(initial: mission, duplicate: true)),
                      ),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Duplicar como borrador'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacePhotos extends ConsumerStatefulWidget {
  const _PlacePhotos({required this.mission});

  final Mission mission;

  @override
  ConsumerState<_PlacePhotos> createState() => _PlacePhotosState();
}

class _PlacePhotosState extends ConsumerState<_PlacePhotos> {
  late final Future<List<String>> _references = ref
      .read(placesRepositoryProvider)
      .photoReferences(placeId: widget.mission.placeId, near: widget.mission.location);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _references,
      builder: (context, snapshot) {
        final refs = snapshot.data ?? const [];
        if (snapshot.connectionState != ConnectionState.done || refs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Fotos del lugar', icon: Icons.photo_library_rounded),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: refs.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, index) => _PlacePhoto(reference: refs[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlacePhoto extends ConsumerStatefulWidget {
  const _PlacePhoto({required this.reference});

  final String reference;

  @override
  ConsumerState<_PlacePhoto> createState() => _PlacePhotoState();
}

class _PlacePhotoState extends ConsumerState<_PlacePhoto> {
  late final Future<Uint8List> _bytes = ref.read(placesRepositoryProvider).photo(widget.reference);

  void _openFullScreen(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: ClipRRect(borderRadius: BorderRadius.circular(AppSpacing.radius), child: Image.memory(bytes)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: IconButton.filled(
                tooltip: 'Cerrar foto',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(52, 52)),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Semantics(
          button: bytes != null,
          label: 'Foto del lugar. Toca para ampliar.',
          child: GestureDetector(
            onTap: bytes == null ? null : () => _openFullScreen(bytes),
            child: Container(
              width: 170,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Center(
                      child: snapshot.hasError
                          ? const Icon(Icons.broken_image_rounded, color: AppColors.textSecondary)
                          : const CircularProgressIndicator(),
                    ),
            ),
          ),
        );
      },
    );
  }
}
