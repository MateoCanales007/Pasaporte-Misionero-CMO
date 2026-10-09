/// Estado de sincronización de un dato local.
enum SyncStatus { pending, failed }

/// Escaneo guardado en el teléfono porque no había conexión. No es un sello
/// confirmado hasta que el servidor lo acepte.
class PendingRedemption {
  const PendingRedemption({
    required this.id,
    required this.token,
    required this.scannedAt,
    this.status = SyncStatus.pending,
    this.attempts = 0,
    this.failureMessage,
  });

  final String id;
  final String token;
  final DateTime scannedAt;
  final SyncStatus status;
  final int attempts;

  /// Explicación para el usuario cuando [status] es [SyncStatus.failed].
  final String? failureMessage;

  PendingRedemption copyWith({SyncStatus? status, int? attempts, String? failureMessage}) {
    return PendingRedemption(
      id: id,
      token: token,
      scannedAt: scannedAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'token': token,
    'scannedAt': scannedAt.toUtc().toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    'failureMessage': failureMessage,
  };

  /// Devuelve `null` si el registro local está dañado.
  static PendingRedemption? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final token = json['token'];
    final scannedAt = DateTime.tryParse(json['scannedAt']?.toString() ?? '');
    if (id is! String || token is! String || scannedAt == null) return null;
    return PendingRedemption(
      id: id,
      token: token,
      scannedAt: scannedAt,
      status: json['status'] == SyncStatus.failed.name ? SyncStatus.failed : SyncStatus.pending,
      attempts: json['attempts'] is int ? json['attempts'] as int : 0,
      failureMessage: json['failureMessage'] as String?,
    );
  }
}
