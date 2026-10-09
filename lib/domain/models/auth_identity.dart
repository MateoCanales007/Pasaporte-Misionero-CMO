import 'user_role.dart';

/// Usuario autenticado y su rol según los Custom Claims del token.
class AuthIdentity {
  const AuthIdentity({required this.uid, required this.username, required this.role});

  final String uid;
  final String username;
  final UserRole role;
}
