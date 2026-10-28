import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../utils/constants.dart';

class NotificationService {
  Future<List<AppNotification>> getUnreadNotifications(int userId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/notifications?userId=$userId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Bildirimler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bildirimler alınırken hata: $e');
    }
  }

  Future<List<AppNotification>> getAllNotifications(int userId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/notifications/user/$userId/all');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Bildirim geçmişi yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bildirim geçmişi alınırken hata: $e');
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/notifications/$notificationId/read');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
