import 'dart:typed_data';

import '../models/sermon.dart';

abstract interface class SermonRepository {
  /// Prédicas visibles. Si [includeHidden] (solo admin) incluye inactivas y
  /// eliminadas.
  Stream<List<Sermon>> watchSermons({required bool includeHidden});

  String newSermonId();

  Future<void> save(SermonDraft draft, {required String editorUid});

  Future<void> setActive(String sermonId, bool active, {required String editorUid});

  /// Borrado recuperable.
  Future<void> softDelete(String sermonId, {required String editorUid});

  Future<void> restore(String sermonId, {required String editorUid});

  Future<VideoMetadataResult> fetchMetadata(String url);

  Future<UploadedImage> uploadCover(String sermonId, Uint8List bytes, String contentType);
}
