import '../models/app_user.dart';
import '../models/journal_entry.dart';
import '../models/public_profile.dart';
import '../models/testimonial.dart';
import '../models/user_role.dart';

/// Código temporal para que un usuario restablezca su contraseña.
class RecoveryCode {
  const RecoveryCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

abstract interface class CommunityRepository {
  /// Perfiles públicos. [includeHidden] solo funciona para administradores.
  Stream<List<PublicProfile>> watchProfiles({required bool includeHidden});

  /// Perfil privado de otro usuario (solo admin).
  Stream<AppUser?> watchPrivateProfile(String uid);

  Future<void> setUserRole(String uid, UserRole role);

  Future<RecoveryCode> createRecoveryCode(String uid);
}

abstract interface class TestimonialRepository {
  Stream<List<Testimonial>> watchApproved();

  Stream<List<Testimonial>> watchMine(String uid);

  /// Solo admin.
  Stream<List<Testimonial>> watchPending();

  Future<void> submit({required String uid, required String displayName, required String text, String? missionId});

  Future<void> moderate(String id, TestimonialStatus status, {required String moderatorUid});

  Future<void> delete(String id);
}

abstract interface class JournalRepository {
  Stream<List<JournalEntry>> watchEntries(String uid);

  /// Crea (si [entryId] es `null`) o actualiza una reflexión.
  Future<void> save(String uid, {String? entryId, required String text, String? missionId, String? missionName});

  Future<void> delete(String uid, String entryId);
}
