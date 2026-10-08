/// Coordenadas geográficas.
class GeoLocation {
  const GeoLocation(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid => latitude.isFinite && longitude.isFinite && latitude.abs() <= 90 && longitude.abs() <= 180;

  @override
  bool operator ==(Object other) => other is GeoLocation && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Ventana de horario de una misión. [start] y [end] son instantes (UTC).
class MissionSchedule {
  const MissionSchedule({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool get isValid => start.isBefore(end);

  /// Abierta en [now] (inicio inclusivo, fin exclusivo).
  bool contains(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  bool overlaps(MissionSchedule other) => start.isBefore(other.end) && other.start.isBefore(end);

  MissionSchedule copyWith({DateTime? start, DateTime? end}) =>
      MissionSchedule(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) => other is MissionSchedule && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

enum MissionStatus {
  draft,
  active,
  inactive;

  static MissionStatus parse(Object? status, {Object? legacyActive}) => switch (status) {
    'draft' => MissionStatus.draft,
    'active' => MissionStatus.active,
    'inactive' => MissionStatus.inactive,
    _ => legacyActive == true ? MissionStatus.active : MissionStatus.inactive,
  };

  String get label => switch (this) {
    MissionStatus.draft => 'Borrador',
    MissionStatus.active => 'Activa',
    MissionStatus.inactive => 'Inactiva',
  };
}

/// Estado que se muestra al usuario, derivado del estado y los horarios.
enum MissionPhase {
  draft('Borrador'),
  open('Abierta ahora'),
  upcoming('Próxima'),
  finished('Finalizada'),
  inactive('Inactiva');

  const MissionPhase(this.label);

  final String label;
}

/// Misión / sello del catálogo (`stamp/{id}`).
class Mission {
  const Mission({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.status,
    this.imageUrl = '',
    this.location,
    this.placeId,
    this.schedules = const [],
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String isoCode;
  final MissionStatus status;
  final String imageUrl;
  final GeoLocation? location;
  final String? placeId;
  final List<MissionSchedule> schedules;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status == MissionStatus.draft;

  List<MissionSchedule> get sortedSchedules => [...schedules]..sort((a, b) => a.start.compareTo(b.start));

  bool isOpenAt(DateTime now) => status == MissionStatus.active && schedules.any((s) => s.contains(now));

  bool isFinishedAt(DateTime now) => schedules.isNotEmpty && schedules.every((s) => !now.isBefore(s.end));

  /// Ventana en curso o la siguiente por comenzar; `null` si ya no hay.
  MissionSchedule? nextWindow(DateTime now) {
    for (final schedule in sortedSchedules) {
      if (now.isBefore(schedule.end)) return schedule;
    }
    return null;
  }

  MissionPhase phaseAt(DateTime now) {
    if (status == MissionStatus.draft) return MissionPhase.draft;
    if (isFinishedAt(now)) return MissionPhase.finished;
    if (status == MissionStatus.inactive) return MissionPhase.inactive;
    if (isOpenAt(now)) return MissionPhase.open;
    return MissionPhase.upcoming;
  }
}

/// Datos del formulario de creación/edición de una misión.
class MissionDraft {
  const MissionDraft({
    this.id,
    required this.name,
    required this.isoCode,
    required this.imageUrl,
    required this.location,
    required this.schedules,
    required this.status,
    this.placeId,
  });

  /// `null` al crear.
  final String? id;
  final String name;
  final String isoCode;
  final String imageUrl;
  final GeoLocation location;
  final String? placeId;
  final List<MissionSchedule> schedules;
  final MissionStatus status;

  bool get isNew => id == null;
}

/// Sugerencia del buscador de lugares.
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

/// Foto del culto misionero subida por un administrador.
class MissionPhoto {
  const MissionPhoto({required this.url, required this.originalUrl, required this.storagePath, this.previewPath});

  /// Versión liviana para mostrar en la app (o el original si no hay copia).
  final String url;

  /// Archivo original en su calidad completa, para descargar.
  final String originalUrl;
  final String storagePath;
  final String? previewPath;
}
