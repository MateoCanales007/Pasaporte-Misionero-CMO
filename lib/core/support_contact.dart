import 'package:url_launcher/url_launcher.dart';

/// Contacto de soporte de la iglesia por WhatsApp.
abstract final class SupportContact {
  static const _whatsAppNumber = '50370969099';
  static const displayPhone = '+503 7096 9099';

  static Future<bool> openWhatsApp(String message) async {
    final uri = Uri.parse('https://wa.me/$_whatsAppNumber?text=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    } catch (_) {
      return false;
    }
  }
}
