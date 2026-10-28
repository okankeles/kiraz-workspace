class Property {
  final int id;
  final String name;
  final String address;
  final String? tenantName;
  final String? tenantPhone;
  final String? tenantEmail;
  final DateTime? daskEndDate;
  final double? depositAmount;

  Property({
    required this.id,
    required this.name,
    required this.address,
    this.tenantName,
    this.tenantPhone,
    this.tenantEmail,
    this.daskEndDate,
    this.depositAmount,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDaskDate;
    if (json['daskEndDate'] != null) {
      try {
        parsedDaskDate = DateTime.parse(json['daskEndDate'].toString());
      } catch (_) {}
    }

    double? parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return Property(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? json['title'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      tenantName: json['tenantName']?.toString() ??
          (json['tenant'] is Map ? json['tenant']['fullName']?.toString() : null),
      tenantPhone: json['tenantPhone']?.toString() ??
          (json['tenant'] is Map ? json['tenant']['phone']?.toString() : null),
      tenantEmail: json['tenantEmail']?.toString() ??
          (json['tenant'] is Map ? json['tenant']['email']?.toString() : null),
      daskEndDate: parsedDaskDate,
      depositAmount: parseAmount(json['depositAmount'] ?? json['deposit']),
    );
  }
}

