import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_stats.dart';
import '../models/landlord_dashboard_data.dart';
import '../utils/constants.dart';

class DashboardService {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (userId != null) {
      headers['X-User-Id'] = userId.toString();
      headers['Authorization'] = 'Bearer $userId';
    }
    return headers;
  }

  /// GET /api/landlord/dashboard
  Future<LandlordDashboardData> getLandlordDashboardData({int? landlordId}) async {
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
        throw Exception('Geçersiz veri biçimi.');
      } else {
        throw Exception('Ev sahibi paneli verisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ev sahibi gösterge paneli verisi alınırken hata: $e');
    }
  }

  Future<DashboardStats> getLandlordStats(int landlordId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/dashboard/landlord/$landlordId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return DashboardStats.fromJson(data);
      } else {
        throw Exception('İstatistikler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ev sahibi gösterge paneli verisi alınırken hata oluştu: $e');
    }
  }

  Future<DashboardStats> getTenantStats(int tenantId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/dashboard/tenant/$tenantId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return DashboardStats.fromJson(data);
      } else {
        throw Exception('İstatistikler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Kiracı gösterge paneli verisi alınırken hata oluştu: $e');
    }
  }

  Future<DashboardStats> getAgentStats(int agentId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/dashboard/agent/$agentId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return DashboardStats.fromJson(data);
      } else {
        throw Exception('Emlakçı istatistikleri alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Emlakçı gösterge paneli verisi alınırken hata oluştu: $e');
    }
  }
}
