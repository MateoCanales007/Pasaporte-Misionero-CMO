import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/core/errors/app_exception.dart';
import 'package:pasaporte_misionero_cmo/data/firebase_error_mapper.dart';
import 'package:pasaporte_misionero_cmo/data/mappers/firestore_parsers.dart';
import 'package:pasaporte_misionero_cmo/data/mappers/model_mappers.dart';
import 'package:pasaporte_misionero_cmo/data/repositories/firebase_stamp_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/qr_models.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/stamp_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';

void main() {
  group('FirestoreParsers', () {
    test('acepta Timestamp, ISO-8601 y milisegundos', () {
      final date = DateTime.utc(2000, 5, 1);
      expect(FirestoreParsers.optionalDate(Timestamp.fromDate(date))!.toUtc(), date);
      expect(FirestoreParsers.optionalDate('2000-05-01T00:00:00.000Z'), date);
      expect(FirestoreParsers.optionalDate(date.millisecondsSinceEpoch)!.toUtc(), date);
    });

    test('un dato dañado NO se reemplaza por la fecha actual', () {
      expect(FirestoreParsers.optionalDate('no-es-fecha'), isNull);
      expect(FirestoreParsers.optionalDate(null), isNull);
      expect(() => FirestoreParsers.requiredDate('???', 'campo'), throwsA(isA<DataParseException>()));
    });
  });

  group('ModelMappers.appUser', () {
    test('lee un pasaporte heredado (fechas ISO, arreglo stamps, isAdmin)', () {
      final user = ModelMappers.appUser('u1', {
        'username': 'mateo',
        'passportNumber': 'PM-2026-ABCD',
        'fullName': 'Mateo',
        'nationality': 'Salvadoreña',
        'cellId': 'c1',
        'dateOfBirth': '1990-01-02T00:00:00.000',
        'dateOfIssue': '2026-06-01T10:00:00.000',
        'isAdmin': true,
        'stamps': [
          {'stampId': 's1', 'dateObtained': Timestamp.fromDate(DateTime.utc(2026, 6, 2))},
          {'stampId': 's2', 'dateObtained': 'dañado'},
          {'sinId': true},
        ],
      });
      expect(user.dateOfBirth, DateTime(1990, 1, 2));
      // El campo heredado isAdmin no otorga rol: solo cuenta el claim.
      expect(user.storedRole, UserRole.user);
      expect(user.legacyStamps.map((s) => s.missionId), ['s1', 's2']);
      expect(user.legacyStamps[1].obtainedAt, isNull);
      expect(user.communityVisible, isTrue);
      expect(user.showNationality, isFalse);
      expect(user.notificationPrefs.newSermon, isTrue);
    });
  });

  group('ModelMappers.mission', () {
    test('omite ventanas dañadas y respeta el estado heredado', () {
      final mission = ModelMappers.mission('m1', {
        'name': 'Honduras',
        'isoCode': 'HN',
        'active': true,
        'location': const GeoPoint(14.1, -87.2),
        'schedule': [
          {
            'start': Timestamp.fromDate(DateTime.utc(2026, 10, 4, 15)),
            'end': Timestamp.fromDate(DateTime.utc(2026, 10, 4, 18)),
          },
          {'start': null, 'end': Timestamp.now()},
        ],
      });
      expect(mission.status, MissionStatus.active);
      expect(mission.schedules, hasLength(1));
      expect(mission.location, const GeoLocation(14.1, -87.2));
    });

    test('borrador a callable en milisegundos y mayúsculas', () {
      final payload = ModelMappers.missionDraftToCallable(
        MissionDraft(
          name: ' Guatemala ',
          isoCode: 'gt',
          imageUrl: '',
          location: const GeoLocation(14.6, -90.5),
          schedules: [MissionSchedule(start: DateTime.utc(2026, 1, 1), end: DateTime.utc(2026, 1, 1, 3))],
          status: MissionStatus.draft,
        ),
      );
      expect(payload.containsKey('missionId'), isFalse);
      expect(payload['name'], 'Guatemala');
      expect(payload['isoCode'], 'GT');
      expect(payload['status'], 'draft');
      expect((payload['schedules'] as List).single, {
        'start': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'end': DateTime.utc(2026, 1, 1, 3).millisecondsSinceEpoch,
      });
    });
  });

  group('ModelMappers.sermon', () {
    test('prédica con portada usa la portada; si no, la miniatura', () {
      final sermon = ModelMappers.sermon('s1', {
        'sourceUrl': 'https://youtu.be/dQw4w9WgXcQ',
        'title': 'Fe',
        'platform': 'youtube',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        'thumbnailUrl': 'https://i.ytimg.com/vi/x/hqdefault.jpg',
        'coverImageUrl': '',
        'active': true,
      });
      expect(sermon.platform, VideoPlatform.youtube);
      expect(sermon.displayImageUrl, contains('ytimg'));
    });

    test('documento sin publishedAt es dato dañado', () {
      expect(
        () => ModelMappers.sermon('s1', {'sourceUrl': 'https://a.com', 'title': 'x'}),
        throwsA(isA<DataParseException>()),
      );
    });

    test('al editar no se envían createdBy/createdAt (protegidos por las reglas)', () {
      final draft = SermonDraft(
        id: 's1',
        isNew: false,
        sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
        title: ' Fe ',
        platform: VideoPlatform.youtube,
        domain: 'youtu.be',
        publishedAt: DateTime.utc(2026),
        active: true,
      );
      final update = ModelMappers.sermonEditableFields(draft, editorUid: 'admin1');
      expect(update.containsKey('createdBy'), isFalse);
      expect(update.containsKey('createdAt'), isFalse);
      expect(update['title'], 'Fe');
      expect(update['updatedBy'], 'admin1');
      final create = ModelMappers.sermonCreate(draft, editorUid: 'admin1');
      expect(create['createdBy'], 'admin1');
      expect(create['deleted'], isFalse);
    });

    test('metadatos de video: válido y rechazado', () {
      final ok = ModelMappers.videoMetadata({
        'status': 'ok',
        'platform': 'youtube',
        'domain': 'youtube.com',
        'canonicalUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'metadataAvailable': true,
        'title': 'Título oficial',
      });
      expect((ok as VideoMetadataFound).metadata.title, 'Título oficial');
      final rejected = ModelMappers.videoMetadata({'status': 'invalidUrl', 'reason': 'notHttps'});
      expect((rejected as VideoUrlRejected).reason, contains('https://'));
      expect(ModelMappers.invalidUrlMessage('desconocido'), contains('no es válido'));
    });
  });

  test('redención migrada se identifica', () {
    final r = ModelMappers.redemption('m1', {'source': 'legacy_migration', 'redeemedAt': null});
    expect(r.source, RedemptionSource.legacyMigration);
    expect(r.redeemedAt, isNull);
  });

  group('FirebaseStampRepository (respuestas tipadas del servidor)', () {
    test('issueQrToken ok calcula vigencia y renovación', () {
      final result = FirebaseStampRepository.parseIssueResult({
        'status': 'ok',
        'token': 'PMCMO1.a.b',
        'missionId': 'm1',
        'missionName': 'Guatemala',
        'issuedAt': 1000,
        'expiresAt': 61000,
        'refreshAfterMs': 30000,
      });
      expect(result, isA<QrTokenIssued>());
      final issued = result as QrTokenIssued;
      expect(issued.lifetime, const Duration(seconds: 60));
      expect(issued.refreshAfter, const Duration(seconds: 30));
    });

    test('issueQrToken sin misión activa o con varias', () {
      expect(FirebaseStampRepository.parseIssueResult({'status': 'noActiveMission'}), isA<NoActiveMission>());
      final choose = FirebaseStampRepository.parseIssueResult({
        'status': 'chooseMission',
        'missions': [
          {'id': 'a', 'name': 'A'},
          {'id': 'b', 'name': 'B'},
        ],
      });
      expect((choose as ChooseMission).options.map((o) => o.id), ['a', 'b']);
    });

    test('redeemStamp: todos los estados', () {
      expect(
        FirebaseStampRepository.parseRedemptionResult({
          'status': 'confirmed',
          'missionId': 'm',
          'missionName': 'X',
          'redeemedAt': 5,
        }),
        isA<RedemptionConfirmed>(),
      );
      expect(
        FirebaseStampRepository.parseRedemptionResult({'status': 'alreadyRedeemed'}),
        isA<RedemptionAlreadyRedeemed>(),
      );
      expect(FirebaseStampRepository.parseRedemptionResult({'status': 'expired'}), isA<RedemptionExpired>());
      expect(FirebaseStampRepository.parseRedemptionResult({'status': 'invalid'}), isA<RedemptionInvalid>());
      expect(FirebaseStampRepository.parseRedemptionResult({'status': 'notFound'}), isA<RedemptionNotFound>());
      expect(
        FirebaseStampRepository.parseRedemptionResult({'status': 'inactive', 'missionName': 'X'}),
        isA<RedemptionInactive>(),
      );
      expect(
        FirebaseStampRepository.parseRedemptionResult({'status': 'outsideSchedule', 'missionName': 'X'}),
        isA<RedemptionOutsideSchedule>(),
      );
      expect(() => FirebaseStampRepository.parseRedemptionResult({'status': 'raro'}), throwsA(isA<UnknownException>()));
    });
  });

  group('mapFirebaseError', () {
    test('traduce códigos de Functions sin exponer detalles internos', () {
      expect(
        mapFirebaseError(FirebaseFunctionsException(code: 'permission-denied', message: 'x')),
        isA<PermissionDeniedException>(),
      );
      expect(mapFirebaseError(FirebaseFunctionsException(code: 'unavailable', message: 'x')), isA<NetworkException>());
      final validation = mapFirebaseError(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'El nombre es obligatorio.',
          details: {'field': 'name'},
        ),
      );
      expect(validation, isA<ValidationException>().having((e) => e.field, 'field', 'name'));
      expect(
        mapFirebaseError(FirebaseFunctionsException(code: 'internal', message: 'TypeError at line 3')),
        isA<UnknownException>(),
      );
      expect(friendlyErrorMessage(StateError('boom')), isNot(contains('boom')));
    });
  });
}
