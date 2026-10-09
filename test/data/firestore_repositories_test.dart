import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/data/repositories/firebase_community_repository.dart';
import 'package:pasaporte_misionero_cmo/data/repositories/firebase_sermon_repository.dart';
import 'package:pasaporte_misionero_cmo/data/repositories/firebase_user_repository.dart';
import 'package:pasaporte_misionero_cmo/domain/models/app_user.dart';
import 'package:pasaporte_misionero_cmo/domain/models/notification_prefs.dart';
import 'package:pasaporte_misionero_cmo/domain/models/sermon.dart';
import 'package:pasaporte_misionero_cmo/domain/models/testimonial.dart';

class _NoFunctions extends Fake implements FirebaseFunctions {}

class _NoStorage extends Fake implements FirebaseStorage {}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('FirebaseUserRepository', () {
    late FirebaseUserRepository repo;

    setUp(() => repo = FirebaseUserRepository(db, _NoFunctions(), clock: () => DateTime.utc(2026, 10, 6)));

    test('crea el pasaporte sin campos de rol ni sellos', () async {
      await repo.createPassport(
        'abcd1234',
        'maria',
        NewPassport(
          fullName: ' María ',
          dateOfBirth: DateTime.utc(1950, 3, 2),
          nationality: 'Salvadoreña',
          cellId: 'c1',
        ),
      );
      final data = (await db.collection('user_passport').doc('abcd1234').get()).data()!;
      expect(data['username'], 'maria');
      expect(data['fullName'], 'María');
      expect(data['passportNumber'], 'PM-2026-ABCD');
      expect(data['stamps'], isEmpty);
      expect(data['dateOfBirth'], isA<Timestamp>());
      for (final forbidden in ['isAdmin', 'canShowQR', 'role', 'roleVersion', 'stampCount']) {
        expect(data.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('actualiza solo los campos editables enviados', () async {
      await db.collection('user_passport').doc('u1').set({'fullName': 'Ana', 'cellId': 'c1', 'isAdmin': false});
      await repo.updateProfile(
        'u1',
        const ProfileUpdate(communityVisible: false, notificationPrefs: NotificationPrefs(newSermon: false)),
      );
      final data = (await db.collection('user_passport').doc('u1').get()).data()!;
      expect(data['fullName'], 'Ana');
      expect(data['communityVisible'], isFalse);
      expect((data['notificationPrefs'] as Map)['newSermon'], isFalse);
      expect(data['isAdmin'], isFalse);
    });

    test('lee pasaporte, sellos del servidor y células ordenadas', () async {
      await db.collection('user_passport').doc('u1').set({'fullName': 'Ana', 'username': 'ana'});
      await db.collection('user_passport').doc('u1').collection('redemptions').doc('m1').set({
        'missionName': 'Guatemala',
        'redeemedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
        'source': 'qr',
      });
      await db.collection('cell').doc('b').set({'name': 'Zacatecoluca'});
      await db.collection('cell').doc('a').set({'name': 'Apopa'});

      expect((await repo.watchUser('u1').first)!.fullName, 'Ana');
      expect(await repo.watchUser('nadie').first, isNull);
      expect((await repo.watchRedemptions('u1').first).single.missionName, 'Guatemala');
      expect((await repo.watchCells().first).map((c) => c.name), ['Apopa', 'Zacatecoluca']);
    });
  });

  group('FirebaseSermonRepository', () {
    late FirebaseSermonRepository repo;

    SermonDraft draft({required bool isNew, String id = 's1', String title = 'Fe'}) => SermonDraft(
      id: id,
      isNew: isNew,
      sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
      title: title,
      platform: VideoPlatform.youtube,
      domain: 'youtu.be',
      publishedAt: DateTime.utc(2026, 9, 1),
      active: true,
    );

    setUp(() => repo = FirebaseSermonRepository(db, _NoFunctions(), _NoStorage()));

    test('crear registra al autor; editar no cambia createdBy', () async {
      await repo.save(draft(isNew: true), editorUid: 'admin1');
      await repo.save(draft(isNew: false, title: 'Fe y obras'), editorUid: 'admin2');
      final data = (await db.collection('sermons').doc('s1').get()).data()!;
      expect(data['createdBy'], 'admin1');
      expect(data['updatedBy'], 'admin2');
      expect(data['title'], 'Fe y obras');
      expect(data['deleted'], isFalse);
    });

    test('los usuarios solo reciben prédicas activas, más recientes primero', () async {
      Future<void> add(String id, bool active, int day) => db.collection('sermons').doc(id).set({
        'sourceUrl': 'https://youtu.be/dQw4w9WgXcQ',
        'title': id,
        'platform': 'youtube',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 9, day)),
        'active': active,
      });
      await add('vieja', true, 1);
      await add('nueva', true, 20);
      await add('oculta', false, 25);
      expect((await repo.watchSermons(includeHidden: false).first).map((s) => s.id), ['nueva', 'vieja']);
      expect((await repo.watchSermons(includeHidden: true).first).map((s) => s.id), ['oculta', 'nueva', 'vieja']);
    });

    test('borrado recuperable y restauración', () async {
      await repo.save(draft(isNew: true), editorUid: 'admin1');
      await repo.softDelete('s1', editorUid: 'admin1');
      var data = (await db.collection('sermons').doc('s1').get()).data()!;
      expect(data['deleted'], isTrue);
      expect(data['active'], isFalse);
      expect(data['deletedAt'], isNotNull);

      await repo.restore('s1', editorUid: 'admin1');
      data = (await db.collection('sermons').doc('s1').get()).data()!;
      expect(data['deleted'], isFalse);
      expect(data['active'], isFalse, reason: 'se recupera oculta hasta que un admin la publique');
    });
  });

  group('Comunidad, testimonios y diario', () {
    test('la comunidad pública solo lista perfiles visibles', () async {
      final repo = FirebaseCommunityRepository(db, _NoFunctions());
      await db.collection('public_profiles').doc('a').set({'displayName': 'Ana', 'communityVisible': true});
      await db.collection('public_profiles').doc('b').set({'displayName': 'Beto', 'communityVisible': false});
      expect((await repo.watchProfiles(includeHidden: false).first).map((p) => p.uid), ['a']);
      expect((await repo.watchProfiles(includeHidden: true).first).map((p) => p.uid), ['a', 'b']);
    });

    test('un testimonio nace pendiente y el admin lo modera', () async {
      final repo = FirebaseTestimonialRepository(db);
      await repo.submit(uid: 'u1', displayName: 'Ana', text: 'Dios es fiel en todo momento');
      final pending = await repo.watchPending().first;
      expect(pending.single.status, TestimonialStatus.pending);
      expect(await repo.watchApproved().first, isEmpty);

      await repo.moderate(pending.single.id, TestimonialStatus.approved, moderatorUid: 'admin1');
      final approved = await repo.watchApproved().first;
      expect(approved.single.text, 'Dios es fiel en todo momento');
      final raw = (await db.collection('testimonials').doc(pending.single.id).get()).data()!;
      expect(raw['moderatedBy'], 'admin1');
    });

    test('el diario guarda, edita y elimina reflexiones privadas', () async {
      final repo = FirebaseJournalRepository(db);
      await repo.save('u1', text: 'Gracias Señor', missionId: 'm1', missionName: 'Guatemala');
      var entries = await repo.watchEntries('u1').first;
      expect(entries.single.missionName, 'Guatemala');

      await repo.save('u1', entryId: entries.single.id, text: 'Gracias por todo');
      entries = await repo.watchEntries('u1').first;
      expect(entries.single.text, 'Gracias por todo');

      await repo.delete('u1', entries.single.id);
      expect(await repo.watchEntries('u1').first, isEmpty);
      expect(await repo.watchEntries('otro').first, isEmpty);
    });
  });
}
