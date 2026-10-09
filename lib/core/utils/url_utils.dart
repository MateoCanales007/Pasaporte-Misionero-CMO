/// Validación ligera de enlaces en el cliente. La validación definitiva y la
/// obtención de metadatos ocurren en Cloud Functions.
abstract final class UrlUtils {
  static const maxLength = 2048;

  /// `true` solo para URLs `https://` bien formadas, sin credenciales embebidas.
  static bool isSafeHttpsUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.length > maxLength) return false;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;
    if (uri.userInfo.isNotEmpty) return false;
    return true;
  }

  /// Dominio legible ("youtube.com") a partir de una URL.
  static String domainOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}
