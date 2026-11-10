import 'dart:convert';
import '../models/managed_property.dart';
import '../models/property_delegation.dart';
import 'api_client.dart';

class DelegationService {
  final ApiClient _apiClient;

  DelegationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

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
    final uri = _apiClient.resolveUri('/landlord/delegations');
    final Map<String, dynamic> body = {
      'propertyId': propertyId,
      'agentEmail': agentEmail.trim(),
    };
    if (startDate != null && startDate.isNotEmpty) {
      body['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['endDate'] = endDate;
    }
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    final response = await _apiClient.post(uri, body: body);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return PropertyDelegation.fromJson(data as Map<String, dynamic>);
  }

  /// Ev sahibine ait yetkilendirme listesini çeker.
  /// GET /api/landlord/delegations
  Future<List<PropertyDelegation>> getLandlordDelegations({int? landlordId}) async {
    final uri = _apiClient.resolveUri('/landlord/delegations');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => PropertyDelegation.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Ev sahibi tarafından verilen yetkilendirmeyi siler/iptal eder.
  /// DELETE /api/landlord/delegations/{id}
  Future<void> deleteLandlordDelegation(int delegationId, {String? reason}) async {
    final uri = _apiClient.resolveUri(
      '/landlord/delegations/$delegationId',
      reason != null && reason.trim().isNotEmpty ? {'reason': reason.trim()} : null,
    );
    await _apiClient.delete(
      uri,
      body: reason != null && reason.isNotEmpty ? {'reason': reason} : null,
    );
  }

  /// Emlakçı / Mülk Yöneticisi için yetkisi devredilmiş mülkleri listeler.
  /// GET /api/manager/properties
  Future<List<ManagedProperty>> getManagerProperties({int? managerId}) async {
    final uri = _apiClient.resolveUri('/manager/properties');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => ManagedProperty.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Emlakçının tüm yetkilerini çeker.
  /// GET /api/manager/delegations
  Future<List<PropertyDelegation>> getManagerDelegations() async {
    final uri = _apiClient.resolveUri('/manager/delegations');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => PropertyDelegation.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Emlakçının aktif yetkilerini çeker.
  /// GET /api/manager/delegations/active
  Future<List<PropertyDelegation>> getActiveDelegationsForAgent([int? agentId]) async {
    final uri = _apiClient.resolveUri('/manager/delegations/active');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => PropertyDelegation.fromJson(e))
          .toList();
    }
    return [];
  }

  // --- UYUMLULUK VE ALIAS METOTLARI ---

  Future<PropertyDelegation> assignAgent({
    required int propertyId,
    int? agentId,
    String? agentEmail,
    int? landlordId,
    String? startDate,
    String? endDate,
    String? notes,
  }) async {
    return createLandlordDelegation(
      propertyId: propertyId,
      agentEmail: agentEmail ?? '',
      landlordId: landlordId,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
    );
  }

  Future<PropertyDelegation?> revokeDelegation(
    int delegationId, {
    int? landlordId,
    String? reason,
  }) async {
    await deleteLandlordDelegation(delegationId, reason: reason);
    return null;
  }

  Future<List<PropertyDelegation>> getDelegationsForLandlord(int landlordId) async {
    return getLandlordDelegations(landlordId: landlordId);
  }

  Future<List<PropertyDelegation>> getDelegationsForProperty(int propertyId) async {
    final all = await getLandlordDelegations();
    return all.where((d) => d.propertyId == propertyId).toList();
  }
}
