import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/service_photo.dart';
import '../../providers/content_providers.dart';
import '../../providers/repository_providers.dart';
import '../app_network_image.dart';
import '../dialogs.dart';
import '../image_picker_button.dart';

/// Sube varias fotos originales (sin comprimir) a un álbum. [onProgress]
/// recibe el texto de avance, o `null` al terminar.
Future<void> addServicePhotos(
  BuildContext context,
  WidgetRef ref,
  PhotoAlbum album, {
  required ValueChanged<String?> onProgress,
}) async {
  final picked = await pickImagesForUpload(context, original: true);
  if (picked.isEmpty || !context.mounted) return;
  final repo = ref.read(servicePhotoRepositoryProvider);
  var uploaded = 0;
  try {
    for (final image in picked) {
      onProgress('Subiendo ${uploaded + 1} de ${picked.length}…');
      await repo.upload(album, image.bytes, image.contentType);
      uploaded++;
    }
    if (context.mounted) {
      showAppSnackBar(
        context,
        uploaded == 1 ? 'Foto agregada.' : '$uploaded fotos agregadas.',
        type: SnackType.success,
      );
    }
  } catch (error) {
    if (context.mounted) showErrorSnackBar(context, error);
  } finally {
    onProgress(null);
    ref.invalidate(servicePhotosProvider(album));
  }
}

/// Abre la foto en grande con las opciones de guardar y (para admins) eliminar.
Future<void> openServicePhotoViewer(
  BuildContext context,
  PhotoAlbum album,
  ServicePhoto photo, {
  required bool canDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ServicePhotoViewer(album: album, photo: photo, canDelete: canDelete),
  );
}

class _ServicePhotoViewer extends ConsumerStatefulWidget {
  const _ServicePhotoViewer({required this.album, required this.photo, required this.canDelete});

  final PhotoAlbum album;
  final ServicePhoto photo;
  final bool canDelete;

  @override
  ConsumerState<_ServicePhotoViewer> createState() => _ServicePhotoViewerState();
}

class _ServicePhotoViewerState extends ConsumerState<_ServicePhotoViewer> {
  bool _saving = false;

  /// En el teléfono se guarda en la galería; en la web se descarga el original.
  Future<void> _save() async {
    final saver = ref.read(photoSaverProvider);
    final messenger = ScaffoldMessenger.of(context);
    void notify(String text, SnackType type) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(buildAppSnackBar(text, type: type));
    }

    if (!saver.savesToGallery) {
      var opened = false;
      try {
        opened = await launchUrl(
          Uri.parse(widget.photo.originalUrl),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } catch (_) {
        opened = false;
      }
      notify(
        opened ? 'Descargando la foto en alta calidad…' : 'No se pudo descargar la foto. Inténtalo de nuevo.',
        opened ? SnackType.info : SnackType.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final bytes = await ref.read(servicePhotoRepositoryProvider).originalBytes(widget.photo);
      final name = 'culto-${DateTime.now().millisecondsSinceEpoch}';
      final saved = await saver.saveToGallery(bytes, name: name);
      notify(
        saved
            ? 'Foto guardada en tu galería, en el álbum "Pasaporte CMO".'
            : 'Para guardar fotos, permite el acceso a la galería en los ajustes del teléfono.',
        saved ? SnackType.success : SnackType.error,
      );
    } catch (error) {
      notify(
        error is AppException ? error.message : 'No se pudo guardar la foto. Inténtalo de nuevo.',
        SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar esta foto?',
      message: 'La foto dejará de verse para todos.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(servicePhotoRepositoryProvider).delete(widget.photo);
      messenger.showSnackBar(buildAppSnackBar('Foto eliminada.', type: SnackType.success));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      messenger.showSnackBar(buildAppSnackBar(friendlyErrorMessage(error), type: SnackType.error));
    } finally {
      ref.invalidate(servicePhotosProvider(widget.album));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toGallery = ref.watch(photoSaverProvider).savesToGallery;
    return Dialog(
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
                child: AppNetworkImage(url: widget.photo.url, fit: BoxFit.contain, semanticLabel: 'Foto del culto'),
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
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                    : Icon(toGallery ? Icons.save_alt_rounded : Icons.download_rounded),
                label: Text(
                  _saving ? 'Guardando…' : (toGallery ? 'Guardar en la galería' : 'Descargar en alta calidad'),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cerrar'),
              ),
              if (widget.canDelete)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar foto'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
