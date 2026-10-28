class RentPeriod {
  final int id;
  final DateTime? periodStart;
  final String periodEnd;
  final String status;
  final String? receiptImageUrl;
  final String? paymentDate;
  final double expectedAmount;

  RentPeriod({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.receiptImageUrl,
    this.paymentDate,
    this.expectedAmount = 0.0,
  });

  String get periodStartFormatted {
    if (periodStart == null) return '';
    return "${periodStart!.year}-${periodStart!.month.toString().padLeft(2, '0')}-${periodStart!.day.toString().padLeft(2, '0')}";
  }

  RentPeriod copyWith({
    int? id,
    DateTime? periodStart,
    String? periodEnd,
    String? status,
    String? receiptImageUrl,
    String? paymentDate,
    double? expectedAmount,
  }) {
    return RentPeriod(
      id: id ?? this.id,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      status: status ?? this.status,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      paymentDate: paymentDate ?? this.paymentDate,
      expectedAmount: expectedAmount ?? this.expectedAmount,
    );
  }

  factory RentPeriod.fromJson(Map<String, dynamic> json) {
    DateTime? startDate;
    final rawStart = json['periodStart'];
    if (rawStart != null) {
      if (rawStart is DateTime) {
        startDate = rawStart;
      } else {
        startDate = DateTime.tryParse(rawStart.toString());
      }
    }

    String endStr = (json['periodEnd'] ?? '').toString();
    if (endStr.isEmpty && startDate != null) {
      final endDt = DateTime(startDate.year, startDate.month + 1, startDate.day);
      endStr =
          "${endDt.year.toString().padLeft(4, '0')}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}";
    }

    final payDateStr = json['paymentDate']?.toString();

    final parsedExpected = json['expectedAmount'] ??
        json['rentAmount'] ??
        json['monthlyRentAmount'] ??
        (json['leaseAgreement'] is Map ? json['leaseAgreement']['monthlyRentAmount'] : null);
    final expected = parsedExpected != null
        ? (double.tryParse(parsedExpected.toString()) ?? 0.0)
        : 0.0;

    return RentPeriod(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      periodStart: startDate,
      periodEnd: endStr,
      status: (json['status'] ?? 'PENDING').toString(),
      receiptImageUrl: json['receiptImageUrl']?.toString(),
      paymentDate: payDateStr != null && payDateStr.isNotEmpty ? payDateStr : (endStr.isNotEmpty ? endStr : null),
      expectedAmount: expected,
    );
  }
}
