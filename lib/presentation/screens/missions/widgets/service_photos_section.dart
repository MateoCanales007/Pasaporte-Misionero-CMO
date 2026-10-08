import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/models/mission.dart';
import '../../../providers/content_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/app_network_image.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/image_picker_button.dart';

/// "Fotos del culto": las suben los administradores; todos las pueden ver.
class ServicePhotosSection extends ConsumerStatefulWidget {
  const ServicePhotosSection({super.key, required this.mission});

  final Mission mission;

  @override
  ConsumerState<ServicePhotosSection> createState() => _ServicePhotosSectionState();
}

class _ServicePhotosSectionState extends ConsumerState<ServicePhotosSection> {
  String? _uploadProgress;

  Future<void> _addPhotos() async {
    // Se sube la foto original, sin comprimir, para poder descargarla en alta calidad.
    final picked = await pickImagesForUpload(context, original: true);
    if (picked.isEmpty || !mounted) return;
    final repo = ref.read(missionPhotoRepositoryProvider);
    var uploaded = 0;
    try {
      for (final image in picked) {
        setState(() => _uploadProgress = 'Subiendo ${uploaded + 1} de ${picked.length}…');
        await repo.uploadServicePhoto(widget.mission.id, image.bytes, image.contentType);
        uploaded++;
      }
      if (mounted) {
        showAppSnackBar(
          context,
          uploaded == 1 ? 'Foto agregada.' : '$uploaded fotos agregadas.',
          type: SnackType.success,
        );
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
      ref.invalidate(servicePhotosProvider(widget.mission.id));
    }
  }

  Future<void> _delete(MissionPhoto photo) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar esta foto?',
      message: 'La foto dejará de verse para todos.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(missionPhotoRepositoryProvider).deleteServicePhoto(photo);
      if (mounted) showAppSnackBar(context, 'Foto eliminada.', type: SnackType.success);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      ref.invalidate(servicePhotosProvider(widget.mission.id));
    }
  }

  Future<void> _download(MissionPhoto photo) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(photo.originalUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    showAppSnackBar(
      context,
      opened ? 'Descargando la foto en alta calidad…' : 'No se pudo descargar la foto. Inténtalo de nuevo.',
      type: opened ? SnackType.info : SnackType.error,
    );
  }

  void _openFullScreen(MissionPhoto photo, {required bool canDelete}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                  child: AppNetworkImage(url: photo.url, fit: BoxFit.contain, semanticLabel: 'Foto del culto'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _download(photo),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar en alta calidad'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy),
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                ),
                if (canDelete)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _delete(photo);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar foto'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentRoleProvider).isAdmin;
    final photos = ref.watch(servicePhotosProvider(widget.mission.id));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Fotos del culto', icon: Icons.photo_camera_rounded),
        photos.when(
          skipLoadingOnReload: true,
          loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Row(
            children: [
              Expanded(child: Text(friendlyErrorMessage(error), style: theme.textTheme.bodyMedium)),
              TextButton(
                onPressed: () => ref.invalidate(servicePhotosProvider(widget.mission.id)),
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
                    itemBuilder: (_, index) {
                      final photo = list[index];
                      return Semantics(
                        button: true,
                        label: 'Foto del culto ${index + 1}. Toca para ampliar.',
                        child: GestureDetector(
                          onTap: () => _openFullScreen(photo, canDelete: isAdmin),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            child: AppNetworkImage(url: photo.url, width: 170, height: 130),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _uploadProgress != null ? null : _addPhotos,
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
