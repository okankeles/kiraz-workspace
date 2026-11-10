import 'dart:convert';
import '../models/property.dart';
import 'api_client.dart';

class PropertyService {
  final ApiClient _apiClient;

  PropertyService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Ev sahibinin mülk listesini çeker.
  /// GET /api/landlord/properties
  Future<List<Property>> getProperties({int? landlordId}) async {
    final uri = _apiClient.resolveUri('/landlord/properties');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Property.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Emlakçı / Mülk Yöneticisi için atanan mülkleri çeker.
  /// GET /api/manager/properties
  Future<List<Property>> getPropertiesForAgent([int? agentId]) async {
    final uri = _apiClient.resolveUri('/manager/properties');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Property.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Belirli bir mülkün detayını çeker.
  /// GET /api/properties/{id}
  Future<Property> getPropertyById(int propertyId) async {
    final uri = _apiClient.resolveUri('/properties/$propertyId');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Property.fromJson(data as Map<String, dynamic>);
  }

  /// Yeni mülk ekler (Yalnızca LANDLORD).
  /// POST /api/properties
  Future<Property> createProperty(
    String title,
    String address,
    String city,
    int? landlordId, {
    String? daskEndDate,
    double? depositAmount,
  }) async {
    final uri = _apiClient.resolveUri('/properties');

    final Map<String, dynamic> payload = {
      'title': title,
      'name': title,
      'address': address,
      'city': city,
    };
    if (daskEndDate != null && daskEndDate.isNotEmpty) {
      payload['daskEndDate'] = daskEndDate;
    }
    if (depositAmount != null) {
      payload['depositAmount'] = depositAmount;
    }

    final response = await _apiClient.post(uri, body: payload);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Property.fromJson(data as Map<String, dynamic>);
  }

  /// Mülk bilgilerini günceller.
  /// PUT /api/properties/{id}
  Future<Property> updateProperty(
    int id,
    String title,
    String address,
    String city, {
    String? daskEndDate,
    double? depositAmount,
  }) async {
    final uri = _apiClient.resolveUri('/properties/$id');

    final Map<String, dynamic> payload = {
      'title': title,
      'name': title,
      'address': address,
      'city': city,
    };
    if (daskEndDate != null && daskEndDate.isNotEmpty) {
      payload['daskEndDate'] = daskEndDate;
    }
    if (depositAmount != null) {
      payload['depositAmount'] = depositAmount;
    }

    final response = await _apiClient.put(uri, body: payload);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Property.fromJson(data as Map<String, dynamic>);
  }
}
