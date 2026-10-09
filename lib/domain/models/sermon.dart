/// Plataforma de video de una prédica.
enum VideoPlatform {
  youtube('YouTube'),
  vimeo('Vimeo'),
  facebook('Facebook'),
  other('Enlace web');

  const VideoPlatform(this.label);

  final String label;

  static VideoPlatform parse(Object? value) => switch (value) {
    'youtube' => VideoPlatform.youtube,
    'vimeo' => VideoPlatform.vimeo,
    'facebook' => VideoPlatform.facebook,
    _ => VideoPlatform.other,
  };
}

/// Prédica publicada (`sermons/{id}`).
class Sermon {
  const Sermon({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.platform,
    required this.publishedAt,
    this.coverImageUrl = '',
    this.coverStoragePath,
    this.thumbnailUrl = '',
    this.domain = '',
    this.externalVideoId,
    this.active = true,
    this.deleted = false,
    this.deletedAt,
    this.sortOrder,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String sourceUrl;
  final String title;
  final VideoPlatform platform;
  final DateTime publishedAt;
  final String coverImageUrl;
  final String? coverStoragePath;
  final String thumbnailUrl;
  final String domain;
  final String? externalVideoId;
  final bool active;
  final bool deleted;
  final DateTime? deletedAt;
  final int? sortOrder;
  final String? createdBy;
  final DateTime? createdAt;

  /// Portada personalizada o, si no hay, la miniatura del proveedor.
  String get displayImageUrl => coverImageUrl.isNotEmpty ? coverImageUrl : thumbnailUrl;
}

/// Datos del formulario de prédicas.
class SermonDraft {
  const SermonDraft({
    required this.id,
    required this.isNew,
    required this.sourceUrl,
    required this.title,
    required this.platform,
    required this.domain,
    required this.publishedAt,
    required this.active,
    this.externalVideoId,
    this.coverImageUrl = '',
    this.coverStoragePath,
    this.thumbnailUrl = '',
  });

  final String id;
  final bool isNew;
  final String sourceUrl;
  final String title;
  final VideoPlatform platform;
  final String domain;
  final String? externalVideoId;
  final DateTime publishedAt;
  final bool active;
  final String coverImageUrl;
  final String? coverStoragePath;
  final String thumbnailUrl;
}

/// Metadatos obtenidos por Cloud Functions a partir de un enlace.
class VideoMetadata {
  const VideoMetadata({
    required this.platform,
    required this.domain,
    required this.canonicalUrl,
    required this.metadataAvailable,
    this.externalVideoId,
    this.title,
    this.thumbnailUrl,
    this.authorName,
  });

  final VideoPlatform platform;
  final String domain;
  final String canonicalUrl;
  final bool metadataAvailable;
  final String? externalVideoId;
  final String? title;
  final String? thumbnailUrl;
  final String? authorName;
}

sealed class VideoMetadataResult {
  const VideoMetadataResult();
}

class VideoMetadataFound extends VideoMetadataResult {
  const VideoMetadataFound(this.metadata);

  final VideoMetadata metadata;
}

class VideoUrlRejected extends VideoMetadataResult {
  const VideoUrlRejected(this.reason);

  final String reason;
}

/// Portada subida a Storage.
class UploadedImage {
  const UploadedImage({required this.downloadUrl, required this.storagePath});

  final String downloadUrl;
  final String storagePath;
}
