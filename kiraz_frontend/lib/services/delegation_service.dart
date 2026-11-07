import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/property_delegation.dart';
import '../utils/constants.dart';

class DelegationService {
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

  Future<PropertyDelegation> assignAgent({
    required int propertyId,
    int? agentId,
    String? agentEmail,
    int? landlordId,
    String? startDate,
    String? endDate,
    String? notes,
  }) async {
    int? effectiveLandlordId = landlordId;
    if (effectiveLandlordId == null) {
      final prefs = await SharedPreferences.getInstance();
      effectiveLandlordId = prefs.getInt('userId');
    }

    final url = Uri.parse('${ApiConstants.baseUrl}/delegations');
    final Map<String, dynamic> body = {
      'propertyId': propertyId,
      'landlordId': effectiveLandlordId,
    };

    if (agentId != null) {
      body['agentId'] = agentId;
    }
    if (agentEmail != null && agentEmail.trim().isNotEmpty) {
      body['agentEmail'] = agentEmail.trim();
    }
    if (startDate != null && startDate.isNotEmpty) {
      body['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['endDate'] = endDate;
    }
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    final headers = await _getHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        return PropertyDelegation.fromJson(data as Map<String, dynamic>);
      } else {
        String msg = 'Emlakçı yetkilendirilemedi (${response.statusCode})';
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

  Future<PropertyDelegation> revokeDelegation(
    int delegationId, {
    int? landlordId,
    String? reason,
  }) async {
    int? effectiveLandlordId = landlordId;
    if (effectiveLandlordId == null) {
      final prefs = await SharedPreferences.getInstance();
      effectiveLandlordId = prefs.getInt('userId');
    }

    final queryParams = <String, String>{};
    if (effectiveLandlordId != null) {
      queryParams['landlordId'] = effectiveLandlordId.toString();
    }
    if (reason != null && reason.trim().isNotEmpty) {
      queryParams['reason'] = reason.trim();
    }

    final uri = Uri.parse('${ApiConstants.baseUrl}/delegations/$delegationId/revoke')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final headers = await _getHeaders();

    try {
      final response = await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'landlordId': effectiveLandlordId,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        return PropertyDelegation.fromJson(data as Map<String, dynamic>);
      } else {
        String msg = 'Yetki iptal edilemedi (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('message')) {
            msg = errorData['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<PropertyDelegation>> getDelegationsForProperty(int propertyId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/delegations/property/$propertyId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((e) => PropertyDelegation.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Vekalet bilgisi alınamadı (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Vekalet geçmişi yüklenirken hata: $e');
    }
  }

  Future<List<PropertyDelegation>> getActiveDelegationsForAgent(int agentId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/delegations/agent/$agentId/active');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((e) => PropertyDelegation.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Aktif yetkiler alınamadı (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Yetki listesi yüklenirken hata: $e');
    }
  }

  Future<List<PropertyDelegation>> getDelegationsForLandlord(int landlordId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/delegations/landlord/$landlordId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((e) => PropertyDelegation.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Vekaletler alınamadı (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Vekalet listesi yüklenirken hata: $e');
    }
  }
}
