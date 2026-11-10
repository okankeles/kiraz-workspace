import 'package:flutter/services.dart';
import '../services/api_client.dart';

class ErrorHandler {
  /// Ham hata veya istisnaları kullanıcı dostu Türkçe bir hata mesajına dönüştürür.
  /// Teknik detayları (PlatformException, -34018, ham stack trace vb.) kullanıcıdan gizler.
  static String getUserFriendlyMessage(dynamic error, {String? defaultMessage}) {
    final fallback = defaultMessage ?? 'İşlem sırasında bir hata oluştu. Lütfen tekrar deneyin.';
    if (error == null) return fallback;

    if (error is ApiException) {
      return error.message;
    }

    if (error is PlatformException) {
      if (error.code == '-34018' || (error.message?.contains('entitlement') ?? false)) {
        return 'Cihaz güvenlik anahtarlığına erişilemedi. Lütfen sistem izinlerinizi kontrol edin.';
      }
      return 'Sistem güvenlik işlemi gerçekleştirilemedi. Lütfen tekrar deneyin.';
    }

    final str = error.toString();

    if (str.contains('PlatformException') || str.contains('-34018')) {
      return 'Cihaz güvenlik anahtarlığına erişilemedi. Lütfen sistem izinlerinizi kontrol edin.';
    }

    if (str.contains('SocketException') ||
        str.contains('Network error') ||
        str.contains('ClientException') ||
        str.contains('Connection refused') ||
        str.contains('Failed host lookup') ||
        str.contains('Software caused connection abort') ||
        str.contains('Connection closed before full header was received')) {
      return 'Sunucuya ulaşılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
    }

    // "Exception: " ön eklerini temizle
    String clean = str.replaceFirst(RegExp(r'^(Exception:\s*)+'), '').trim();

    // Hâlâ ham teknik hata veya yığın izi içeriyorsa genel mesaj döndür
    if (clean.isEmpty ||
        clean.contains('PlatformException') ||
        clean.contains('FormatException') ||
        clean.contains('TypeError') ||
        clean.contains('NoSuchMethodError') ||
        clean.contains('Stack trace:')) {
      return fallback;
    }

    return clean;
  }
}
