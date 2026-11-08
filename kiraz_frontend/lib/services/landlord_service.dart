import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/landlord_dashboard_data.dart';
import '../models/receipt_approval_item.dart';
import '../utils/constants.dart';
import 'rent_period_service.dart';

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

  /// Onay bekleyen dekont listesini çeker.
  /// GET /api/landlord/receipts/pending
  Future<List<ReceiptApprovalItem>> getPendingReceipts({int? landlordId}) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveId = landlordId ?? prefs.getInt('userId');

    var urlStr = '${ApiConstants.baseUrl}/landlord/receipts/pending';
    if (effectiveId != null) {
      urlStr += '?landlordId=$effectiveId';
    }
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((item) => ReceiptApprovalItem.fromJson(item))
              .toList();
        }
        return [];
      } else if (response.statusCode == 404 && effectiveId != null) {
        // Fallback: RentPeriodService üzerinden çek
        final pendingItems = await RentPeriodService().getPendingApprovalsForLandlord(effectiveId);
        return pendingItems.map((item) => ReceiptApprovalItem.fromPendingApprovalItem(item)).toList();
      } else {
        throw Exception('Bekleyen dekontlar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      if (effectiveId != null) {
        try {
          final pendingItems = await RentPeriodService().getPendingApprovalsForLandlord(effectiveId);
          return pendingItems.map((item) => ReceiptApprovalItem.fromPendingApprovalItem(item)).toList();
        } catch (_) {}
      }
      throw Exception('Bekleyen dekontlar alınırken hata: $e');
    }
  }

  /// Dekontu onaylar ve kira periyodunu PAID yapar.
  /// POST /api/landlord/receipts/{periodId}/approve
  Future<void> approveReceipt(int periodId) async {
    final primaryUrl = Uri.parse('${ApiConstants.baseUrl}/landlord/receipts/$periodId/approve');
    final headers = await _getHeaders();

    try {
      final response = await http.post(primaryUrl, headers: headers, body: json.encode({}));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        // Fallback: RentPeriodService updateStatus('PAID')
        await RentPeriodService().updatePeriodStatus(periodId, 'PAID');
        return;
      } else {
        String msg = 'Dekont onaylanamadı (${response.statusCode})';
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

  /// Dekontu reddeder ve gerekçesini kaydeder.
  /// POST /api/landlord/receipts/{periodId}/reject
  Future<void> rejectReceipt(int periodId, {String? reason}) async {
    final cleanReason = reason?.trim() ?? '';
    final primaryUrl = Uri.parse('${ApiConstants.baseUrl}/landlord/receipts/$periodId/reject')
        .replace(queryParameters: cleanReason.isNotEmpty ? {'reason': cleanReason} : null);
    final headers = await _getHeaders();
    final body = json.encode({
      'reason': cleanReason,
      'rejectionReason': cleanReason,
    });

    try {
      final response = await http.post(primaryUrl, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        // Fallback: RentPeriodService updateStatus('REJECTED')
        await RentPeriodService().updatePeriodStatus(periodId, 'REJECTED');
        return;
      } else {
        String msg = 'Dekont reddedilemedi (${response.statusCode})';
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
