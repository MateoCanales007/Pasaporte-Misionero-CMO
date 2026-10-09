import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/sermon.dart';
import '../../domain/repositories/sermon_repository.dart';
import '../firebase_error_mapper.dart';
import '../mappers/model_mappers.dart';
import '../storage_upload.dart';
import '../stream_extensions.dart';

class FirebaseSermonRepository implements SermonRepository {
  FirebaseSermonRepository(this._db, this._functions, this._storage);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _sermons => _db.collection('sermons');

  @override
  Stream<List<Sermon>> watchSermons({required bool includeHidden}) {
    final Query<Map<String, dynamic>> query = includeHidden
        ? _sermons.orderBy('publishedAt', descending: true)
        : _sermons.where('active', isEqualTo: true).orderBy('publishedAt', descending: true);
    return query.snapshots().map((snap) {
      final sermons = <Sermon>[];
      for (final doc in snap.docs) {
        try {
          sermons.add(ModelMappers.sermon(doc.id, doc.data()));
        } on DataParseException catch (e) {
          debugPrint('Prédica omitida por datos dañados: ${e.detail}');
        }
      }
      return sermons;
    }).mapFirebaseErrors();
  }

  @override
  String newSermonId() => _sermons.doc().id;

  @override
  Future<void> save(SermonDraft draft, {required String editorUid}) {
    final doc = _sermons.doc(draft.id);
    return guardFirebase(
      () => draft.isNew
          ? doc.set(ModelMappers.sermonCreate(draft, editorUid: editorUid))
          : doc.update(ModelMappers.sermonEditableFields(draft, editorUid: editorUid)),
    );
  }

  Future<void> _update(String id, String editorUid, Map<String, Object?> fields) {
    return guardFirebase(
      () => _sermons.doc(id).update({...fields, 'updatedBy': editorUid, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  @override
  Future<void> setActive(String sermonId, bool active, {required String editorUid}) =>
      _update(sermonId, editorUid, {'active': active});

  @override
  Future<void> softDelete(String sermonId, {required String editorUid}) =>
      _update(sermonId, editorUid, {'active': false, 'deleted': true, 'deletedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> restore(String sermonId, {required String editorUid}) =>
      _update(sermonId, editorUid, {'deleted': false, 'deletedAt': null});

  @override
  Future<VideoMetadataResult> fetchMetadata(String url) {
    return guardFirebase(() async {
      final result = await _functions.httpsCallable('fetchVideoMetadata').call<Object?>({'url': url});
      return ModelMappers.videoMetadata(result.data);
    });
  }

  @override
  Future<UploadedImage> uploadCover(String sermonId, Uint8List bytes, String contentType) {
    return uploadImage(
      _storage,
      folder: 'sermon_covers/$sermonId',
      baseName: 'portada',
      bytes: bytes,
      contentType: contentType,
    );
  }
}
