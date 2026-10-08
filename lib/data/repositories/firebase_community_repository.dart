import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/journal_entry.dart';
import '../../domain/models/public_profile.dart';
import '../../domain/models/testimonial.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/community_repository.dart';
import '../firebase_error_mapper.dart';
import '../mappers/model_mappers.dart';
import '../stream_extensions.dart';

class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<PublicProfile>> watchProfiles({required bool includeHidden}) {
    final collection = _db.collection('public_profiles');
    final Query<Map<String, dynamic>> query = includeHidden
        ? collection.orderBy('displayName')
        : collection.where('communityVisible', isEqualTo: true).orderBy('displayName');
    return query
        .snapshots()
        .map((snap) => [for (final doc in snap.docs) ModelMappers.publicProfile(doc.id, doc.data())])
        .mapFirebaseErrors();
  }

  @override
  Stream<AppUser?> watchPrivateProfile(String uid) {
    return _db
        .collection('user_passport')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data() == null ? null : ModelMappers.appUser(uid, snap.data()!))
        .mapFirebaseErrors();
  }

  @override
  Future<void> setUserRole(String uid, UserRole role) {
    return guardFirebase(() async {
      await _functions.httpsCallable('setUserRole').call<Object?>({'uid': uid, 'role': role.claimValue});
    });
  }

  @override
  Future<RecoveryCode> createRecoveryCode(String uid) {
    return guardFirebase(() async {
      final result = await _functions.httpsCallable('createRecoveryCode').call<Object?>({'uid': uid});
      final data = result.data;
      if (data is! Map || data['code'] is! String || data['expiresAt'] is! num) throw const UnknownException();
      return RecoveryCode(
        code: data['code'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch((data['expiresAt'] as num).toInt()),
      );
    });
  }
}

class FirebaseTestimonialRepository implements TestimonialRepository {
  FirebaseTestimonialRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _testimonials => _db.collection('testimonials');

  Stream<List<Testimonial>> _watch(Query<Map<String, dynamic>> query) {
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => [for (final doc in snap.docs) ModelMappers.testimonial(doc.id, doc.data())])
        .mapFirebaseErrors();
  }

  @override
  Stream<List<Testimonial>> watchApproved() => _watch(_testimonials.where('status', isEqualTo: 'approved'));

  @override
  Stream<List<Testimonial>> watchMine(String uid) => _watch(_testimonials.where('userId', isEqualTo: uid));

  @override
  Stream<List<Testimonial>> watchPending() => _watch(_testimonials.where('status', isEqualTo: 'pending'));

  @override
  Future<void> submit({required String uid, required String displayName, required String text, String? missionId}) {
    return guardFirebase(
      () => _testimonials.add({
        'userId': uid,
        'displayName': displayName.trim(),
        'text': text.trim(),
        'missionId': missionId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> moderate(String id, TestimonialStatus status, {required String moderatorUid}) {
    return guardFirebase(
      () => _testimonials.doc(id).update({
        'status': status.name,
        'moderatedBy': moderatorUid,
        'moderatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> delete(String id) => guardFirebase(() => _testimonials.doc(id).delete());
}

class FirebaseJournalRepository implements JournalRepository {
  FirebaseJournalRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String uid) =>
      _db.collection('user_passport').doc(uid).collection('journal');

  @override
  Stream<List<JournalEntry>> watchEntries(String uid) {
    return _entries(uid)
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => [
            for (final doc in snap.docs)
              ModelMappers.journalEntry(doc.id, doc.data(), hasPendingWrites: doc.metadata.hasPendingWrites),
          ],
        )
        .mapFirebaseErrors();
  }

  /// El Future se completa cuando el servidor confirma. Sin conexión Firestore
  /// guarda el cambio localmente (la lista lo muestra como "pendiente").
  @override
  Future<void> save(String uid, {String? entryId, required String text, String? missionId, String? missionName}) {
    final collection = _entries(uid);
    return guardFirebase(
      () => entryId == null
          ? collection.doc().set({
              'text': text.trim(),
              'missionId': missionId,
              'missionName': missionName,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            })
          : collection.doc(entryId).update({'text': text.trim(), 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  @override
  Future<void> delete(String uid, String entryId) => guardFirebase(() => _entries(uid).doc(entryId).delete());
}
