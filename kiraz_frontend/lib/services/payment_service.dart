import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
}
