import '../models/auth_identity.dart';

/// Resultado de restablecer la contraseña con un código de recuperación.
enum PasswordRecoveryResult { success, invalidCode, weakPassword }

abstract interface class AuthRepository {
  /// Emite la identidad (con rol) cada vez que cambia la sesión o el token.
  Stream<AuthIdentity?> watchIdentity();

  AuthIdentity? get currentIdentity;

  /// Devuelve un mensaje de error en español o `null` si tuvo éxito.
  Future<String?> login(String username, String password);

  /// Devuelve un mensaje de error en español o `null` si tuvo éxito.
  Future<String?> register(String username, String password);

  Future<void> logout();

  /// Fuerza la actualización del token para leer roles recién asignados.
  Future<void> refreshClaims();

  Future<PasswordRecoveryResult> recoverWithCode({
    required String username,
    required String code,
    required String newPassword,
  });
}
