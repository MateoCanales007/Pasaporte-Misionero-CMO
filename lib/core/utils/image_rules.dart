/// Reglas de imágenes subidas por administradores (mismas que storage.rules).
const maxImageBytes = 5 * 1024 * 1024;

/// Fotos del culto: se guarda el original tal como se tomó (alta calidad).
const maxOriginalPhotoBytes = 25 * 1024 * 1024;
const allowedImageTypes = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'};

/// Tipo MIME a partir del nombre del archivo (image_picker no siempre lo da).
String? imageContentTypeFor(String fileName, {String? reported}) {
  if (reported != null && allowedImageTypes.containsKey(reported)) return reported;
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}
