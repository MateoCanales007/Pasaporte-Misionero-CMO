import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/image_rules.dart';
import '../domain/models/sermon.dart';
import 'firebase_error_mapper.dart';

/// Sube una imagen validada (tipo y tamaño) y devuelve su URL de descarga.
Future<UploadedImage> uploadImage(
  FirebaseStorage storage, {
  required String folder,
  required String baseName,
  required Uint8List bytes,
  required String contentType,
  int maxBytes = maxImageBytes,
  String? fileName,
  String? downloadName,
}) {
  final extension = allowedImageTypes[contentType];
  if (extension == null) {
    throw const ValidationException('Solo se permiten imágenes JPG, PNG o WEBP.');
  }
  if (bytes.lengthInBytes >= maxBytes) {
    throw ValidationException('La imagen es demasiado grande. El máximo es ${maxBytes ~/ (1024 * 1024)} MB.');
  }
  return guardFirebase(() async {
    final path = '$folder/${fileName ?? '${baseName}_${DateTime.now().millisecondsSinceEpoch}'}.$extension';
    final ref = storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=604800',
        // Al abrir el enlace, el navegador descarga el archivo original.
        contentDisposition: downloadName == null ? null : 'attachment; filename="$downloadName.$extension"',
      ),
    );
    return UploadedImage(downloadUrl: await ref.getDownloadURL(), storagePath: path);
  });
}
