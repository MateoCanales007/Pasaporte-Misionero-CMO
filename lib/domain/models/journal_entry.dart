/// Reflexión del diario privado de oración.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.text,
    this.missionId,
    this.missionName,
    this.createdAt,
    this.updatedAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final String text;
  final String? missionId;
  final String? missionName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `true` mientras el cambio no se ha sincronizado con el servidor.
  final bool hasPendingWrites;

  static const maxLength = 5000;
}
