import 'pending_approval_item.dart';

class ReceiptApprovalItem {
  final int periodId;
  final int? leaseId;
  final String tenantName;
  final String propertyName;
  final String periodMonthYear;
  final DateTime? periodStart;
  final double amount;
  final String receiptImageUrl;
  final String status;
  final String? rejectionReason;

  ReceiptApprovalItem({
    required this.periodId,
    this.leaseId,
    required this.tenantName,
    required this.propertyName,
    this.periodMonthYear = '',
    this.periodStart,
    required this.amount,
    required this.receiptImageUrl,
    this.status = 'WAITING_APPROVAL',
    this.rejectionReason,
  });

  String get formattedMonthYear {
    if (periodMonthYear.isNotEmpty) return periodMonthYear;
    if (periodStart != null) {
      const months = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      final monthName = (periodStart!.month >= 1 && periodStart!.month <= 12)
          ? months[periodStart!.month - 1]
          : '${periodStart!.month}';
      return '$monthName ${periodStart!.year}';
    }
    return 'Kira Dönemi';
  }

  bool get isPdf => receiptImageUrl.toLowerCase().endsWith('.pdf');

  factory ReceiptApprovalItem.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    double parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '') ?? 0.0;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    String tName = (json['tenantName'] ?? '').toString();
    if (tName.isEmpty && json['tenant'] is Map) {
      tName = (json['tenant']['fullName'] ?? json['tenant']['name'] ?? '').toString();
    }
    if (tName.isEmpty) tName = 'Kiracı';

    String pName = (json['propertyName'] ?? json['propertyTitle'] ?? '').toString();
    if (pName.isEmpty && json['property'] is Map) {
      pName = (json['property']['name'] ?? json['property']['title'] ?? '').toString();
    }
    if (pName.isEmpty) pName = 'Kiralık Mülk';

    final pStart = parseDate(json['periodStart'] ?? json['startDate']);
    final mYear = (json['periodMonthYear'] ?? json['monthYear'] ?? json['periodName'] ?? '').toString();

    final amt = parseAmount(
      json['amount'] ?? json['expectedAmount'] ?? json['rentAmount'] ?? json['paymentAmount'],
    );

    final imgUrl = (json['receiptImageUrl'] ?? json['receiptUrl'] ?? json['imageUrl'] ?? '').toString();
    final statusStr = (json['status'] ?? 'WAITING_APPROVAL').toString();

    return ReceiptApprovalItem(
      periodId: parseId(json['periodId'] ?? json['id']),
      leaseId: json['leaseId'] != null ? parseId(json['leaseId']) : null,
      tenantName: tName,
      propertyName: pName,
      periodMonthYear: mYear,
      periodStart: pStart,
      amount: amt,
      receiptImageUrl: imgUrl,
      status: statusStr,
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }

  factory ReceiptApprovalItem.fromPendingApprovalItem(PendingApprovalItem item) {
    return ReceiptApprovalItem(
      periodId: item.period.id,
      leaseId: item.lease.id,
      tenantName: item.tenantName,
      propertyName: item.propertyName,
      amount: item.period.expectedAmount > 0 ? item.period.expectedAmount : item.amount,
      receiptImageUrl: item.period.receiptImageUrl ?? '',
      periodStart: item.period.periodStart,
      status: item.period.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'periodId': periodId,
    'leaseId': leaseId,
    'tenantName': tenantName,
    'propertyName': propertyName,
    'periodMonthYear': periodMonthYear,
    'periodStart': periodStart?.toIso8601String(),
    'amount': amount,
    'receiptImageUrl': receiptImageUrl,
    'status': status,
    'rejectionReason': rejectionReason,
  };
}
