import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/mission.dart';
import '../../domain/models/sermon.dart';
import '../../domain/repositories/mission_repository.dart';
import '../firebase_error_mapper.dart';
import '../mappers/model_mappers.dart';
import '../storage_upload.dart';
import '../stream_extensions.dart';

class FirebaseMissionRepository implements MissionRepository {
  FirebaseMissionRepository(this._db, this._functions, this._storage);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  @override
  Stream<List<Mission>> watchMissions() {
    return _db
        .collection('stamp')
        .snapshots()
        .map((snap) => [for (final doc in snap.docs) ModelMappers.mission(doc.id, doc.data())])
        .mapFirebaseErrors();
  }

  @override
  Future<String> saveMission(MissionDraft draft) {
    return guardFirebase(() async {
      final result = await _functions
          .httpsCallable('saveMission')
          .call<Object?>(ModelMappers.missionDraftToCallable(draft));
      final data = result.data;
      final id = data is Map ? data['missionId'] : null;
      if (id is! String) throw const UnknownException();
      return id;
    });
  }

  @override
  Future<void> setMissionStatus(String missionId, MissionStatus status) {
    return guardFirebase(() async {
      await _functions.httpsCallable('setMissionStatus').call<Object?>({'missionId': missionId, 'status': status.name});
    });
  }

  @override
  Future<UploadedImage> uploadMissionImage(Uint8List bytes, String contentType) {
    final folder = _db.collection('stamp').doc().id;
    return uploadImage(
      _storage,
      folder: 'mission_images/$folder',
      baseName: 'imagen',
      bytes: bytes,
      contentType: contentType,
    );
  }
}

class FirebasePlacesRepository implements PlacesRepository {
  FirebasePlacesRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<Object?, Object?>> _call(String name, Map<String, Object?> payload) {
    return guardFirebase(() async {
      final result = await _functions.httpsCallable(name).call<Object?>(payload);
      final data = result.data;
      if (data is! Map || data['success'] != true) throw const UnknownException();
      return data;
    });
  }

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    final data = await _call('searchPlaces', {'query': query});
    final predictions = data['predictions'];
    if (predictions is! List) return const [];
    return [
      for (final p in predictions)
        if (p is Map && p['place_id'] is String && p['description'] is String)
          PlaceSuggestion(placeId: p['place_id'] as String, description: p['description'] as String),
    ];
  }

  @override
  Future<GeoLocation> locationOf(String placeId) async {
    final data = await _call('getPlaceDetails', {'placeId': placeId});
    final location = data['location'];
    if (location is Map && location['lat'] is num && location['lng'] is num) {
      return GeoLocation((location['lat'] as num).toDouble(), (location['lng'] as num).toDouble());
    }
    throw const NotFoundException('No se encontró la ubicación de ese lugar.');
  }

  @override
  Future<List<String>> photoReferences({String? placeId, GeoLocation? near}) async {
    final data = await _call('getPhotoReferences', {'placeId': placeId, 'lat': near?.latitude, 'lng': near?.longitude});
    final refs = data['references'];
    return refs is List ? refs.whereType<String>().toList() : const [];
  }

  @override
  Future<Uint8List> photo(String photoReference) async {
    final data = await _call('getMissionPlacePhoto', {'photoReference': photoReference});
    final base64Image = data['imageBase64'];
    if (base64Image is! String) throw const NotFoundException();
    return base64Decode(base64Image);
  }
}
