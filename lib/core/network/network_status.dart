/// Estado de la conexión del dispositivo (abstracción para poder probar).
abstract interface class NetworkStatus {
  /// Emite `true` cada vez que el dispositivo recupera alguna conexión.
  Stream<bool> get onlineChanges;

  Future<bool> isOffline();
}
