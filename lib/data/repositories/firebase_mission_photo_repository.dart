import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/utils/image_preview.dart';
import '../../core/utils/image_rules.dart';
import '../../domain/models/mission.dart';
import '../../domain/models/sermon.dart';
import '../../domain/repositories/mission_repository.dart';
import '../firebase_error_mapper.dart';
import '../storage_upload.dart';

/// Fotos del culto en `mission_service_photos/{missionId}/`:
/// `culto_<ms>.<ext>` (original, alta calidad) y `culto_<ms>_preview.jpg`
/// (copia liviana que se muestra en la app).
class FirebaseMissionPhotoRepository implements MissionPhotoRepository {
  FirebaseMissionPhotoRepository(this._storage, {Future<Uint8List?> Function(Uint8List)? previewBuilder})
    : _previewBuilder = previewBuilder ?? buildImagePreview;

  static const _previewSuffix = '_preview';

  final FirebaseStorage _storage;
  final Future<Uint8List?> Function(Uint8List) _previewBuilder;

  String _folder(String missionId) => 'mission_service_photos/$missionId';

  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? fileName : fileName.substring(0, dot);
  }

  @override
  Future<List<MissionPhoto>> servicePhotos(String missionId) {
    return guardFirebase(() async {
      final items = (await _storage.ref(_folder(missionId)).listAll()).items;
      final previews = {
        for (final item in items)
          if (_baseName(item.name).endsWith(_previewSuffix)) _baseName(item.name): item,
      };
      final originals = items.where((item) => !_baseName(item.name).endsWith(_previewSuffix)).toList()
        ..sort((a, b) => b.name.compareTo(a.name));
      return Future.wait(
        originals.map((original) async {
          final preview = previews['${_baseName(original.name)}$_previewSuffix'];
          final originalUrl = await original.getDownloadURL();
          return MissionPhoto(
            url: preview == null ? originalUrl : await preview.getDownloadURL(),
            originalUrl: originalUrl,
            storagePath: original.fullPath,
            previewPath: preview?.fullPath,
          );
        }),
      );
    });
  }

  @override
  Future<MissionPhoto> uploadServicePhoto(String missionId, Uint8List original, String contentType) async {
    final base = 'culto_${DateTime.now().millisecondsSinceEpoch}';
    final uploaded = await uploadImage(
      _storage,
      folder: _folder(missionId),
      baseName: 'culto',
      fileName: base,
      bytes: original,
      contentType: contentType,
      maxBytes: maxOriginalPhotoBytes,
      downloadName: 'foto-del-culto-$base',
    );
    UploadedImage? preview;
    final previewBytes = await _previewBuilder(original);
    if (previewBytes != null) {
      try {
        preview = await uploadImage(
          _storage,
          folder: _folder(missionId),
          baseName: 'culto',
          fileName: '$base$_previewSuffix',
          bytes: previewBytes,
          contentType: 'image/jpeg',
        );
      } catch (_) {
        // Sin copia liviana la app muestra el original.
      }
    }
    return MissionPhoto(
      url: preview?.downloadUrl ?? uploaded.downloadUrl,
      originalUrl: uploaded.downloadUrl,
      storagePath: uploaded.storagePath,
      previewPath: preview?.storagePath,
    );
  }

  @override
  Future<void> deleteServicePhoto(MissionPhoto photo) {
    return guardFirebase(() async {
      await _storage.ref(photo.storagePath).delete();
      final preview = photo.previewPath;
      if (preview != null) {
        try {
          await _storage.ref(preview).delete();
        } catch (_) {
          // La copia liviana pudo no existir; el original ya se eliminó.
        }
      }
    });
  }
}
