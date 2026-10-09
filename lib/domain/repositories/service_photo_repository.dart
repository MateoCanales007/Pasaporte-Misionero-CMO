import 'dart:typed_data';

import '../models/service_photo.dart';

/// Fotos del culto (misiones y prédicas). Solo los administradores suben o borran.
abstract interface class ServicePhotoRepository {
  /// Más recientes primero.
  Future<List<ServicePhoto>> photos(PhotoAlbum album);

  /// Guarda el original sin pérdida de calidad y una copia liviana para la app.
  Future<ServicePhoto> upload(PhotoAlbum album, Uint8List original, String contentType);

  Future<void> delete(ServicePhoto photo);

  /// Bytes del archivo original (para guardarlo en la galería del teléfono).
  Future<Uint8List> originalBytes(ServicePhoto photo);
}

/// Guarda imágenes en la galería del dispositivo.
abstract interface class PhotoSaver {
  /// `false` en web: allí la foto se descarga con el navegador.
  bool get savesToGallery;

  /// Devuelve `false` si el usuario no dio permiso.
  Future<bool> saveToGallery(Uint8List bytes, {required String name});
}
