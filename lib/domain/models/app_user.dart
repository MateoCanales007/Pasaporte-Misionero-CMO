import 'notification_prefs.dart';
import 'user_role.dart';

/// Sello registrado en el arreglo heredado `stamps` del pasaporte.
class LegacyStamp {
  const LegacyStamp({required this.missionId, this.obtainedAt});

  final String missionId;

  /// `null` cuando el dato original estaba ausente o dañado.
  final DateTime? obtainedAt;
}

/// Perfil privado del usuario (`user_passport/{uid}`).
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.passportNumber,
    required this.fullName,
    required this.nationality,
    required this.cellId,
    this.dateOfBirth,
    this.dateOfIssue,
    this.storedRole = UserRole.user,
    this.roleVersion = 0,
    this.stampCount = 0,
    this.communityVisible = true,
    this.showNationality = false,
    this.showCell = true,
    this.notificationPrefs = const NotificationPrefs(),
    this.deletionRequestedAt,
    this.legacyStamps = const [],
  });

  final String uid;
  final String username;
  final String passportNumber;
  final String fullName;
  final String nationality;
  final String cellId;
  final DateTime? dateOfBirth;
  final DateTime? dateOfIssue;

  /// Copia del rol guardada por el servidor (solo informativa; los permisos
  /// se basan en el claim del token).
  final UserRole storedRole;
  final int roleVersion;
  final int stampCount;
  final bool communityVisible;
  final bool showNationality;
  final bool showCell;
  final NotificationPrefs notificationPrefs;
  final DateTime? deletionRequestedAt;
  final List<LegacyStamp> legacyStamps;

  bool get hasRequestedDeletion => deletionRequestedAt != null;
}

/// Datos que el usuario puede editar de su propio perfil.
class ProfileUpdate {
  const ProfileUpdate({
    this.fullName,
    this.nationality,
    this.cellId,
    this.communityVisible,
    this.showNationality,
    this.showCell,
    this.notificationPrefs,
  });

  final String? fullName;
  final String? nationality;
  final String? cellId;
  final bool? communityVisible;
  final bool? showNationality;
  final bool? showCell;
  final NotificationPrefs? notificationPrefs;

  bool get isEmpty =>
      fullName == null &&
      nationality == null &&
      cellId == null &&
      communityVisible == null &&
      showNationality == null &&
      showCell == null &&
      notificationPrefs == null;
}

/// Datos para crear el pasaporte por primera vez.
class NewPassport {
  const NewPassport({
    required this.fullName,
    required this.dateOfBirth,
    required this.nationality,
    required this.cellId,
    this.communityVisible = true,
  });

  final String fullName;
  final DateTime dateOfBirth;
  final String nationality;
  final String cellId;
  final bool communityVisible;
}
