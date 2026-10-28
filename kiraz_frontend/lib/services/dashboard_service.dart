import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/dashboard_stats.dart';
import '../utils/constants.dart';

class DashboardService {
  Future<DashboardStats> getLandlordStats(int landlordId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/dashboard/landlord/$landlordId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

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

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

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
}
