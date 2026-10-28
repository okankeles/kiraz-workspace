enum TxStatus { pending, approved, rejected }

class FinancialTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String propertyName;
  TxStatus status;
  final bool hasReceiptImage;
  final String? rentPeriodId;

  FinancialTransaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.propertyName,
    this.status = TxStatus.pending,
    this.hasReceiptImage = false,
    this.rentPeriodId,
  });
}
