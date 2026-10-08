import '../../core/utils/business_time.dart';
import '../models/achievement.dart';
import '../models/mission.dart';
import '../models/stamp_redemption.dart';

/// Calcula insignias personales a partir de los sellos obtenidos.
abstract final class AchievementsCalculator {
  static const _milestones = [
    (id: 'first', target: 1, title: 'Primer sello', description: 'Obtuviste tu primer sello misionero.'),
    (id: 'three', target: 3, title: 'Misionero constante', description: 'Completa 3 misiones.'),
    (id: 'five', target: 5, title: 'Intercesor fiel', description: 'Completa 5 misiones.'),
    (id: 'ten', target: 10, title: 'Embajador de oración', description: 'Completa 10 misiones.'),
    (id: 'twentyfive', target: 25, title: 'Pasaporte de gracia', description: 'Completa 25 misiones.'),
  ];

  static List<Achievement> compute(List<StampRedemption> stamps, Map<String, Mission> catalog) {
    final total = stamps.length;
    final achievements = [
      for (final m in _milestones)
        Achievement(id: m.id, title: m.title, description: m.description, current: total, target: m.target),
    ];

    final nations = stamps
        .map((s) => catalog[s.missionId]?.isoCode)
        .whereType<String>()
        .where((code) => code.isNotEmpty && code != 'GLOBAL')
        .toSet()
        .length;
    achievements.add(
      Achievement(
        id: 'nations',
        title: 'Explorador de naciones',
        description: 'Intercede por 5 naciones distintas.',
        current: nations,
        target: 5,
        isChallenge: true,
      ),
    );

    achievements.add(
      Achievement(
        id: 'streak',
        title: 'Tres meses seguidos',
        description: 'Obtén al menos un sello durante 3 meses consecutivos.',
        current: longestMonthlyStreak(stamps),
        target: 3,
        isChallenge: true,
      ),
    );
    return achievements;
  }

  /// Mayor cantidad de meses consecutivos (hora de El Salvador) con sellos.
  static int longestMonthlyStreak(List<StampRedemption> stamps) {
    final months =
        stamps
            .map((s) => s.redeemedAt)
            .whereType<DateTime>()
            .map((d) {
              final local = BusinessTime.toWallClock(d);
              return local.year * 12 + (local.month - 1);
            })
            .toSet()
            .toList()
          ..sort();
    var best = 0;
    var current = 0;
    int? previous;
    for (final month in months) {
      current = previous != null && month == previous + 1 ? current + 1 : 1;
      if (current > best) best = current;
      previous = month;
    }
    return best;
  }
}
