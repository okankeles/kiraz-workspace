import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lease.dart';
import '../utils/constants.dart';

class LeaseService {
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

  Future<List<Lease>> getLeasesForProperty(int propertyId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/property/$propertyId');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

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
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

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
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

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

  Future<List<Lease>> getPendingApprovalsForLandlord(int landlordId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/landlord/$landlordId/pending-approvals');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => Lease.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Onay bekleyen sözleşmeler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Onay listesi alınırken hata: $e');
    }
  }

  Future<Lease> approveLease(int leaseId, {int? landlordId}) async {
    int? effectiveLandlordId = landlordId;
    if (effectiveLandlordId == null) {
      final prefs = await SharedPreferences.getInstance();
      effectiveLandlordId = prefs.getInt('userId');
    }

    final query = effectiveLandlordId != null ? '?landlordId=$effectiveLandlordId' : '';
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/$leaseId/approve$query');
    final headers = await _getHeaders();

    try {
      final response = await http.put(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        return Lease.fromJson(data as Map<String, dynamic>);
      } else {
        String msg = 'Sözleşme onaylanamadı (${response.statusCode})';
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

  Future<Lease> rejectLease(int leaseId, {int? landlordId, String? reason}) async {
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

    final url = Uri.parse('${ApiConstants.baseUrl}/leases/$leaseId/reject')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final headers = await _getHeaders();

    try {
      final response = await http.put(url, headers: headers);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        return Lease.fromJson(data as Map<String, dynamic>);
      } else {
        String msg = 'Sözleşme reddedilemedi (${response.statusCode})';
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

  Future<Lease> createLease(
    int propertyId,
    String tenantName,
    String tenantEmail,
    double rentAmount,
    String startDate, {
    double? depositAmount,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? prefs.getInt('userId');

    final url = Uri.parse('${ApiConstants.baseUrl}/leases');

    final Map<String, dynamic> body = {
      'propertyId': propertyId,
      'tenantName': tenantName,
      'tenantEmail': tenantEmail,
      'rentAmount': rentAmount,
      'startDate': startDate,
    };
    if (effectiveUserId != null) {
      body['userId'] = effectiveUserId;
    }
    if (depositAmount != null) {
      body['depositAmount'] = depositAmount;
    }

    final headers = await _getHeaders();

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      return Lease.fromJson(data as Map<String, dynamic>);
    } else {
      String msg = 'Kiracı atanamadı: ${response.statusCode}';
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('message')) {
          msg = errorData['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
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
    final headers = await _getHeaders();

    try {
      final response = await http.put(
        url,
        headers: headers,
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
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);

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

  Future<void> uploadContract(int leaseId, File file) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/leases/$leaseId/contract');

    try {
      final request = http.MultipartRequest('POST', url);

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId != null) {
        request.headers['X-User-Id'] = userId.toString();
        request.headers['Authorization'] = 'Bearer $userId';
      }

      final bytes = await file.readAsBytes();
      final filename = file.path.split(Platform.pathSeparator).last;
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';

      MediaType? contentType;
      if (ext == 'png') {
        contentType = MediaType('image', 'png');
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = MediaType('image', 'jpeg');
      } else if (ext == 'pdf') {
        contentType = MediaType('application', 'pdf');
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Sözleşme yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sözleşme yükleme hatası: $e');
    }
  }
}
