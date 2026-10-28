enum PaymentStatus { paid, unpaid, pending }

class MockRentPeriod {
  final String id;
  final String propertyName;
  final String monthName;
  final double amount;
  PaymentStatus status;
  String? receiptImagePath;

  MockRentPeriod({
    required this.id,
    required this.propertyName,
    required this.monthName,
    required this.amount,
    required this.status,
    this.receiptImagePath,
  });
}

typedef RentPeriod = MockRentPeriod;
