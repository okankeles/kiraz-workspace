class PaymentSummary {
  final double totalDebt;
  final double totalPaid;
  final String? nextPaymentDate;
  final double nextPaymentAmount;

  PaymentSummary({
    required this.totalDebt,
    required this.totalPaid,
    this.nextPaymentDate,
    required this.nextPaymentAmount,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalDebt: (json['totalDebt'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      nextPaymentDate: json['nextPaymentDate']?.toString(),
      nextPaymentAmount: (json['nextPaymentAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDebt': totalDebt,
      'totalPaid': totalPaid,
      'nextPaymentDate': nextPaymentDate,
      'nextPaymentAmount': nextPaymentAmount,
    };
  }
}
