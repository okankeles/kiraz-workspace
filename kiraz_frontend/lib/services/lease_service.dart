import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lease.dart';
import '../utils/constants.dart';

class LeaseService {
  Future<List<Lease>> getLeasesForProperty(int propertyId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/property/$propertyId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => Lease.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Sözleşmeler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sözleşme listesi alınırken hata oluştu: $e');
    }
  }

  Future<List<Lease>> getLeasesForTenant(int tenantId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/tenant/$tenantId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => Lease.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Sözleşmeler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sözleşme listesi alınırken hata oluştu: $e');
    }
  }

  Future<List<Lease>> getLeasesForLandlord(int landlordId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/landlord/$landlordId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => Lease.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Ev sahibi sözleşmeleri alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sözleşme listesi alınırken hata oluştu: $e');
    }
  }

  Future<Lease> createLease(
    int propertyId,
    String tenantName,
    String tenantEmail,
    double rentAmount,
    String startDate,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases');

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'propertyId': propertyId,
          'tenantName': tenantName,
          'tenantEmail': tenantEmail,
          'rentAmount': rentAmount,
          'startDate': startDate,
        }),
      );
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      return Lease.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception('Kiracı atanamadı: ${response.statusCode}');
    }
  }

  Future<String?> acceptLease(String inviteCode, String newPassword) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/leases/accept?inviteCode=${Uri.encodeComponent(inviteCode)}&newPassword=${Uri.encodeComponent(newPassword)}',
    );

    try {
      final response = await http.post(url);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map) {
          return data['tenantEmail'] as String? ??
              (data['tenant'] is Map ? data['tenant']['email'] as String? : null);
        }
        return null;
      } else {
        String msg = 'Davet kodu onaylanamadı: ${response.statusCode}';
        try {
          final dynamic data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> activateLease(int leaseId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/$leaseId/activate');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        String msg = 'Sözleşme onaylanamadı: ${response.statusCode}';
        try {
          final dynamic data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Lease> getLeaseById(int id) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/$id');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        return Lease.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception('Sözleşme bilgisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sözleşme detayı alınırken hata: $e');
    }
  }
}

