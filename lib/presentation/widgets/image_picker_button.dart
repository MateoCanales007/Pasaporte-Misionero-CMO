import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/image_rules.dart';
import 'dialogs.dart';

/// Imagen elegida por el administrador, lista para subir.
class PickedImage {
  const PickedImage(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

/// Abre la galería, comprime y valida tipo y tamaño. Devuelve `null` si se
/// canceló o la imagen no es válida (y avisa al usuario).
Future<PickedImage?> pickImageForUpload(BuildContext context) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  } catch (_) {
    if (context.mounted) showAppSnackBar(context, 'No se pudo abrir la galería.', type: SnackType.error);
    return null;
  }
  if (file == null) return null;
  final contentType = imageContentTypeFor(file.name, reported: file.mimeType);
  if (contentType == null) {
    if (context.mounted) showAppSnackBar(context, 'Elige una imagen JPG, PNG o WEBP.', type: SnackType.error);
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.lengthInBytes >= maxImageBytes) {
    if (context.mounted) showAppSnackBar(context, 'La imagen pesa más de 5 MB. Elige otra.', type: SnackType.error);
    return null;
  }
  return PickedImage(bytes, contentType);
}

/// Elige varias imágenes de la galería (las no válidas se omiten con aviso).
/// Con [original] se conserva la foto tal como se tomó (sin comprimir).
Future<List<PickedImage>> pickImagesForUpload(BuildContext context, {int limit = 10, bool original = false}) async {
  final List<XFile> files;
  try {
    files = original
        ? await ImagePicker().pickMultiImage(limit: limit)
        : await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: limit);
  } catch (_) {
    if (context.mounted) showAppSnackBar(context, 'No se pudo abrir la galería.', type: SnackType.error);
    return const [];
  }
  final picked = <PickedImage>[];
  var skipped = 0;
  final maxBytes = original ? maxOriginalPhotoBytes : maxImageBytes;
  for (final file in files.take(limit)) {
    final contentType = imageContentTypeFor(file.name, reported: file.mimeType);
    final bytes = contentType == null ? null : await file.readAsBytes();
    if (contentType == null || bytes == null || bytes.lengthInBytes >= maxBytes) {
      skipped++;
      continue;
    }
    picked.add(PickedImage(bytes, contentType));
  }
  if (skipped > 0 && context.mounted) {
    showAppSnackBar(
      context,
      skipped == 1 ? 'Una imagen no era válida y se omitió.' : '$skipped imágenes no eran válidas y se omitieron.',
    );
  }
  return picked;
}
