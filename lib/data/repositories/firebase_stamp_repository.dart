import 'package:cloud_functions/cloud_functions.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/qr_models.dart';
import '../../domain/repositories/stamp_repository.dart';
import '../firebase_error_mapper.dart';

/// Flujo QR server-side: emisión de tokens firmados y canje transaccional.
class FirebaseStampRepository implements StampRepository {
  FirebaseStampRepository(
    this._functions, {
    required this._isOffline,
    required this._appVersion,
    required this._platform,
  });

  final FirebaseFunctions _functions;
  final Future<bool> Function() _isOffline;
  final String _appVersion;
  final String _platform;

  @override
  Future<QrIssueResult> issueQrToken({String? missionId}) {
    return guardFirebase(() async {
      final result = await _functions.httpsCallable('issueQrToken').call<Object?>({'missionId': ?missionId});
      return parseIssueResult(result.data);
    });
  }

  @override
  Future<RedemptionResult> redeem(String token) async {
    if (await _isOffline()) throw const NetworkException();
    try {
      final result = await _functions
          .httpsCallable('redeemStamp', options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
          .call<Object?>({'token': token, 'appVersion': _appVersion, 'platform': _platform});
      return parseRedemptionResult(result.data);
    } catch (error) {
      final mapped = mapFirebaseError(error);
      // En web los fallos de red llegan como "internal": se confirma con la conectividad.
      if (mapped is UnknownException && await _isOffline()) throw const NetworkException();
      throw mapped;
    }
  }

  static QrIssueResult parseIssueResult(Object? raw) {
    if (raw is! Map) throw const UnknownException();
    switch (raw['status']) {
      case 'ok':
        final issuedAt = raw['issuedAt'];
        final expiresAt = raw['expiresAt'];
        final refreshAfter = raw['refreshAfterMs'];
        if (raw['token'] is! String || issuedAt is! num || expiresAt is! num) throw const UnknownException();
        final lifetime = Duration(milliseconds: (expiresAt - issuedAt).toInt());
        return QrTokenIssued(
          token: raw['token'] as String,
          missionId: raw['missionId']?.toString() ?? '',
          missionName: raw['missionName']?.toString() ?? 'Misión',
          lifetime: lifetime,
          refreshAfter: refreshAfter is num
              ? Duration(milliseconds: refreshAfter.toInt())
              : Duration(milliseconds: lifetime.inMilliseconds ~/ 2),
        );
      case 'noActiveMission':
        return const NoActiveMission();
      case 'chooseMission':
        final missions = raw['missions'];
        return ChooseMission([
          if (missions is List)
            for (final m in missions)
              if (m is Map) MissionOption(id: m['id'].toString(), name: m['name']?.toString() ?? 'Misión'),
        ]);
      default:
        throw const UnknownException();
    }
  }

  static RedemptionResult parseRedemptionResult(Object? raw) {
    if (raw is! Map) throw const UnknownException();
    final missionId = raw['missionId']?.toString() ?? '';
    final missionName = raw['missionName']?.toString() ?? 'la misión';
    return switch (raw['status']) {
      'confirmed' => RedemptionConfirmed(
        missionId: missionId,
        missionName: missionName,
        redeemedAt: raw['redeemedAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((raw['redeemedAt'] as num).toInt())
            : null,
      ),
      'alreadyRedeemed' => RedemptionAlreadyRedeemed(missionId: missionId, missionName: missionName),
      'expired' => const RedemptionExpired(),
      'invalid' => const RedemptionInvalid(),
      'notFound' => const RedemptionNotFound(),
      'inactive' => RedemptionInactive(missionName),
      'outsideSchedule' => RedemptionOutsideSchedule(missionName),
      _ => throw const UnknownException(),
    };
  }
}
