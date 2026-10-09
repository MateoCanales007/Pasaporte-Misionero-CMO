/// Prefijo de los códigos QR firmados por el servidor.
const qrTokenPrefix = 'PMCMO1.';

bool looksLikeSignedQrToken(String raw) =>
    raw.startsWith(qrTokenPrefix) && raw.split('.').length == 3 && raw.length <= 2048;

/// Resultado de pedir un QR temporal al servidor.
sealed class QrIssueResult {
  const QrIssueResult();
}

class QrTokenIssued extends QrIssueResult {
  const QrTokenIssued({
    required this.token,
    required this.missionId,
    required this.missionName,
    required this.lifetime,
    required this.refreshAfter,
  });

  final String token;
  final String missionId;
  final String missionName;

  /// Vigencia total del token según el servidor (expiresAt − issuedAt).
  final Duration lifetime;

  /// Momento recomendado para pedir el siguiente token.
  final Duration refreshAfter;
}

class NoActiveMission extends QrIssueResult {
  const NoActiveMission();
}

class ChooseMission extends QrIssueResult {
  const ChooseMission(this.options);

  final List<MissionOption> options;
}

class MissionOption {
  const MissionOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Resultado de canjear un QR. Todas las variantes provienen del servidor,
/// excepto [RedemptionQueued], que indica que se guardó para reintentar.
sealed class RedemptionResult {
  const RedemptionResult();
}

class RedemptionConfirmed extends RedemptionResult {
  const RedemptionConfirmed({required this.missionId, required this.missionName, this.redeemedAt});

  final String missionId;
  final String missionName;
  final DateTime? redeemedAt;
}

class RedemptionAlreadyRedeemed extends RedemptionResult {
  const RedemptionAlreadyRedeemed({required this.missionId, required this.missionName});

  final String missionId;
  final String missionName;
}

class RedemptionExpired extends RedemptionResult {
  const RedemptionExpired();
}

class RedemptionInvalid extends RedemptionResult {
  const RedemptionInvalid({this.isLegacyCode = false});

  /// El QR es del formato antiguo (id fijo del sello).
  final bool isLegacyCode;
}

class RedemptionNotFound extends RedemptionResult {
  const RedemptionNotFound();
}

class RedemptionInactive extends RedemptionResult {
  const RedemptionInactive(this.missionName);

  final String missionName;
}

class RedemptionOutsideSchedule extends RedemptionResult {
  const RedemptionOutsideSchedule(this.missionName);

  final String missionName;
}

class RedemptionQueued extends RedemptionResult {
  const RedemptionQueued();
}
