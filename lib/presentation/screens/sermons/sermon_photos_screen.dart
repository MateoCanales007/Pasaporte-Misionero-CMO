import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/sermon.dart';
import '../../../domain/models/service_photo.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/service_photos/service_photo_actions.dart';
import '../../widgets/service_photos/service_photos_section.dart';
import '../../widgets/state_views.dart';

/// Fotos del culto de una prédica. Todos las ven y descargan; los
/// administradores las agregan y eliminan.
class SermonPhotosScreen extends ConsumerStatefulWidget {
  const SermonPhotosScreen({super.key, required this.sermon});

  final Sermon sermon;

  @override
  ConsumerState<SermonPhotosScreen> createState() => _SermonPhotosScreenState();
}

class _SermonPhotosScreenState extends ConsumerState<SermonPhotosScreen> {
  String? _uploadProgress;

  PhotoAlbum get _album => PhotoAlbum.sermon(widget.sermon.id);

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final photos = ref.watch(servicePhotosProvider(_album));
    return Scaffold(
      appBar: AppBar(title: const Text('Fotos del culto')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.onOrange,
              onPressed: _uploadProgress != null
                  ? null
                  : () => addServicePhotos(
                      context,
                      ref,
                      _album,
                      onProgress: (text) {
                        if (mounted) setState(() => _uploadProgress = text);
                      },
                    ),
              icon: _uploadProgress != null
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_uploadProgress ?? 'Agregar fotos'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(servicePhotosProvider(_album)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveCenter(
                child: PageHeader(
                  title: widget.sermon.title,
                  subtitle: 'Toca una foto para verla en grande y guardarla.',
                ),
              ),
            ),
            photos.when(
              skipLoadingOnReload: true,
              loading: () => const SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(error: error, onRetry: () => ref.invalidate(servicePhotosProvider(_album))),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.photo_library_outlined,
                      title: 'Aún no hay fotos de este culto',
                      message: isAdmin ? 'Toca "Agregar fotos" para subir las primeras.' : null,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 120),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) => ServicePhotoThumbnail(
                      photo: list[index],
                      index: index,
                      onTap: () => openServicePhotoViewer(context, _album, list[index], canDelete: isAdmin),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
