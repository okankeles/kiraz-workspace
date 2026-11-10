import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/lease.dart';
import '../models/pending_approval_item.dart';
import '../models/rent_period.dart';
import 'api_client.dart';
import 'landlord_service.dart';

class RentPeriodService {
  final ApiClient _apiClient;

  RentPeriodService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient.instance;

  /// Sözleşmeye ait kira dönemlerini çeker.
  /// GET /api/periods/lease/{leaseId}
  Future<List<RentPeriod>> getPeriodsForLease(int leaseId) async {
    final uri = _apiClient.resolveUri('/periods/lease/$leaseId');
    final response = await _apiClient.get(uri);

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => RentPeriod.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Kiracı tarafından dekont yükleme.
  /// POST /api/tenant/receipts/{periodId} (Multipart, alan adı "file")
  Future<void> uploadReceipt(int periodId, PlatformFile file) async {
    List<int> bytes = file.bytes ?? [];
    if (bytes.isEmpty && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }

    if (bytes.isEmpty) {
      throw ApiException(statusCode: 400, message: 'Seçilen dosya boş veya okunamadı.');
    }

    // 10 MB sınır kontrolü (10 * 1024 * 1024 bytes)
    if (bytes.length > 10 * 1024 * 1024) {
      throw ApiException(
        statusCode: 400,
        message: 'Dosya boyutu 10 MB\'tan büyük olamaz.',
      );
    }

    final ext = file.extension?.toLowerCase() ?? '';
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

    final uri = _apiClient.resolveUri('/tenant/receipts/$periodId');

    await _apiClient.sendMultipart(() async {
      final request = http.MultipartRequest('POST', uri);
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      return request;
    });
  }

  /// Ev sahibi için bekleyen dekont onaylarını çeker (LandlordService üzerinden).
  Future<List<PendingApprovalItem>> getPendingApprovalsForLandlord(int landlordId) async {
    try {
      final pendingReceipts = await LandlordService().getPendingReceipts(landlordId: landlordId);
      return pendingReceipts.map((r) => PendingApprovalItem(
        period: RentPeriod(
          id: r.periodId,
          periodStart: r.periodStart ?? DateTime.now(),
          periodEnd: (r.periodStart ?? DateTime.now()).add(const Duration(days: 30)).toIso8601String(),
          status: r.status,
          receiptImageUrl: r.receiptImageUrl,
          expectedAmount: r.amount,
        ),
        lease: Lease(
          id: r.leaseId ?? 0,
          propertyId: 0,
          tenantId: 0,
          rentAmount: r.amount,
          startDate: (r.periodStart ?? DateTime.now()).toIso8601String(),
          propertyName: r.propertyName,
          tenantName: r.tenantName,
        ),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Dekont onay/ret işlemi (Kanonik LandlordService üzerinden).
  Future<void> updatePeriodStatus(int periodId, String status) async {
    final s = status.toUpperCase();
    if (s == 'PAID' || s == 'ÖDENDİ' || s == 'APPROVED' || s == 'ONAYLANDI') {
      await LandlordService().approveReceipt(periodId);
    } else {
      await LandlordService().rejectReceipt(periodId);
    }
  }

  Future<void> updateStatus(int periodId, String status) => updatePeriodStatus(periodId, status);

  /// Hukuki süreç başlatma
  Future<RentPeriod> initiateLegalProcess(
    int periodId, {
    int? userId,
    String? notes,
  }) async {
    final queryParams = <String, dynamic>{};
    if (notes != null && notes.trim().isNotEmpty) {
      queryParams['notes'] = notes.trim();
    }
    final uri = _apiClient.resolveUri('/periods/$periodId/legal-process', queryParams);
    final response = await _apiClient.put(uri);
    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    return RentPeriod.fromJson(data as Map<String, dynamic>);
  }
}
