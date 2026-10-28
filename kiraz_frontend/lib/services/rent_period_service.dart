import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/pending_approval_item.dart';
import '../models/rent_period.dart';
import '../utils/constants.dart';
import 'lease_service.dart';

class RentPeriodService {
  Future<List<PendingApprovalItem>> getPendingApprovalsForLandlord(int landlordId) async {
    try {
      final leases = await LeaseService().getLeasesForLandlord(landlordId);
      final List<PendingApprovalItem> pendingList = [];

      for (final lease in leases) {
        try {
          final periods = await getPeriodsForLease(lease.id);
          for (final p in periods) {
            final statusUpper = p.status.toUpperCase();
            final isPending = statusUpper == 'PENDING' || statusUpper == 'BEKLİYOR';
            final hasReceipt = p.receiptImageUrl != null && p.receiptImageUrl!.trim().isNotEmpty;
            if (isPending && hasReceipt) {
              pendingList.add(PendingApprovalItem(period: p, lease: lease));
            }
          }
        } catch (_) {}
      }

      return pendingList;
    } catch (e) {
      return [];
    }
  }

  Future<List<RentPeriod>> getPeriodsForLease(int leaseId) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/periods/lease/$leaseId');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data
              .map((item) => RentPeriod.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw Exception('Ödeme dönemleri alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Dönem listesi alınırken hata: $e');
    }
  }

  Future<void> uploadReceipt(int periodId, PlatformFile file) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/periods/$periodId/receipt');

    try {
      final request = http.MultipartRequest('POST', url);

      List<int> bytes = file.bytes ?? [];
      if (bytes.isEmpty && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      String filename = file.name;
      MediaType? contentType;
      final ext = file.extension?.toLowerCase();
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
        throw Exception('Dekont yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Yükleme hatası: $e');
    }
  }

  Future<void> updatePeriodStatus(int periodId, String status) async {
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/periods/$periodId/status?status=${Uri.encodeComponent(status)}',
    );

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Durum güncellenemedi: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Durum güncellenirken hata: $e');
    }
  }

  Future<void> updateStatus(int periodId, String status) => updatePeriodStatus(periodId, status);
}
