import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/payment_summary.dart';
import 'api_client.dart';

class PaymentService {
  final ApiClient _apiClient;

  PaymentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Kiracının belirli bir kira periyodu için PayTR Sanal POS iframe token'ı talep eder.
  /// POST /api/payments/paytr/initialize
  Future<String> initializePayment(int periodId) async {
    final uri = _apiClient.resolveUri('/payments/paytr/initialize');
    final response = await _apiClient.post(
      uri,
      body: {'periodId': periodId},
    );

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'failed') {
        final reason = data['reason']?.toString() ?? 'Ödeme başlatılamadı';
        throw ApiException(statusCode: 400, message: reason);
      }
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        return token;
      }
      throw ApiException(
        statusCode: 400,
        message: data['reason']?.toString() ?? 'PayTR token alınamadı',
      );
    }
    throw ApiException(statusCode: 500, message: 'Sunucudan geçersiz veri biçimi alındı.');
  }

  /// Kiracının anlık finansal özetini (Toplam Borç, Toplam Ödenen, Sıradaki Ödeme) döner.
  /// GET /api/tenant/payments/summary
  Future<PaymentSummary> getPaymentSummary({int? tenantId}) async {
    final uri = _apiClient.resolveUri('/tenant/payments/summary');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) {
      return PaymentSummary.fromJson(data);
    }
    throw ApiException(statusCode: 500, message: 'Geçersiz veri biçimi');
  }

  /// Belirli bir kira periyoduna ait havale/EFT dekont belgesini backend'e yükler.
  /// POST /api/tenant/receipts/{periodId} (multipart/form-data, alan adı "file")
  Future<void> uploadReceipt({
    required int periodId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    // 10 MB sınır kontrolü (10 * 1024 * 1024 bytes)
    if (fileBytes.length > 10 * 1024 * 1024) {
      throw ApiException(
        statusCode: 400,
        message: 'Dosya boyutu 10 MB\'tan büyük olamaz.',
      );
    }

    final ext = fileName.split('.').last.toLowerCase();
    MediaType? contentType;
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else if (ext == 'pdf') {
      contentType = MediaType('application', 'pdf');
    } else {
      throw ApiException(
        statusCode: 400,
        message: 'Yalnızca PDF, JPEG ve PNG formatları desteklenmektedir.',
      );
    }

    final uri = _apiClient.resolveUri('/tenant/receipts/$periodId');

    await _apiClient.sendMultipart(() async {
      final request = http.MultipartRequest('POST', uri);
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      return request;
    });
  }
}