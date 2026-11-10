import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/lease.dart';
import '../models/regenerate_invite_response.dart';
import 'api_client.dart';

class LeaseService {
  final ApiClient _apiClient;

  LeaseService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Bir mülke ait sözleşmeleri çeker.
  /// GET /api/leases/property/{propertyId}
  Future<List<Lease>> getLeasesForProperty(int propertyId) async {
    final uri = _apiClient.resolveUri('/leases/property/$propertyId');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Lease.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Kiracıya ait sözleşmeleri çeker.
  /// GET /api/tenant/leases
  Future<List<Lease>> getLeasesForTenant([int? tenantId]) async {
    final uri = _apiClient.resolveUri('/tenant/leases');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Lease.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Ev sahibine ait sözleşmeleri çeker.
  /// GET /api/landlord/leases
  Future<List<Lease>> getLeasesForLandlord([int? landlordId]) async {
    final uri = _apiClient.resolveUri('/landlord/leases');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Lease.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Ev sahibi için onay bekleyen sözleşmeleri çeker.
  /// GET /api/landlord/leases/pending-approvals
  Future<List<Lease>> getPendingApprovalsForLandlord([int? landlordId]) async {
    final uri = _apiClient.resolveUri('/landlord/leases/pending-approvals');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => Lease.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Ev sahibinin emlakçı tarafından açılan sözleşmeyi onaylaması.
  /// POST /api/landlord/leases/{id}/approve
  Future<Lease> approveLease(int leaseId, {int? landlordId}) async {
    final uri = _apiClient.resolveUri('/landlord/leases/$leaseId/approve');
    final response = await _apiClient.post(uri, body: {});

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Lease.fromJson(data as Map<String, dynamic>);
  }

  /// Ev sahibinin emlakçı tarafından açılan sözleşmeyi reddetmesi.
  /// POST /api/landlord/leases/{id}/reject
  Future<Lease> rejectLease(int leaseId, {int? landlordId, String? reason}) async {
    final cleanReason = reason?.trim() ?? '';
    final uri = _apiClient.resolveUri(
      '/landlord/leases/$leaseId/reject',
      cleanReason.isNotEmpty ? {'reason': cleanReason} : null,
    );
    final response = await _apiClient.post(
      uri,
      body: {'reason': cleanReason},
    );

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Lease.fromJson(data as Map<String, dynamic>);
  }

  /// Yeni sözleşme oluşturur.
  /// POST /api/leases
  Future<Lease> createLease(
    int propertyId,
    String tenantName,
    String tenantEmail,
    double rentAmount,
    String startDate, {
    double? depositAmount,
    int? userId,
  }) async {
    final uri = _apiClient.resolveUri('/leases');

    final Map<String, dynamic> body = {
      'propertyId': propertyId,
      'tenantName': tenantName,
      'tenantEmail': tenantEmail,
      'rentAmount': rentAmount,
      'startDate': startDate,
    };
    if (depositAmount != null) {
      body['depositAmount'] = depositAmount;
    }

    final response = await _apiClient.post(uri, body: body);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Lease.fromJson(data as Map<String, dynamic>);
  }

  /// Davet kodunu doğrular.
  /// GET /api/leases/validate-invite?inviteCode=... (Kimlik doğrulamasız)
  Future<Map<String, dynamic>> validateInvite(String inviteCode) async {
    final uri = _apiClient.resolveUri(
      '/leases/validate-invite',
      {'inviteCode': inviteCode.trim()},
    );

    final response = await _apiClient.get(uri, requiresAuth: false);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Daveti kabul eder ve şifre belirler.
  /// POST /api/leases/accept (Kimlik doğrulamasız)
  Future<String?> acceptLease(String inviteCode, String newPassword) async {
    final uri = _apiClient.resolveUri('/leases/accept');
    final response = await _apiClient.post(
      uri,
      body: {
        'inviteCode': inviteCode.trim(),
        'newPassword': newPassword,
      },
      requiresAuth: false,
    );

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is Map) {
      return data['tenantEmail'] as String? ??
          (data['tenant'] is Map ? data['tenant']['email'] as String? : null);
    }
    return null;
  }

  /// Sözleşmeyi aktif eder (Ev sahibi onayı yoksa 409 döner).
  /// PUT /api/leases/{id}/activate
  Future<void> activateLease(int leaseId) async {
    final uri = _apiClient.resolveUri('/leases/$leaseId/activate');
    try {
      await _apiClient.put(uri);
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) {
        throw ApiException(
          statusCode: 409,
          message: 'Ev sahibi onayı bekleniyor. Sözleşme henüz onaylanmamış.',
        );
      }
      rethrow;
    }
  }

  /// Tek bir sözleşme detayını çeker.
  /// GET /api/leases/{id}
  Future<Lease> getLeaseById(int id) async {
    final uri = _apiClient.resolveUri('/leases/$id');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return Lease.fromJson(data as Map<String, dynamic>);
  }

  /// Sözleşme belgesi yükler.
  /// POST /api/leases/{id}/contract (Multipart, alan adı "file")
  Future<void> uploadContract(int leaseId, File file) async {
    final bytes = await file.readAsBytes();

    // 10 MB sınır kontrolü (10 * 1024 * 1024 bytes)
    if (bytes.length > 10 * 1024 * 1024) {
      throw ApiException(
        statusCode: 400,
        message: 'Dosya boyutu 10 MB\'tan büyük olamaz.',
      );
    }

    final filename = file.path.split(Platform.pathSeparator).last;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';

    MediaType? contentType;
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else if (ext == 'pdf') {
      contentType = MediaType('application', 'pdf');
    } else {
      throw ApiException(
        statusCode: 400,
        message: 'Yalnızca PDF, JPEG ve PNG formatları desteklenmektedir.',
      );
    }

    final uri = _apiClient.resolveUri('/leases/$leaseId/contract');

    await _apiClient.sendMultipart(() async {
      final request = http.MultipartRequest('POST', uri);
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      return request;
    });
  }

  /// Sözleşme için yeni davet kodu üretir ve eskisini geçersiz kılar (Yalnızca LANDLORD).
  /// POST /api/landlord/leases/{id}/regenerate-invite
  Future<RegenerateInviteResponse> regenerateInviteCode(int leaseId) async {
    final uri = _apiClient.resolveUri('/landlord/leases/$leaseId/regenerate-invite');
    try {
      final response = await _apiClient.post(uri);
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      return RegenerateInviteResponse.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        if (e.statusCode == 409) {
          throw ApiException(
            statusCode: 409,
            message: 'Kiracı zaten bağlanmış veya sözleşme artık aktif değil. Yeni davet kodu üretilemez.',
          );
        } else if (e.statusCode == 404) {
          throw ApiException(
            statusCode: 404,
            message: 'Sözleşme bulunamadı veya bu işlem için yetkiniz yok.',
          );
        }
      }
      rethrow;
    }
  }
}
