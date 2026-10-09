import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/data/repositories/firebase_service_photo_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/models/service_photo.dart';

/// Storage en memoria: guarda los archivos subidos y los que se borran.
class _FakeStorage extends Fake implements FirebaseStorage {
  final files = <String, Uint8List>{};

  @override
  Reference ref([String? path]) => _FakeRef(this, path!);
}

class _FakeRef extends Fake implements Reference {
  _FakeRef(this._storage, this.fullPath);

  final _FakeStorage _storage;

  @override
  final String fullPath;

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    _storage.files[fullPath] = data;
    return _DoneUpload();
  }

  @override
  Future<String> getDownloadURL() async => 'https://firebasestorage.test/${Uri.encodeComponent(fullPath)}';

  @override
  Future<void> delete() async {
    if (_storage.files.remove(fullPath) == null) {
      throw FirebaseException(plugin: 'firebase_storage', code: 'object-not-found');
    }
  }
}

class _DoneUpload extends Fake implements UploadTask {
  @override
  Future<R> then<R>(FutureOr<R> Function(TaskSnapshot) onValue, {Function? onError}) =>
      Future<TaskSnapshot>.value(_Snapshot()).then(onValue, onError: onError);
}

class _Snapshot extends Fake implements TaskSnapshot {}

void main() {
  const album = PhotoAlbum.sermon('s1');
  final now = DateTime.fromMillisecondsSinceEpoch(1791490234565);
  late FakeFirebaseFirestore db;
  late _FakeStorage storage;

  FirebaseServicePhotoRepository repo({Uint8List? preview}) =>
      FirebaseServicePhotoRepository(db, storage, previewBuilder: (_) async => preview, clock: () => now);

  setUp(() {
    db = FakeFirebaseFirestore();
    storage = _FakeStorage();
  });

  test('cada álbum tiene su carpeta en Storage y su lista en Firestore', () {
    expect(FirebaseServicePhotoRepository.folderOf(const PhotoAlbum.mission('m1')), 'mission_service_photos/m1');
    expect(FirebaseServicePhotoRepository.collectionOf(const PhotoAlbum.mission('m1')), 'stamp/m1/photos');
    expect(FirebaseServicePhotoRepository.folderOf(album), 'sermon_photos/s1');
    expect(FirebaseServicePhotoRepository.collectionOf(album), 'sermons/s1/photos');
  });

  test('sube el original y la copia liviana, y registra la foto', () async {
    final photo = await repo(preview: Uint8List(2)).upload(album, Uint8List(8), 'image/png', editorUid: 'admin1');

    expect(photo.id, 'culto_1791490234565');
    expect(storage.files.keys, [
      'sermon_photos/s1/culto_1791490234565.png',
      'sermon_photos/s1/culto_1791490234565_preview.jpg',
    ]);
    final data = (await db.doc('sermons/s1/photos/culto_1791490234565').get()).data()!;
    expect(data['storagePath'], 'sermon_photos/s1/culto_1791490234565.png');
    expect(data['previewPath'], 'sermon_photos/s1/culto_1791490234565_preview.jpg');
    expect(data['url'], contains('_preview.jpg'));
    expect(data['originalUrl'], contains('culto_1791490234565.png'));
    expect(data['createdBy'], 'admin1');
    expect(data['createdAt'], isA<Timestamp>());
  });

  test('sin copia liviana la app muestra el original', () async {
    final photo = await repo().upload(album, Uint8List(8), 'image/jpeg', editorUid: 'admin1');

    expect(photo.url, photo.originalUrl);
    expect(photo.previewPath, isNull);
    final data = (await db.doc('sermons/s1/photos/${photo.id}').get()).data()!;
    expect(data.containsKey('previewPath'), isFalse);
  });

  test('lista las fotos del álbum, más recientes primero', () async {
    final photos = db.collection('sermons/s1/photos');
    await photos.doc('culto_1').set({
      'url': 'https://x/1_preview.jpg',
      'originalUrl': 'https://x/1.jpg',
      'storagePath': 'sermon_photos/s1/culto_1.jpg',
      'previewPath': 'sermon_photos/s1/culto_1_preview.jpg',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
    });
    await photos.doc('culto_2').set({
      'originalUrl': 'https://x/2.jpg',
      'storagePath': 'sermon_photos/s1/culto_2.jpg',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 2)),
    });
    await photos.doc('roto').set({
      'url': 'https://x/3.jpg',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 3)),
    });
    await db.collection('sermons/otra/photos').doc('culto_9').set({
      'originalUrl': 'https://x/9.jpg',
      'storagePath': 'sermon_photos/otra/culto_9.jpg',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4)),
    });

    final list = await repo().photos(album);

    expect(list.map((p) => p.id), ['culto_2', 'culto_1'], reason: 'la foto incompleta se omite');
    expect(list.first.url, 'https://x/2.jpg', reason: 'sin copia liviana se usa el original');
    expect(list.last.previewPath, 'sermon_photos/s1/culto_1_preview.jpg');
  });

  test('eliminar borra el registro y los dos archivos', () async {
    final photo = await repo(preview: Uint8List(2)).upload(album, Uint8List(8), 'image/jpeg', editorUid: 'admin1');

    await repo().delete(album, photo);

    expect(storage.files, isEmpty);
    expect((await db.doc('sermons/s1/photos/${photo.id}').get()).exists, isFalse);
  });

  test('eliminar se puede reintentar aunque el archivo ya no exista', () async {
    final photo = await repo().upload(album, Uint8List(8), 'image/jpeg', editorUid: 'admin1');
    storage.files.clear();

    await repo().delete(album, photo);

    expect((await db.doc('sermons/s1/photos/${photo.id}').get()).exists, isFalse);
  });
}
