/// Mensaje recibido mientras la app está abierta.
class InAppNotification {
  const InAppNotification({required this.title, required this.body});

  final String title;
  final String body;
}

abstract interface class NotificationRepository {
  bool get isSupported;

  /// Pide permiso y registra este dispositivo. Devuelve `false` si el usuario
  /// no concedió el permiso.
  Future<bool> enableOnThisDevice(String uid);

  /// Vuelve a registrar el token si el permiso ya estaba concedido.
  Future<void> refreshRegistration(String uid);

  Future<void> disableOnThisDevice(String uid);

  Future<bool> isEnabledOnThisDevice();

  Stream<InAppNotification> get foregroundMessages;
}
