class RentPeriod {
  final int id;
  final String periodStart;
  final String periodEnd;
  final String status;
  final String? receiptImageUrl;
  final String? paymentDate;

  RentPeriod({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.receiptImageUrl,
    this.paymentDate,
  });

  factory RentPeriod.fromJson(Map<String, dynamic> json) {
    final startStr = (json['periodStart'] ?? '').toString();
    String endStr = (json['periodEnd'] ?? '').toString();

    if (endStr.isEmpty && startStr.isNotEmpty) {
      try {
        final startDt = DateTime.parse(startStr);
        final endDt = DateTime(startDt.year, startDt.month + 1, startDt.day);
        endStr =
            "${endDt.year.toString().padLeft(4, '0')}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    final payDateStr = json['paymentDate']?.toString();

    return RentPeriod(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      periodStart: startStr,
      periodEnd: endStr,
      status: (json['status'] ?? 'PENDING').toString(),
      receiptImageUrl: json['receiptImageUrl']?.toString(),
      paymentDate: payDateStr != null && payDateStr.isNotEmpty ? payDateStr : (endStr.isNotEmpty ? endStr : null),
    );
  }
}
