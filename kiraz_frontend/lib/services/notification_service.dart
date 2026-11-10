import 'dart:convert';
import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Okunmamış bildirimleri çeker.
  /// GET /api/notifications/unread
  Future<List<AppNotification>> getUnreadNotifications([int? userId]) async {
    final uri = _apiClient.resolveUri('/notifications/unread');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => AppNotification.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Tüm bildirim geçmişini çeker.
  /// GET /api/notifications/all
  Future<List<AppNotification>> getAllNotifications([int? userId]) async {
    final uri = _apiClient.resolveUri('/notifications/all');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => AppNotification.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Bildirimi okundu olarak işaretler.
  /// PUT /api/notifications/{id}/read
  Future<bool> markAsRead(int notificationId) async {
    final uri = _apiClient.resolveUri('/notifications/$notificationId/read');
    try {
      final response = await _apiClient.put(uri);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
