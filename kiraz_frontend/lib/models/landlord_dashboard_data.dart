class MonthlyIncomeItem {
  final String month;
  final double amount;

  MonthlyIncomeItem({
    required this.month,
    required this.amount,
  });

  factory MonthlyIncomeItem.fromJson(Map<String, dynamic> json) {
    return MonthlyIncomeItem(
      month: (json['month'] ?? json['name'] ?? json['label'] ?? json['monthName'] ?? '').toString(),
      amount: (json['amount'] ?? json['income'] ?? json['totalIncome'] ?? json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'month': month,
    'amount': amount,
  };
}

class ExpiringLeaseItem {
  final int id;
  final String propertyName;
  final String tenantName;
  final String endDate;
  final int daysLeft;
  final double rentAmount;

  ExpiringLeaseItem({
    required this.id,
    required this.propertyName,
    required this.tenantName,
    required this.endDate,
    required this.daysLeft,
    this.rentAmount = 0.0,
  });

  factory ExpiringLeaseItem.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '') ?? 0;
    }

    double parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '') ?? 0.0;
    }

    int calcDaysLeft(String? endStr, dynamic explicitDays) {
      if (explicitDays is num) return explicitDays.toInt();
      if (explicitDays is String) {
        final parsed = int.tryParse(explicitDays);
        if (parsed != null) return parsed;
      }
      if (endStr != null && endStr.isNotEmpty) {
        final dt = DateTime.tryParse(endStr);
        if (dt != null) {
          final now = DateTime.now();
          final diff = dt.difference(now).inDays;
          return diff >= 0 ? diff : 0;
        }
      }
      return 30;
    }

    String pName = (json['propertyName'] ?? json['propertyTitle'] ?? '').toString();
    if (pName.isEmpty && json['property'] is Map) {
      pName = (json['property']['name'] ?? json['property']['title'] ?? '').toString();
    }
    if (pName.isEmpty) pName = 'Kiralık Mülk';

    String tName = (json['tenantName'] ?? '').toString();
    if (tName.isEmpty && json['tenant'] is Map) {
      tName = (json['tenant']['fullName'] ?? json['tenant']['name'] ?? '').toString();
    }
    if (tName.isEmpty) tName = 'Kiracı';

    final endStr = (json['endDate'] ?? json['contractEndDate'] ?? json['leaseEnd'] ?? '').toString();
    final days = calcDaysLeft(endStr, json['daysLeft'] ?? json['remainingDays']);
    final rent = parseAmount(json['rentAmount'] ?? json['monthlyRentAmount']);

    return ExpiringLeaseItem(
      id: parseId(json['id'] ?? json['leaseId']),
      propertyName: pName,
      tenantName: tName,
      endDate: endStr,
      daysLeft: days,
      rentAmount: rent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'propertyName': propertyName,
    'tenantName': tenantName,
    'endDate': endDate,
    'daysLeft': daysLeft,
    'rentAmount': rentAmount,
  };
}

class LandlordDashboardData {
  final double totalMonthlyIncome;
  final double totalPendingReceivables;
  final double occupancyRate;
  final List<MonthlyIncomeItem> incomeTrend;
  final List<ExpiringLeaseItem> expiringLeases;

  LandlordDashboardData({
    required this.totalMonthlyIncome,
    required this.totalPendingReceivables,
    required this.occupancyRate,
    required this.incomeTrend,
    required this.expiringLeases,
  });

  double get normalizedOccupancy {
    if (occupancyRate <= 0.0) return 0.0;
    if (occupancyRate <= 1.0) return occupancyRate;
    return (occupancyRate / 100.0).clamp(0.0, 1.0);
  }

  int get occupancyPercentage {
    if (occupancyRate <= 0.0) return 0;
    if (occupancyRate <= 1.0) return (occupancyRate * 100).round();
    return occupancyRate.round();
  }

  factory LandlordDashboardData.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final income = parseDouble(
      json['totalMonthlyIncome'] ?? json['monthlyIncome'] ?? json['income'] ?? json['totalIncome'],
    );
    final pending = parseDouble(
      json['totalPendingReceivables'] ?? json['pendingReceivables'] ?? json['pendingAmount'] ?? json['overdue'],
    );
    final occupancy = parseDouble(
      json['occupancyRate'] ?? json['occupancy'] ?? json['occupancyPercentage'],
    );

    List<MonthlyIncomeItem> trend = [];
    final trendRaw = json['incomeTrend'] ?? json['monthlyIncomes'] ?? json['monthlyStats'] ?? json['last6MonthsIncome'];
    if (trendRaw is List) {
      trend = trendRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => MonthlyIncomeItem.fromJson(item))
          .toList();
    } else if (trendRaw is Map) {
      trend = trendRaw.entries
          .map((e) => MonthlyIncomeItem(month: e.key.toString(), amount: parseDouble(e.value)))
          .toList();
    }

    List<ExpiringLeaseItem> expiring = [];
    final expiringRaw = json['expiringLeases'] ?? json['upcomingExpiringLeases'] ?? json['upcomingExpirations'];
    if (expiringRaw is List) {
      expiring = expiringRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => ExpiringLeaseItem.fromJson(item))
          .toList();
    }

    return LandlordDashboardData(
      totalMonthlyIncome: income,
      totalPendingReceivables: pending,
      occupancyRate: occupancy,
      incomeTrend: trend,
      expiringLeases: expiring,
    );
  }

  LandlordDashboardData copyWith({
    double? totalMonthlyIncome,
    double? totalPendingReceivables,
    double? occupancyRate,
    List<MonthlyIncomeItem>? incomeTrend,
    List<ExpiringLeaseItem>? expiringLeases,
  }) {
    return LandlordDashboardData(
      totalMonthlyIncome: totalMonthlyIncome ?? this.totalMonthlyIncome,
      totalPendingReceivables: totalPendingReceivables ?? this.totalPendingReceivables,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      incomeTrend: incomeTrend ?? this.incomeTrend,
      expiringLeases: expiringLeases ?? this.expiringLeases,
    );
  }
}
