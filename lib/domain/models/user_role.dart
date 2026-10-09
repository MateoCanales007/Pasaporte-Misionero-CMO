/// Rol del usuario. La fuente de verdad es el Custom Claim `role` del token
/// de Firebase Auth, asignado únicamente desde Cloud Functions.
enum UserRole {
  user,
  qrPresenter,
  admin;

  static UserRole fromClaim(Object? value) => switch (value) {
    'admin' => UserRole.admin,
    'qrPresenter' => UserRole.qrPresenter,
    _ => UserRole.user,
  };

  String get claimValue => name;

  String get label => switch (this) {
    UserRole.user => 'Misionero',
    UserRole.qrPresenter => 'Presentador de QR',
    UserRole.admin => 'Administrador',
  };

  bool get canPresentQr => this == UserRole.qrPresenter || this == UserRole.admin;

  bool get isAdmin => this == UserRole.admin;
}
