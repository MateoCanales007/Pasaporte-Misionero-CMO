import '../models/pending_redemption.dart';
import '../models/qr_models.dart';

/// Operaciones server-side del flujo QR.
abstract interface class StampRepository {
  Future<QrIssueResult> issueQrToken({String? missionId});

  /// Lanza `NetworkException` si no hay conexión con el servidor.
  Future<RedemptionResult> redeem(String token);
}

/// Almacenamiento local de escaneos pendientes de validación, por usuario.
abstract interface class PendingRedemptionStore {
  Future<List<PendingRedemption>> load(String uid);

  Future<void> save(String uid, List<PendingRedemption> items);
}
