import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/managed_property.dart';
import '../models/property_delegation.dart';
import '../utils/constants.dart';
import 'property_service.dart';

class DelegationService {
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

  /// Ev sahibi için yeni emlakçı yetkilendirmesi oluşturur.
  /// POST /api/landlord/delegations
  Future<PropertyDelegation> createLandlordDelegation({
    required int propertyId,
    required String agentEmail,
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

    final url = Uri.parse('${ApiConstants.baseUrl}/landlord/delegations');
    final Map<String, dynamic> body = {
      'propertyId': propertyId,
      'agentEmail': agentEmail.trim(),
    };
    if (effectiveLandlordId != null) {
      body['landlordId'] = effectiveLandlordId;
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
      } else if (response.statusCode == 404) {
        // Fallback: POST /api/delegations
        return await assignAgent(
          propertyId: propertyId,
          agentEmail: agentEmail,
          landlordId: effectiveLandlordId,
          startDate: startDate,
          endDate: endDate,
          notes: notes,
        );
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

  /// Ev sahibine ait yetkilendirme listesini çeker.
  /// GET /api/landlord/delegations
  Future<List<PropertyDelegation>> getLandlordDelegations({int? landlordId}) async {
    int? effectiveLandlordId = landlordId;
    if (effectiveLandlordId == null) {
      final prefs = await SharedPreferences.getInstance();
      effectiveLandlordId = prefs.getInt('userId');
    }

    var urlStr = '${ApiConstants.baseUrl}/landlord/delegations';
    if (effectiveLandlordId != null) {
      urlStr += '?landlordId=$effectiveLandlordId';
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
              .map((e) => PropertyDelegation.fromJson(e))
              .toList();
        }
        return [];
      } else if (response.statusCode == 404 && effectiveLandlordId != null) {
        // Fallback: GET /api/delegations/landlord/$effectiveLandlordId
        return await getDelegationsForLandlord(effectiveLandlordId);
      } else {
        throw Exception('Yetkilendirmeler alınamadı (${response.statusCode})');
      }
    } catch (e) {
      if (effectiveLandlordId != null) {
        try {
          return await getDelegationsForLandlord(effectiveLandlordId);
        } catch (_) {}
      }
      throw Exception('Yetkilendirmeler yüklenirken hata: $e');
    }
  }

  /// Ev sahibi tarafından verilen yetkilendirmeyi iptal eder/siler.
  /// DELETE /api/landlord/delegations/{id}
  Future<void> deleteLandlordDelegation(int delegationId, {String? reason}) async {
    final prefs = await SharedPreferences.getInstance();
    final landlordId = prefs.getInt('userId');

    var urlStr = '${ApiConstants.baseUrl}/landlord/delegations/$delegationId';
    if (landlordId != null) {
      urlStr += '?landlordId=$landlordId';
    }
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();

    try {
      final response = await http.delete(
        url,
        headers: headers,
        body: reason != null && reason.isNotEmpty ? json.encode({'reason': reason}) : null,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 404) {
        // Fallback: revokeDelegation PUT /api/delegations/$delegationId/revoke
        await revokeDelegation(delegationId, landlordId: landlordId, reason: reason);
        return;
      } else {
        String msg = 'Yetkilendirme iptal edilemedi (${response.statusCode})';
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

  /// Emlakçı / Mülk Yöneticisi için yetkisi devredilmiş mülkleri listeler.
  /// GET /api/manager/properties
  Future<List<ManagedProperty>> getManagerProperties({int? managerId}) async {
    int? effectiveManagerId = managerId;
    if (effectiveManagerId == null) {
      final prefs = await SharedPreferences.getInstance();
      effectiveManagerId = prefs.getInt('userId');
    }

    var urlStr = '${ApiConstants.baseUrl}/manager/properties';
    if (effectiveManagerId != null) {
      urlStr += '?managerId=$effectiveManagerId&agentId=$effectiveManagerId';
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
              .map((item) => ManagedProperty.fromJson(item))
              .toList();
        }
        return [];
      } else if (response.statusCode == 404 && effectiveManagerId != null) {
        return await _fallbackManagerProperties(effectiveManagerId);
      } else {
        throw Exception('Yönetilen mülkler alınamadı (${response.statusCode})');
      }
    } catch (e) {
      if (effectiveManagerId != null) {
        try {
          return await _fallbackManagerProperties(effectiveManagerId);
        } catch (_) {}
      }
      throw Exception('Yönetilen mülkler yüklenirken hata: $e');
    }
  }

  Future<List<ManagedProperty>> _fallbackManagerProperties(int managerId) async {
    try {
      final delegations = await getActiveDelegationsForAgent(managerId);
      if (delegations.isNotEmpty) {
        return delegations.map((d) => ManagedProperty.fromDelegation(d)).toList();
      }
    } catch (_) {}

    try {
      final properties = await PropertyService().getPropertiesForAgent(managerId);
      return properties.map((p) => ManagedProperty.fromProperty(p)).toList();
    } catch (_) {}

    return [];
  }

  // --- MEVCUT DESTEK VE GEÇMİŞ METOTLARI (Backward Compatibility) ---

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
