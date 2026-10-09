import '../../core/errors/app_exception.dart';
import '../models/pending_redemption.dart';
import '../models/qr_models.dart';
import '../repositories/stamp_repository.dart';

/// Resumen de un reintento de escaneos pendientes.
class RetrySummary {
  const RetrySummary({required this.confirmed, required this.failed, required this.stillPending});

  final List<RedemptionConfirmed> confirmed;
  final int failed;
  final int stillPending;
}

/// Canjea un QR con el servidor. Si no hay conexión guarda el escaneo como
/// "pendiente de validación"; nunca lo marca como confirmado localmente.
class RedeemStampUseCase {
  RedeemStampUseCase({
    required this._repository,
    required this._store,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => DateTime.now().microsecondsSinceEpoch.toString());

  final StampRepository _repository;
  final PendingRedemptionStore _store;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  Future<RedemptionResult> execute(String uid, String rawCode) async {
    final code = rawCode.trim();
    if (!looksLikeSignedQrToken(code)) {
      return RedemptionInvalid(isLegacyCode: code.isNotEmpty && !code.contains('.'));
    }
    try {
      return await _repository.redeem(code);
    } on NetworkException {
      final pending = await _store.load(uid);
      if (!pending.any((p) => p.token == code)) {
        pending.add(PendingRedemption(id: _idGenerator(), token: code, scannedAt: _clock()));
        await _store.save(uid, pending);
      }
      return const RedemptionQueued();
    }
  }

  /// Reintenta los escaneos pendientes. Se detiene al primer error de red.
  Future<RetrySummary> retryPending(String uid) async {
    final items = await _store.load(uid);
    final remaining = <PendingRedemption>[];
    final confirmed = <RedemptionConfirmed>[];
    var failed = 0;
    var offline = false;

    for (final item in items) {
      if (offline || item.status == SyncStatus.failed) {
        remaining.add(item);
        continue;
      }
      try {
        final result = await _repository.redeem(item.token);
        switch (result) {
          case RedemptionConfirmed():
            confirmed.add(result);
          case RedemptionAlreadyRedeemed():
            break;
          case RedemptionQueued():
            remaining.add(item);
          default:
            failed++;
            remaining.add(
              item.copyWith(
                status: SyncStatus.failed,
                attempts: item.attempts + 1,
                failureMessage: failureMessageFor(result),
              ),
            );
        }
      } on NetworkException {
        offline = true;
        remaining.add(item.copyWith(attempts: item.attempts + 1));
      }
    }

    await _store.save(uid, remaining);
    return RetrySummary(
      confirmed: confirmed,
      failed: failed,
      stillPending: remaining.where((p) => p.status == SyncStatus.pending).length,
    );
  }

  Future<void> dismiss(String uid, String pendingId) async {
    final items = await _store.load(uid);
    await _store.save(uid, items.where((p) => p.id != pendingId).toList());
  }

  /// Mensaje claro para el usuario cuando un escaneo pendiente no se pudo validar.
  static String failureMessageFor(RedemptionResult result) => switch (result) {
    RedemptionExpired() =>
      'El código venció antes de que pudiéramos validarlo. Vuelve a escanear el QR que muestra el encargado.',
    RedemptionInactive(:final missionName) => 'La misión "$missionName" ya no está activa.',
    RedemptionOutsideSchedule(:final missionName) => 'El código de "$missionName" no estaba en horario.',
    RedemptionNotFound() => 'Este código ya no corresponde a ninguna misión.',
    _ => 'El código no es válido. Vuelve a escanear el QR que muestra el encargado.',
  };
}
