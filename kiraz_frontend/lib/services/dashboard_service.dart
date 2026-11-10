import 'dart:convert';
import '../models/dashboard_stats.dart';
import '../models/landlord_dashboard_data.dart';
import 'api_client.dart';

class DashboardService {
  final ApiClient _apiClient;

  DashboardService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Ev sahibi gösterge paneli verilerini çeker.
  /// GET /api/landlord/dashboard
  Future<LandlordDashboardData> getLandlordDashboardData([int? landlordId]) async {
    final uri = _apiClient.resolveUri('/landlord/dashboard');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) {
      return LandlordDashboardData.fromJson(data);
    }
    throw Exception('Geçersiz veri biçimi.');
  }

  /// Ev sahibi özet istatistiklerini çeker.
  /// GET /api/landlord/dashboard
  Future<DashboardStats> getLandlordStats([int? landlordId]) async {
    final uri = _apiClient.resolveUri('/landlord/dashboard');
    final response = await _apiClient.get(uri);

    final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return DashboardStats.fromJson(data);
  }

  /// Kiracı gösterge paneli istatistiklerini çeker.
  /// GET /api/tenant/dashboard
  Future<DashboardStats> getTenantStats([int? tenantId]) async {
    final uri = _apiClient.resolveUri('/tenant/dashboard');
    final response = await _apiClient.get(uri);

    final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return DashboardStats.fromJson(data);
  }

  /// Emlakçı / Mülk Yöneticisi gösterge paneli istatistiklerini çeker.
  /// GET /api/manager/dashboard
  Future<DashboardStats> getAgentStats([int? agentId]) async {
    final uri = _apiClient.resolveUri('/manager/dashboard');
    final response = await _apiClient.get(uri);

    final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return DashboardStats.fromJson(data);
  }
}
