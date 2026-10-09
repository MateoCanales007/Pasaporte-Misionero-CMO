/// Iniciales para avatares: primeras letras de las dos primeras palabras.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'CM';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Nombre de usuario normalizado: sin espacios y en minúsculas.
String normalizeUsername(String raw) => raw.replaceAll(RegExp(r'\s+'), '').toLowerCase();
