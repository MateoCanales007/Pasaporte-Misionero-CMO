import '../models/app_user.dart';
import '../models/cell.dart';
import '../models/stamp_redemption.dart';

abstract interface class UserRepository {
  Stream<AppUser?> watchUser(String uid);

  Future<void> createPassport(String uid, String username, NewPassport data);

  Future<void> updateProfile(String uid, ProfileUpdate update);

  /// Sellos confirmados por el servidor (subcolección `redemptions`).
  Stream<List<StampRedemption>> watchRedemptions(String uid);

  Future<void> requestAccountDeletion({String? reason});

  Stream<List<Cell>> watchCells();
}
