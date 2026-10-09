import 'dart:typed_data';

import '../models/mission.dart';
import '../models/sermon.dart';

abstract interface class MissionRepository {
  Stream<List<Mission>> watchMissions();

  /// Crea o actualiza mediante Cloud Function protegida. Devuelve el id.
  Future<String> saveMission(MissionDraft draft);

  Future<void> setMissionStatus(String missionId, MissionStatus status);

  Future<UploadedImage> uploadMissionImage(Uint8List bytes, String contentType);
}

/// Búsqueda de lugares y fotos (Google Places a través de Cloud Functions).
abstract interface class PlacesRepository {
  Future<List<PlaceSuggestion>> search(String query);

  Future<GeoLocation> locationOf(String placeId);

  Future<List<String>> photoReferences({String? placeId, GeoLocation? near});

  Future<Uint8List> photo(String photoReference);
}
