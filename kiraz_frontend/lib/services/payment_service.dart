import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_summary.dart';
import '../utils/constants.dart';

class PaymentService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final userEmail = prefs.getString('email');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (userId != null) {
      headers['X-User-Id'] = userId.toString();
      headers['Authorization'] = 'Bearer $userId';
    }
    if (userEmail != null && userEmail.isNotEmpty) {
      headers['X-User-Email'] = userEmail;
    }
    return headers;
  }

  /// Kiracının belirli bir kira periyodu için PayTR Sanal POS iframe token'ı talep eder.
  /// POST /api/payments/paytr/initialize
  /// Başarılı yanıtta dönen JSON içerisindeki token değerini String olarak döndürür.
  Future<String> initializePayment(int periodId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/payments/paytr/initialize');
    final headers = await _getHeaders();

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('email');

    final Map<String, dynamic> body = {
      'periodId': periodId,
    };
    if (userEmail != null && userEmail.isNotEmpty) {
      body['userEmail'] = userEmail;
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          if (data['status'] == 'failed') {
            final reason = data['reason']?.toString() ?? 'Ödeme başlatılamadı';
            throw Exception(reason);
          }
          final token = data['token']?.toString();
          if (token != null && token.isNotEmpty) {
            return token;
          }
          throw Exception(data['reason']?.toString() ?? 'PayTR token alınamadı');
        }
        throw Exception('Sunucudan geçersiz veri biçimi alındı.');
      } else {
        String errorMsg = 'Ödeme başlatılamadı (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map) {
            if (errorData.containsKey('reason') && errorData['reason'] != null) {
              errorMsg = errorData['reason'].toString();
            } else if (errorData.containsKey('message') && errorData['message'] != null) {
              errorMsg = errorData['message'].toString();
            }
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: Network error')) {
        rethrow;
      }
      throw Exception('Ağ hatası: $e');
    }
  }

  /// Kiracının anlık finansal özetini (Toplam Borç, Toplam Ödenen, Sıradaki Ödeme) döner.
  /// GET /api/payments/summary
  Future<PaymentSummary> getPaymentSummary({int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveTenantId = tenantId ?? prefs.getInt('userId');

    var urlStr = '${ApiConstants.baseUrl}/payments/summary';
    if (effectiveTenantId != null) {
      urlStr += '?tenantId=$effectiveTenantId';
    }
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          return PaymentSummary.fromJson(data);
        }
        throw Exception('Geçersiz veri biçimi');
      } else {
        String msg = 'Ödeme özeti alınamadı (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('message')) {
            msg = errorData['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: ')) {
        rethrow;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Belirli bir kira periyoduna ait havale/EFT dekont belgesini backend'e yükler.
  /// POST /api/payments/{periodId}/receipt (multipart/form-data)
  Future<void> uploadReceipt({
    required int periodId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final primaryUrl = Uri.parse('${ApiConstants.baseUrl}/payments/$periodId/receipt');
    final fallbackUrl = Uri.parse('${ApiConstants.baseUrl}/periods/$periodId/receipt');

    MediaType? contentType;
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else if (ext == 'pdf') {
      contentType = MediaType('application', 'pdf');
    }

    Future<http.Response> sendTo(Uri targetUrl) async {
      final request = http.MultipartRequest('POST', targetUrl);
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      final userEmail = prefs.getString('email');

      if (userId != null) {
        request.headers['X-User-Id'] = userId.toString();
        request.headers['Authorization'] = 'Bearer $userId';
      }
      if (userEmail != null && userEmail.isNotEmpty) {
        request.headers['X-User-Email'] = userEmail;
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: contentType,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    }

    try {
      var response = await sendTo(primaryUrl);
      if (response.statusCode == 404) {
        // /payments/$periodId/receipt bulunamazsa /periods/$periodId/receipt endpoint'ini dener
        response = await sendTo(fallbackUrl);
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        String msg = 'Dekont yüklenemedi (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('message')) {
            msg = errorData['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: ')) {
        rethrow;
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}