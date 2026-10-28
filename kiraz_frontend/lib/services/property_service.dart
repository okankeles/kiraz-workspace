import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/property.dart';
import '../utils/constants.dart';

class PropertyService {
  Future<List<Property>> getProperties({int? landlordId}) async {
    int? targetLandlordId = landlordId;
    if (targetLandlordId == null) {
      final prefs = await SharedPreferences.getInstance();
      targetLandlordId = prefs.getInt('userId');
    }

    final url = targetLandlordId != null
        ? Uri.parse('${ApiConstants.baseUrl}/properties?landlordId=$targetLandlordId')
        : Uri.parse('${ApiConstants.baseUrl}/properties');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => Property.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Mülkler yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Mülk listesi alınırken hata oluştu: $e');
    }
  }

  Future<Property> createProperty(
    String title,
    String address,
    String city,
    int landlordId, {
    String? daskEndDate,
    double? depositAmount,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/properties');

    final Map<String, dynamic> payload = {
      'title': title,
      'address': address,
      'city': city,
      'landlordId': landlordId,
    };
    if (daskEndDate != null && daskEndDate.isNotEmpty) {
      payload['daskEndDate'] = daskEndDate;
    }
    if (depositAmount != null) {
      payload['depositAmount'] = depositAmount;
    }

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      return Property.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception('Mülk eklenemedi: ${response.statusCode}');
    }
  }
}
