import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/domain/models/app_user.dart';
import 'package:pasaporte_misionero_cmo/domain/models/mission.dart';
import 'package:pasaporte_misionero_cmo/domain/models/stamp_redemption.dart';
import 'package:pasaporte_misionero_cmo/domain/models/user_role.dart';
import 'package:pasaporte_misionero_cmo/domain/use_cases/achievements_calculator.dart';
import 'package:pasaporte_misionero_cmo/domain/use_cases/passport_stamps.dart';

void main() {
  StampRedemption stamp(String id, DateTime? at) =>
      StampRedemption(missionId: id, redeemedAt: at, source: RedemptionSource.qr);

  group('mergePassportStamps', () {
    test('une servidor y arreglo heredado sin duplicados, prefiriendo el servidor', () {
      final merged = mergePassportStamps(
        [stamp('a', DateTime.utc(2026, 3))],
        [
          LegacyStamp(missionId: 'a', obtainedAt: DateTime.utc(2025)),
          LegacyStamp(missionId: 'b', obtainedAt: DateTime.utc(2026, 1)),
        ],
      );
      expect(merged.map((s) => s.missionId), ['a', 'b']);
      expect(merged.first.source, RedemptionSource.qr);
      expect(merged.last.source, RedemptionSource.legacyArray);
    });

    test('las fechas dañadas (null) van al final y no se inventan', () {
      final merged = mergePassportStamps([stamp('x', null), stamp('y', DateTime.utc(2026))], const []);
      expect(merged.map((s) => s.missionId), ['y', 'x']);
      expect(merged.last.redeemedAt, isNull);
    });
  });

  group('AchievementsCalculator', () {
    Mission mission(String id, String iso) => Mission(id: id, name: id, isoCode: iso, status: MissionStatus.active);

    test('hitos según la cantidad de misiones', () {
      final stamps = [for (var i = 0; i < 3; i++) stamp('m$i', DateTime.utc(2026, i + 1, 10))];
      final result = AchievementsCalculator.compute(stamps, const {});
      expect(result.firstWhere((a) => a.id == 'first').unlocked, isTrue);
      expect(result.firstWhere((a) => a.id == 'three').unlocked, isTrue);
      expect(result.firstWhere((a) => a.id == 'five').unlocked, isFalse);
      expect(result.firstWhere((a) => a.id == 'five').progress, closeTo(0.6, 0.001));
    });

    test('reto de naciones distintas ignora GLOBAL', () {
      final catalog = {
        for (final (id, iso) in [('a', 'GT'), ('b', 'HN'), ('c', 'GT'), ('d', 'GLOBAL')]) id: mission(id, iso),
      };
      final stamps = [
        for (final id in ['a', 'b', 'c', 'd']) stamp(id, DateTime.utc(2026)),
      ];
      final nations = AchievementsCalculator.compute(stamps, catalog).firstWhere((a) => a.id == 'nations');
      expect(nations.current, 2);
      expect(nations.isChallenge, isTrue);
    });

    test('racha mensual usa la hora de El Salvador', () {
      // 1 de febrero 03:00 UTC = 31 de enero 21:00 en El Salvador.
      final stamps = [
        stamp('a', DateTime.utc(2026, 2, 1, 3)),
        stamp('b', DateTime.utc(2026, 2, 15)),
        stamp('c', DateTime.utc(2026, 3, 15)),
        stamp('d', DateTime.utc(2026, 6, 15)),
      ];
      expect(AchievementsCalculator.longestMonthlyStreak(stamps), 3);
    });
  });

  group('UserRole', () {
    test('fromClaim', () {
      expect(UserRole.fromClaim('admin'), UserRole.admin);
      expect(UserRole.fromClaim('qrPresenter'), UserRole.qrPresenter);
      expect(UserRole.fromClaim(null), UserRole.user);
      expect(UserRole.fromClaim('superadmin'), UserRole.user);
      expect(UserRole.fromClaim(true), UserRole.user);
    });

    test('permisos de presentación', () {
      expect(UserRole.admin.canPresentQr, isTrue);
      expect(UserRole.qrPresenter.canPresentQr, isTrue);
      expect(UserRole.user.canPresentQr, isFalse);
      expect(UserRole.qrPresenter.isAdmin, isFalse);
    });
  });
}
