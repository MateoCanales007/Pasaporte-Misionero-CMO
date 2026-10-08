import '../models/app_user.dart';
import '../models/stamp_redemption.dart';

/// Une los sellos del servidor con los del arreglo heredado (compatibilidad
/// hasta completar la migración). Sin duplicados; los más recientes primero.
List<StampRedemption> mergePassportStamps(List<StampRedemption> server, List<LegacyStamp> legacy) {
  final byMission = <String, StampRedemption>{for (final r in server) r.missionId: r};
  for (final stamp in legacy) {
    byMission.putIfAbsent(
      stamp.missionId,
      () => StampRedemption(
        missionId: stamp.missionId,
        redeemedAt: stamp.obtainedAt,
        source: RedemptionSource.legacyArray,
      ),
    );
  }
  final merged = byMission.values.toList()
    ..sort((a, b) {
      final da = a.redeemedAt;
      final db = b.redeemedAt;
      if (da == null && db == null) return a.missionId.compareTo(b.missionId);
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
  return merged;
}
