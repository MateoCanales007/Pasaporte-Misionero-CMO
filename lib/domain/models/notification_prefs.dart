/// Categorías de notificaciones que el usuario puede activar o desactivar.
class NotificationPrefs {
  const NotificationPrefs({
    this.newMission = true,
    this.missionReminder = true,
    this.newSermon = true,
    this.stampConfirmed = true,
  });

  final bool newMission;
  final bool missionReminder;
  final bool newSermon;
  final bool stampConfirmed;

  NotificationPrefs copyWith({bool? newMission, bool? missionReminder, bool? newSermon, bool? stampConfirmed}) {
    return NotificationPrefs(
      newMission: newMission ?? this.newMission,
      missionReminder: missionReminder ?? this.missionReminder,
      newSermon: newSermon ?? this.newSermon,
      stampConfirmed: stampConfirmed ?? this.stampConfirmed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.newMission == newMission &&
      other.missionReminder == missionReminder &&
      other.newSermon == newSermon &&
      other.stampConfirmed == stampConfirmed;

  @override
  int get hashCode => Object.hash(newMission, missionReminder, newSermon, stampConfirmed);
}
