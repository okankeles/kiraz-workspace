import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class FileViewer {
  /// Güvenli biçimde dekont veya sözleşme dosyasını indirir ve görüntüler.
  /// PDF'ler cihazda geçici dosyaya kaydedilerek harici uygulamayla açılır;
  /// Görseller ise uygulama içinde yakınlaştırılabilir (zoom) dialog penceresinde gösterilir.
  static Future<void> open({
    required BuildContext context,
    required String fileUrl,
    String? title,
  }) async {
    final cleanUrl = fileUrl.trim();
    if (cleanUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya bağlantısı bulunamadı.')),
        );
      }
      return;
    }

    // Yükleme göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Dosya yükleniyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final uri = ApiClient.instance.resolveUri(cleanUrl);
      final bytes = await ApiClient.instance.downloadFile(uri);

      // Yükleme diyaloğunu kapat
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final isPdf = cleanUrl.toLowerCase().endsWith('.pdf') ||
          (bytes.length > 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46); // %PDF magic bytes

      if (isPdf) {
        if (kIsWeb) {
          final dataUri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
          await launchUrl(dataUri);
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/belge_$timestamp.pdf');
        await tempFile.writeAsBytes(bytes);

        final fileUri = Uri.file(tempFile.path);
        final launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(fileUri);
        }
      } else {
        // Görsel dosyası: Uygulama içi modal
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text(title ?? 'Belge Görüntüleyici', style: const TextStyle(fontSize: 16)),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Yükleme diyaloğu açıksa kapat
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya açılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
