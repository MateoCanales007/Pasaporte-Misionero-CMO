import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/image_preview.dart';
import '../../core/utils/image_rules.dart';
import '../../domain/models/sermon.dart';
import '../../domain/models/service_photo.dart';
import '../../domain/repositories/service_photo_repository.dart';
import '../firebase_error_mapper.dart';
import '../storage_upload.dart';

/// Fotos del culto por álbum. Los archivos están en Storage:
/// `<carpeta>/culto_<ms>.<ext>` (original, alta calidad) y
/// `<carpeta>/culto_<ms>_preview.jpg` (copia liviana que se muestra en la app).
/// La lista se lee de Firestore (`<álbum>/photos/culto_<ms>`), así la app no
/// necesita listar carpetas de Storage, algo que falla en algunos navegadores.
class FirebaseServicePhotoRepository implements ServicePhotoRepository {
  FirebaseServicePhotoRepository(
    this._db,
    this._storage, {
    Future<Uint8List?> Function(Uint8List)? previewBuilder,
    DateTime Function()? clock,
  }) : _previewBuilder = previewBuilder ?? buildImagePreview,
       _clock = clock ?? DateTime.now;

  static const _previewSuffix = '_preview';

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final Future<Uint8List?> Function(Uint8List) _previewBuilder;
  final DateTime Function() _clock;

  static String folderOf(PhotoAlbum album) => switch (album.kind) {
    PhotoAlbumKind.mission => 'mission_service_photos/${album.ownerId}',
    PhotoAlbumKind.sermon => 'sermon_photos/${album.ownerId}',
  };

  static String collectionOf(PhotoAlbum album) => switch (album.kind) {
    PhotoAlbumKind.mission => 'stamp/${album.ownerId}/photos',
    PhotoAlbumKind.sermon => 'sermons/${album.ownerId}/photos',
  };

  CollectionReference<Map<String, dynamic>> _photosOf(PhotoAlbum album) => _db.collection(collectionOf(album));

  @override
  Future<List<ServicePhoto>> photos(PhotoAlbum album) {
    return guardFirebase(() async {
      final snapshot = await _photosOf(album).orderBy('createdAt', descending: true).get();
      return [for (final doc in snapshot.docs) ?_photoFrom(doc.id, doc.data())];
    });
  }

  static ServicePhoto? _photoFrom(String id, Map<String, dynamic> data) {
    final originalUrl = data['originalUrl'];
    final storagePath = data['storagePath'];
    if (originalUrl is! String || originalUrl.isEmpty || storagePath is! String || storagePath.isEmpty) return null;
    final url = data['url'];
    final previewPath = data['previewPath'];
    return ServicePhoto(
      id: id,
      url: url is String && url.isNotEmpty ? url : originalUrl,
      originalUrl: originalUrl,
      storagePath: storagePath,
      previewPath: previewPath is String && previewPath.isNotEmpty ? previewPath : null,
    );
  }

  @override
  Future<ServicePhoto> upload(
    PhotoAlbum album,
    Uint8List original,
    String contentType, {
    required String editorUid,
  }) async {
    final folder = folderOf(album);
    final id = 'culto_${_clock().millisecondsSinceEpoch}';
    final uploaded = await uploadImage(
      _storage,
      folder: folder,
      baseName: 'culto',
      fileName: id,
      bytes: original,
      contentType: contentType,
      maxBytes: maxOriginalPhotoBytes,
      downloadName: 'foto-del-culto-$id',
    );
    UploadedImage? preview;
    final previewBytes = await _previewBuilder(original);
    if (previewBytes != null) {
      try {
        preview = await uploadImage(
          _storage,
          folder: folder,
          baseName: 'culto',
          fileName: '$id$_previewSuffix',
          bytes: previewBytes,
          contentType: 'image/jpeg',
        );
      } catch (_) {
        // Sin copia liviana la app muestra el original.
      }
    }
    final photo = ServicePhoto(
      id: id,
      url: preview?.downloadUrl ?? uploaded.downloadUrl,
      originalUrl: uploaded.downloadUrl,
      storagePath: uploaded.storagePath,
      previewPath: preview?.storagePath,
    );
    try {
      await guardFirebase(
        () => _photosOf(album).doc(id).set({
          'url': photo.url,
          'originalUrl': photo.originalUrl,
          'storagePath': photo.storagePath,
          if (photo.previewPath != null) 'previewPath': photo.previewPath,
          'createdBy': editorUid,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    } catch (_) {
      // Sin el registro nadie vería la foto: no se dejan archivos sueltos.
      await _deleteFiles(photo);
      rethrow;
    }
    return photo;
  }

  @override
  Future<void> delete(PhotoAlbum album, ServicePhoto photo) {
    return guardFirebase(() async {
      await _deleteFile(photo.storagePath);
      await _photosOf(album).doc(photo.id).delete();
      final preview = photo.previewPath;
      if (preview != null) {
        try {
          await _deleteFile(preview);
        } catch (_) {
          // La copia liviana es secundaria; el original y su registro ya se eliminaron.
        }
      }
    });
  }

  /// Borra un archivo; si ya no existe no es un error (permite reintentar).
  Future<void> _deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _deleteFiles(ServicePhoto photo) async {
    for (final path in [photo.storagePath, ?photo.previewPath]) {
      try {
        await _deleteFile(path);
      } catch (_) {
        // Se intentó limpiar; el error original es el que importa.
      }
    }
  }

  @override
  Future<Uint8List> originalBytes(ServicePhoto photo) {
    return guardFirebase(() async {
      final bytes = await _storage.ref(photo.storagePath).getData(maxOriginalPhotoBytes);
      if (bytes == null) throw const NotFoundException('No se encontró la foto.');
      return bytes;
    });
  }
}
