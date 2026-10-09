/// Origen de un sello obtenido.
enum RedemptionSource { qr, legacyMigration, legacyArray }

/// Sello obtenido por el usuario (`user_passport/{uid}/redemptions/{missionId}`
/// o, temporalmente, el arreglo heredado `stamps`).
class StampRedemption {
  const StampRedemption({required this.missionId, required this.source, this.missionName, this.redeemedAt});

  final String missionId;
  final String? missionName;

  /// `null` si el dato heredado estaba dañado o ausente.
  final DateTime? redeemedAt;
  final RedemptionSource source;
}
