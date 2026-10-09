import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppHelper {
  static Future<void> sendWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('92')) {
      cleanPhone = '92$cleanPhone';
    }
    cleanPhone = cleanPhone.replaceAll('+', '');

    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    
    // Fallback to general system share if direct WhatsApp launch isn't available
    await Share.share(message);
  }
}
