import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/pending_redemption.dart';
import '../../domain/use_cases/redeem_stamp_use_case.dart';
import 'repository_providers.dart';
import 'session_providers.dart';

/// Escaneos guardados sin conexión, pendientes de validar con el servidor.
final pendingRedemptionsProvider = AsyncNotifierProvider<PendingRedemptionsNotifier, List<PendingRedemption>>(
  PendingRedemptionsNotifier.new,
);

class PendingRedemptionsNotifier extends AsyncNotifier<List<PendingRedemption>> {
  bool _retrying = false;

  @override
  Future<List<PendingRedemption>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const [];
    return ref.watch(pendingRedemptionStoreProvider).load(uid);
  }

  Future<void> reload() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = AsyncData(await ref.read(pendingRedemptionStoreProvider).load(uid));
  }

  /// Reintenta los pendientes. Devuelve `null` si no había nada que enviar.
  Future<RetrySummary?> retry() async {
    final uid = ref.read(currentUidProvider);
    final current = state.value ?? const [];
    if (uid == null || _retrying || !current.any((p) => p.status == SyncStatus.pending)) return null;
    _retrying = true;
    try {
      final summary = await ref.read(redeemStampUseCaseProvider).retryPending(uid);
      await reload();
      return summary;
    } finally {
      _retrying = false;
    }
  }

  Future<void> dismiss(String id) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    await ref.read(redeemStampUseCaseProvider).dismiss(uid, id);
    await reload();
  }
}
