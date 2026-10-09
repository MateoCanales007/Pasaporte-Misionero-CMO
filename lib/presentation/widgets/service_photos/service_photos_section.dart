import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/service_photo.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_providers.dart';
import '../app_network_image.dart';
import '../common_widgets.dart';
import 'service_photo_actions.dart';

/// "Fotos del culto" en una fila horizontal: todos las ven; los
/// administradores las suben y eliminan.
class ServicePhotosSection extends ConsumerStatefulWidget {
  const ServicePhotosSection({super.key, required this.album, this.title = 'Fotos del culto'});

  final PhotoAlbum album;
  final String title;

  @override
  ConsumerState<ServicePhotosSection> createState() => _ServicePhotosSectionState();
}

class _ServicePhotosSectionState extends ConsumerState<ServicePhotosSection> {
  String? _uploadProgress;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final photos = ref.watch(servicePhotosProvider(widget.album));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(widget.title, icon: Icons.photo_camera_rounded),
        photos.when(
          skipLoadingOnReload: true,
          loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Row(
            children: [
              Expanded(child: Text(friendlyErrorMessage(error), style: theme.textTheme.bodyMedium)),
              TextButton(
                onPressed: () => ref.invalidate(servicePhotosProvider(widget.album)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (list) => list.isEmpty
              ? Text('Aún no hay fotos del culto.', style: theme.textTheme.bodyMedium)
              : SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, index) => ServicePhotoThumbnail(
                      photo: list[index],
                      index: index,
                      width: 170,
                      onTap: () => openServicePhotoViewer(context, widget.album, list[index], canDelete: isAdmin),
                    ),
                  ),
                ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _uploadProgress != null
                ? null
                : () => addServicePhotos(
                    context,
                    ref,
                    widget.album,
                    onProgress: (text) {
                      if (mounted) setState(() => _uploadProgress = text);
                    },
                  ),
            icon: _uploadProgress != null
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                : const Icon(Icons.add_photo_alternate_rounded),
            label: Text(_uploadProgress ?? 'Agregar fotos del culto'),
          ),
        ],
      ],
    );
  }
}

/// Miniatura tocable de una foto del culto.
class ServicePhotoThumbnail extends StatelessWidget {
  const ServicePhotoThumbnail({super.key, required this.photo, required this.index, required this.onTap, this.width});

  final ServicePhoto photo;
  final int index;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto del culto ${index + 1}. Toca para ampliar.',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          child: AppNetworkImage(url: photo.url, width: width, height: width == null ? null : 130),
        ),
      ),
    );
  }
}
