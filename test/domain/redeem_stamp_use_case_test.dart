import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/core/errors/app_exception.dart';
import 'package:pasaporte_misionero_cmo/domain/models/pending_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/qr_models.dart';
import 'package:pasaporte_misionero_cmo/domain/use_cases/redeem_stamp_use_case.dart';

import '../helpers/fakes.dart';

void main() {
  const token = 'PMCMO1.eyJ2IjoxfQ.c2lnbmF0dXJh';
  late FakeStampRepository repo;
  late InMemoryPendingStore store;
  late RedeemStampUseCase useCase;
  var ids = 0;

  setUp(() {
    repo = FakeStampRepository();
    store = InMemoryPendingStore();
    ids = 0;
    useCase = RedeemStampUseCase(
      repository: repo,
      store: store,
      clock: () => DateTime.utc(2026, 10, 4, 16),
      idGenerator: () => 'p${ids++}',
    );
  });

  group('execute', () {
    test('devuelve la confirmación del servidor sin guardar nada local', () async {
      repo.redeemResults.add(const RedemptionConfirmed(missionId: 'm1', missionName: 'Guatemala'));
      final result = await useCase.execute('u1', token);
      expect(result, isA<RedemptionConfirmed>());
      expect(repo.redeemedTokens, [token]);
      expect(await store.load('u1'), isEmpty);
    });

    test('un duplicado lo informa el servidor', () async {
      repo.redeemResults.add(const RedemptionAlreadyRedeemed(missionId: 'm1', missionName: 'Guatemala'));
      expect(await useCase.execute('u1', token), isA<RedemptionAlreadyRedeemed>());
    });

    test('sin conexión queda pendiente y NO se confirma', () async {
      repo.redeemResults.add(const NetworkException());
      final result = await useCase.execute('u1', token);
      expect(result, isA<RedemptionQueued>());
      final pending = await store.load('u1');
      expect(pending, hasLength(1));
      expect(pending.single.token, token);
      expect(pending.single.status, SyncStatus.pending);
    });

    test('no duplica el mismo escaneo pendiente', () async {
      repo.redeemResults.addAll([const NetworkException(), const NetworkException()]);
      await useCase.execute('u1', token);
      await useCase.execute('u1', token);
      expect(await store.load('u1'), hasLength(1));
    });

    test('rechaza códigos QR antiguos (id fijo del sello) sin llamar al servidor', () async {
      final result = await useCase.execute('u1', 'ec612cb9-abc');
      expect(result, isA<RedemptionInvalid>().having((r) => r.isLegacyCode, 'isLegacyCode', isTrue));
      expect(repo.redeemedTokens, isEmpty);
    });

    test('otros errores se propagan (no se guardan como pendientes)', () async {
      repo.redeemResults.add(const PermissionDeniedException());
      await expectLater(useCase.execute('u1', token), throwsA(isA<PermissionDeniedException>()));
      expect(await store.load('u1'), isEmpty);
    });
  });

  group('retryPending', () {
    Future<void> seed(List<String> tokens) => store.save('u1', [
      for (final (i, t) in tokens.indexed) PendingRedemption(id: 'p$i', token: t, scannedAt: DateTime.utc(2026)),
    ]);

    test('confirmados se eliminan de la cola', () async {
      await seed([token]);
      repo.redeemResults.add(const RedemptionConfirmed(missionId: 'm1', missionName: 'Guatemala'));
      final summary = await useCase.retryPending('u1');
      expect(summary.confirmed.single.missionName, 'Guatemala');
      expect(await store.load('u1'), isEmpty);
    });

    test('un token vencido queda como fallido con explicación para volver a escanear', () async {
      await seed([token]);
      repo.redeemResults.add(const RedemptionExpired());
      final summary = await useCase.retryPending('u1');
      expect(summary.failed, 1);
      final item = (await store.load('u1')).single;
      expect(item.status, SyncStatus.failed);
      expect(item.failureMessage, contains('Vuelve a escanear'));
    });

    test('se detiene al primer error de red y conserva los pendientes', () async {
      await seed(['${token}a', '${token}b']);
      repo.redeemResults.add(const NetworkException());
      final summary = await useCase.retryPending('u1');
      expect(summary.stillPending, 2);
      expect(repo.redeemedTokens, hasLength(1));
    });

    test('dismiss elimina un fallido', () async {
      await seed([token]);
      await useCase.dismiss('u1', 'p0');
      expect(await store.load('u1'), isEmpty);
    });
  });

  test('PendingRedemption se serializa y descarta registros dañados', () {
    final item = PendingRedemption(id: 'x', token: token, scannedAt: DateTime.utc(2026, 1, 2), attempts: 2);
    final copy = PendingRedemption.tryFromJson(item.toJson())!;
    expect(copy.token, token);
    expect(copy.attempts, 2);
    expect(copy.scannedAt, DateTime.utc(2026, 1, 2));
    expect(PendingRedemption.tryFromJson({'id': 1}), isNull);
    expect(PendingRedemption.tryFromJson('basura'), isNull);
  });

  test('looksLikeSignedQrToken', () {
    expect(looksLikeSignedQrToken(token), isTrue);
    expect(looksLikeSignedQrToken('PMCMO1.solo-dos'), isFalse);
    expect(looksLikeSignedQrToken('stamp-id'), isFalse);
    expect(looksLikeSignedQrToken('PMCMO1.${'a' * 3000}.b'), isFalse);
  });
}
