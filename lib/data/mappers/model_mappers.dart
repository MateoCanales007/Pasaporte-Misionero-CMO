import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/mission.dart';
import '../../domain/models/notification_prefs.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/models/sermon.dart';
import '../../domain/models/stamp_redemption.dart';
import '../../domain/models/testimonial.dart';
import '../../domain/models/user_role.dart';
import 'firestore_parsers.dart';

typedef Json = Map<String, Object?>;

/// Conversión entre documentos de Firestore y modelos de dominio.
abstract final class ModelMappers {
  // ---------------------------------------------------------------- Usuario

  static AppUser appUser(String uid, Json data) {
    final prefs = FirestoreParsers.map(data['notificationPrefs']);
    return AppUser(
      uid: uid,
      username: FirestoreParsers.string(data['username']),
      passportNumber: FirestoreParsers.string(data['passportNumber'], fallback: 'PM-0000'),
      fullName: FirestoreParsers.string(data['fullName'], fallback: 'Misionero'),
      nationality: FirestoreParsers.string(data['nationality']),
      cellId: FirestoreParsers.string(data['cellId']),
      dateOfBirth: FirestoreParsers.optionalDate(data['dateOfBirth']),
      dateOfIssue: FirestoreParsers.optionalDate(data['dateOfIssue']),
      storedRole: UserRole.fromClaim(data['role']),
      roleVersion: FirestoreParsers.integer(data['roleVersion']),
      stampCount: FirestoreParsers.integer(data['stampCount']),
      communityVisible: FirestoreParsers.boolean(data['communityVisible'], fallback: true),
      showNationality: FirestoreParsers.boolean(data['showNationality'], fallback: false),
      showCell: FirestoreParsers.boolean(data['showCell'], fallback: true),
      notificationPrefs: notificationPrefs(prefs),
      deletionRequestedAt: FirestoreParsers.optionalDate(data['deletionRequestedAt']),
      legacyStamps: legacyStamps(data['stamps']),
    );
  }

  static List<LegacyStamp> legacyStamps(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map && entry['stampId'] is String)
          LegacyStamp(
            missionId: entry['stampId'] as String,
            obtainedAt: FirestoreParsers.optionalDate(entry['dateObtained']),
          ),
    ];
  }

  static NotificationPrefs notificationPrefs(Json data) => NotificationPrefs(
    newMission: FirestoreParsers.boolean(data['newMission'], fallback: true),
    missionReminder: FirestoreParsers.boolean(data['missionReminder'], fallback: true),
    newSermon: FirestoreParsers.boolean(data['newSermon'], fallback: true),
    stampConfirmed: FirestoreParsers.boolean(data['stampConfirmed'], fallback: true),
  );

  static Json notificationPrefsToJson(NotificationPrefs prefs) => {
    'newMission': prefs.newMission,
    'missionReminder': prefs.missionReminder,
    'newSermon': prefs.newSermon,
    'stampConfirmed': prefs.stampConfirmed,
  };

  static Json newPassport(String uid, String username, NewPassport data, DateTime now) => {
    'id': uid,
    'username': username,
    'passportNumber': 'PM-${now.year}-${uid.substring(0, uid.length < 4 ? uid.length : 4).toUpperCase()}',
    'fullName': data.fullName.trim(),
    'nationality': data.nationality.trim(),
    'dateOfBirth': Timestamp.fromDate(data.dateOfBirth),
    'cellId': data.cellId.trim(),
    'dateOfIssue': Timestamp.fromDate(now),
    'stamps': <Object?>[],
    'communityVisible': data.communityVisible,
    'showNationality': false,
    'showCell': true,
    'notificationPrefs': notificationPrefsToJson(const NotificationPrefs()),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Json profileUpdate(ProfileUpdate update) => {
    if (update.fullName != null) 'fullName': update.fullName!.trim(),
    if (update.nationality != null) 'nationality': update.nationality!.trim(),
    if (update.cellId != null) 'cellId': update.cellId!.trim(),
    if (update.communityVisible != null) 'communityVisible': update.communityVisible,
    if (update.showNationality != null) 'showNationality': update.showNationality,
    if (update.showCell != null) 'showCell': update.showCell,
    if (update.notificationPrefs != null) 'notificationPrefs': notificationPrefsToJson(update.notificationPrefs!),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static StampRedemption redemption(String missionId, Json data) => StampRedemption(
    missionId: missionId,
    missionName: FirestoreParsers.optionalString(data['missionName']),
    redeemedAt: FirestoreParsers.optionalDate(data['redeemedAt']),
    source: data['source'] == 'legacy_migration' ? RedemptionSource.legacyMigration : RedemptionSource.qr,
  );

  static PublicProfile publicProfile(String uid, Json data) {
    final name = FirestoreParsers.string(data['displayName'], fallback: 'Misionero');
    return PublicProfile(
      uid: uid,
      displayName: name,
      initials: FirestoreParsers.string(data['initials'], fallback: 'CM'),
      cellName: FirestoreParsers.optionalString(data['cellName']),
      nationality: FirestoreParsers.optionalString(data['nationality']),
      stampCount: FirestoreParsers.integer(data['stampCount']),
      stampIds: FirestoreParsers.stringList(data['stampIds']),
      communityVisible: FirestoreParsers.boolean(data['communityVisible'], fallback: false),
    );
  }

  static Cell cell(String id, Json data) => Cell(
    id: id,
    name: FirestoreParsers.string(data['name'], fallback: 'Célula sin nombre'),
  );

  // ---------------------------------------------------------------- Misiones

  static Mission mission(String id, Json data) {
    final location = data['location'];
    return Mission(
      id: id,
      name: FirestoreParsers.string(data['name'], fallback: 'Misión sin nombre'),
      isoCode: FirestoreParsers.string(data['isoCode'], fallback: 'GLOBAL'),
      status: MissionStatus.parse(data['status'], legacyActive: data['active']),
      imageUrl: FirestoreParsers.string(data['image']),
      location: location is GeoPoint ? GeoLocation(location.latitude, location.longitude) : null,
      placeId: FirestoreParsers.optionalString(data['placeId']),
      schedules: schedules(data['schedule'], missionId: id),
      createdBy: FirestoreParsers.optionalString(data['createdBy']),
      updatedBy: FirestoreParsers.optionalString(data['updatedBy']),
      createdAt: FirestoreParsers.optionalDate(data['createdAt']),
      updatedAt: FirestoreParsers.optionalDate(data['updatedAt']),
    );
  }

  /// Las ventanas dañadas se omiten (no se inventan fechas).
  static List<MissionSchedule> schedules(Object? raw, {required String missionId}) {
    if (raw is! List) return const [];
    final result = <MissionSchedule>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final start = FirestoreParsers.optionalDate(entry['start']);
      final end = FirestoreParsers.optionalDate(entry['end']);
      if (start != null && end != null) result.add(MissionSchedule(start: start, end: end));
    }
    return result;
  }

  static Json missionDraftToCallable(MissionDraft draft) => {
    if (draft.id != null) 'missionId': draft.id,
    'name': draft.name.trim(),
    'isoCode': draft.isoCode.trim().toUpperCase(),
    'image': draft.imageUrl.trim(),
    'location': {'lat': draft.location.latitude, 'lng': draft.location.longitude},
    'placeId': draft.placeId,
    'schedules': [
      for (final s in draft.schedules) {'start': s.start.millisecondsSinceEpoch, 'end': s.end.millisecondsSinceEpoch},
    ],
    'status': draft.status.name,
  };

  // ---------------------------------------------------------------- Prédicas

  static Sermon sermon(String id, Json data) => Sermon(
    id: id,
    sourceUrl: FirestoreParsers.requiredString(data['sourceUrl'], 'sermons/$id.sourceUrl'),
    title: FirestoreParsers.string(data['title'], fallback: 'Prédica'),
    platform: VideoPlatform.parse(data['platform']),
    publishedAt: FirestoreParsers.requiredDate(data['publishedAt'], 'sermons/$id.publishedAt'),
    coverImageUrl: FirestoreParsers.string(data['coverImageUrl']),
    coverStoragePath: FirestoreParsers.optionalString(data['coverStoragePath']),
    thumbnailUrl: FirestoreParsers.string(data['thumbnailUrl']),
    domain: FirestoreParsers.string(data['domain']),
    externalVideoId: FirestoreParsers.optionalString(data['externalVideoId']),
    active: FirestoreParsers.boolean(data['active'], fallback: false),
    deleted: FirestoreParsers.boolean(data['deleted'], fallback: false),
    deletedAt: FirestoreParsers.optionalDate(data['deletedAt']),
    sortOrder: FirestoreParsers.optionalInt(data['sortOrder']),
    createdBy: FirestoreParsers.optionalString(data['createdBy']),
    createdAt: FirestoreParsers.optionalDate(data['createdAt']),
  );

  /// Campos editables de una prédica (comunes a crear y actualizar).
  static Json sermonEditableFields(SermonDraft draft, {required String editorUid}) => {
    'sourceUrl': draft.sourceUrl.trim(),
    'title': draft.title.trim(),
    'coverImageUrl': draft.coverImageUrl,
    'coverStoragePath': draft.coverStoragePath,
    'thumbnailUrl': draft.thumbnailUrl,
    'platform': draft.platform.name,
    'domain': draft.domain,
    'externalVideoId': draft.externalVideoId,
    'publishedAt': Timestamp.fromDate(draft.publishedAt),
    'active': draft.active,
    'updatedBy': editorUid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Documento completo para crear. Al actualizar se usan solo los campos
  /// editables para no tocar `createdBy`/`createdAt`, que las reglas protegen.
  static Json sermonCreate(SermonDraft draft, {required String editorUid}) => {
    ...sermonEditableFields(draft, editorUid: editorUid),
    'deleted': false,
    'deletedAt': null,
    'createdBy': editorUid,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static VideoMetadataResult videoMetadata(Object? raw) {
    final data = FirestoreParsers.map(raw);
    if (data['status'] == 'invalidUrl') return VideoUrlRejected(invalidUrlMessage(data['reason']));
    if (data['status'] != 'ok') throw const UnknownException();
    return VideoMetadataFound(
      VideoMetadata(
        platform: VideoPlatform.parse(data['platform']),
        domain: FirestoreParsers.string(data['domain']),
        canonicalUrl: FirestoreParsers.string(data['canonicalUrl']),
        metadataAvailable: FirestoreParsers.boolean(data['metadataAvailable'], fallback: false),
        externalVideoId: FirestoreParsers.optionalString(data['externalVideoId']),
        title: FirestoreParsers.optionalString(data['title']),
        thumbnailUrl: FirestoreParsers.optionalString(data['thumbnailUrl']),
        authorName: FirestoreParsers.optionalString(data['authorName']),
      ),
    );
  }

  /// Mensaje para el administrador según el motivo devuelto por el servidor.
  static String invalidUrlMessage(Object? reason) => switch (reason) {
    'empty' => 'Pega el enlace del video.',
    'tooLong' => 'El enlace es demasiado largo.',
    'notHttps' => 'El enlace debe empezar con https://',
    'credentials' => 'El enlace no puede incluir usuario ni contraseña.',
    'invalidVideoId' => 'No reconocemos el video. Copia el enlace completo otra vez.',
    _ => 'El enlace no es válido. Revisa que esté completo.',
  };

  // ---------------------------------------------------------------- Comunidad

  static Testimonial testimonial(String id, Json data) => Testimonial(
    id: id,
    userId: FirestoreParsers.string(data['userId']),
    displayName: FirestoreParsers.string(data['displayName'], fallback: 'Misionero'),
    text: FirestoreParsers.string(data['text']),
    status: TestimonialStatus.parse(data['status']),
    missionId: FirestoreParsers.optionalString(data['missionId']),
    createdAt: FirestoreParsers.optionalDate(data['createdAt']),
  );

  static JournalEntry journalEntry(String id, Json data, {required bool hasPendingWrites}) => JournalEntry(
    id: id,
    text: FirestoreParsers.string(data['text']),
    missionId: FirestoreParsers.optionalString(data['missionId']),
    missionName: FirestoreParsers.optionalString(data['missionName']),
    createdAt: FirestoreParsers.optionalDate(data['createdAt']),
    updatedAt: FirestoreParsers.optionalDate(data['updatedAt']),
    hasPendingWrites: hasPendingWrites,
  );
}
