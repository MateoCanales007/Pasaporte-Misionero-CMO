import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/stamp_redemption.dart';
import '../../domain/repositories/user_repository.dart';
import '../firebase_error_mapper.dart';
import '../mappers/model_mappers.dart';
import '../stream_extensions.dart';

class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository(this._db, this._functions, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('user_passport').doc(uid);

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : ModelMappers.appUser(uid, data);
    }).mapFirebaseErrors();
  }

  @override
  Future<void> createPassport(String uid, String username, NewPassport data) {
    return guardFirebase(() => _userDoc(uid).set(ModelMappers.newPassport(uid, username, data, _clock())));
  }

  @override
  Future<void> updateProfile(String uid, ProfileUpdate update) {
    if (update.isEmpty) return Future.value();
    return guardFirebase(() => _userDoc(uid).update(ModelMappers.profileUpdate(update)));
  }

  @override
  Stream<List<StampRedemption>> watchRedemptions(String uid) {
    return _userDoc(uid)
        .collection('redemptions')
        .snapshots()
        .map((snap) => [for (final doc in snap.docs) ModelMappers.redemption(doc.id, doc.data())])
        .mapFirebaseErrors();
  }

  @override
  Future<void> requestAccountDeletion({String? reason}) {
    return guardFirebase(() async {
      await _functions.httpsCallable('requestAccountDeletion').call<Object?>({
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
    });
  }

  @override
  Stream<List<Cell>> watchCells() {
    return _db.collection('cell').snapshots().map((snap) {
      final cells = [for (final doc in snap.docs) ModelMappers.cell(doc.id, doc.data())];
      cells.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return cells;
    }).mapFirebaseErrors();
  }
}
