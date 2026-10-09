/// Insignia por hitos o retos especiales. Es personal: no hay rankings.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    this.isChallenge = false,
  });

  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final bool isChallenge;

  bool get unlocked => current >= target;

  double get progress => target == 0 ? 1 : (current / target).clamp(0, 1).toDouble();
}
