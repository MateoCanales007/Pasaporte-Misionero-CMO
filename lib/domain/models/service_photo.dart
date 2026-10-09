/// A qué pertenece un álbum de fotos del culto.
enum PhotoAlbumKind { mission, sermon }

/// Álbum de fotos del culto de una misión o de una prédica.
class PhotoAlbum {
  const PhotoAlbum(this.kind, this.ownerId);

  const PhotoAlbum.mission(String missionId) : this(PhotoAlbumKind.mission, missionId);

  const PhotoAlbum.sermon(String sermonId) : this(PhotoAlbumKind.sermon, sermonId);

  final PhotoAlbumKind kind;
  final String ownerId;

  @override
  bool operator ==(Object other) => other is PhotoAlbum && other.kind == kind && other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(kind, ownerId);
}

/// Foto del culto subida por un administrador.
class ServicePhoto {
  const ServicePhoto({required this.url, required this.originalUrl, required this.storagePath, this.previewPath});

  /// Versión liviana para mostrar en la app (o el original si no hay copia).
  final String url;

  /// Archivo original en su calidad completa, para descargar.
  final String originalUrl;
  final String storagePath;
  final String? previewPath;
}
