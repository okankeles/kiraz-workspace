class DashboardStats {
  final double totalPaid;
  final double upcoming;
  final double pendingApproval;
  final double overdue;

  DashboardStats({
    required this.totalPaid,
    required this.upcoming,
    required this.pendingApproval,
    required this.overdue,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      upcoming: (json['upcoming'] as num?)?.toDouble() ?? 0.0,
      pendingApproval: (json['pendingApproval'] as num?)?.toDouble() ?? 0.0,
      overdue: (json['overdue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPaid': totalPaid,
      'upcoming': upcoming,
      'pendingApproval': pendingApproval,
      'overdue': overdue,
    };
  }
}
