enum TestimonialStatus {
  pending('Pendiente de revisión'),
  approved('Publicado'),
  rejected('No publicado');

  const TestimonialStatus(this.label);

  final String label;

  static TestimonialStatus parse(Object? value) => switch (value) {
    'approved' => TestimonialStatus.approved,
    'rejected' => TestimonialStatus.rejected,
    _ => TestimonialStatus.pending,
  };
}

/// Testimonio enviado por un usuario. Solo los aprobados son públicos.
class Testimonial {
  const Testimonial({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.status,
    this.missionId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String text;
  final TestimonialStatus status;
  final String? missionId;

  /// `null` mientras la escritura está pendiente de sincronizar.
  final DateTime? createdAt;

  static const minLength = 10;
  static const maxLength = 1000;
}
