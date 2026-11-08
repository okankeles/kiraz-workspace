import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/landlord_dashboard_data.dart';
import '../utils/constants.dart';

class LandlordService {
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

  /// Ev sahibi kurumsal gösterge paneli verilerini çeker.
  /// GET /api/landlord/dashboard
  Future<LandlordDashboardData> getLandlordDashboard({int? landlordId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveId = landlordId ?? prefs.getInt('userId');

    var urlStr = '${ApiConstants.baseUrl}/landlord/dashboard';
    if (effectiveId != null) {
      urlStr += '?landlordId=$effectiveId';
    }
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          return LandlordDashboardData.fromJson(data);
        }
        throw Exception('Sunucudan geçersiz veri biçimi alındı.');
      } else {
        String msg = 'Ev sahibi paneli verisi alınamadı (${response.statusCode})';
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
