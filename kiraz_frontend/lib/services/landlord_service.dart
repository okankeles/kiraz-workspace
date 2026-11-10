import 'dart:convert';
import '../models/landlord_dashboard_data.dart';
import '../models/receipt_approval_item.dart';
import 'api_client.dart';

class LandlordService {
  final ApiClient _apiClient;

  LandlordService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Ev sahibi kurumsal gösterge paneli verilerini çeker.
  /// GET /api/landlord/dashboard
  Future<LandlordDashboardData> getLandlordDashboard({int? landlordId}) async {
    final uri = _apiClient.resolveUri('/landlord/dashboard');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) {
      return LandlordDashboardData.fromJson(data);
    }
    throw Exception('Sunucudan geçersiz veri biçimi alındı.');
  }

  /// Onay bekleyen dekont listesini çeker.
  /// GET /api/landlord/receipts/pending
  Future<List<ReceiptApprovalItem>> getPendingReceipts({int? landlordId}) async {
    final uri = _apiClient.resolveUri('/landlord/receipts/pending');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => ReceiptApprovalItem.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Dekontu onaylar ve kira periyodunu PAID yapar.
  /// POST /api/landlord/receipts/{periodId}/approve
  Future<void> approveReceipt(int periodId) async {
    final uri = _apiClient.resolveUri('/landlord/receipts/$periodId/approve');
    await _apiClient.post(uri, body: {});
  }

  /// Dekontu reddeder ve gerekçesini kaydeder.
  /// POST /api/landlord/receipts/{periodId}/reject
  Future<void> rejectReceipt(int periodId, {String? reason}) async {
    final cleanReason = reason?.trim() ?? '';
    final uri = _apiClient.resolveUri(
      '/landlord/receipts/$periodId/reject',
      cleanReason.isNotEmpty ? {'reason': cleanReason} : null,
    );
    final body = {
      'reason': cleanReason,
      'rejectionReason': cleanReason,
    };
    await _apiClient.post(uri, body: body);
  }
}
