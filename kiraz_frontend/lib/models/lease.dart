class Lease {
  final int id;
  final int propertyId;
  final int tenantId;
  final double rentAmount;
  final String startDate;
  final String? propertyName;
  final String? propertyAddress;
  final String? status;
  final String? approvalStatus;
  final String? createdByName;
  final String? createdByRole;
  final String? rejectionReason;
  final String? inviteCode;
  final String? contractFileUrl;
  final String? tenantName;
  final String? tenantEmail;
  final String? tenantPhone;
  final double? depositAmount;
  final String? landlordName;
  final String? landlordEmail;
  final String? endDate;

  Lease({
    required this.id,
    required this.propertyId,
    required this.tenantId,
    required this.rentAmount,
    required this.startDate,
    this.propertyName,
    this.propertyAddress,
    this.status,
    this.approvalStatus,
    this.createdByName,
    this.createdByRole,
    this.rejectionReason,
    this.inviteCode,
    this.contractFileUrl,
    this.tenantName,
    this.tenantEmail,
    this.tenantPhone,
    this.depositAmount,
    this.landlordName,
    this.landlordEmail,
    this.endDate,
  });

  bool get isPendingLandlordApproval =>
      approvalStatus?.toUpperCase() == 'PENDING_LANDLORD_APPROVAL';

  bool get isRejected => approvalStatus?.toUpperCase() == 'REJECTED';

  bool get isApprovedOrActive =>
      approvalStatus?.toUpperCase() == 'ACTIVE' ||
      (status?.toUpperCase() == 'ACTIVE' && !isPendingLandlordApproval);

  String get approvalStatusDisplay {
    switch (approvalStatus?.toUpperCase()) {
      case 'PENDING_LANDLORD_APPROVAL':
        return 'Ev Sahibi Onayı Bekliyor';
      case 'ACTIVE':
        return 'Onaylandı / Aktif';
      case 'REJECTED':
        return 'Reddedildi';
      case 'TERMINATED':
        return 'Sonlandırıldı';
      default:
        return status ?? 'Bekliyor';
    }
  }

  factory Lease.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value, [dynamic nested]) {
      if (value is int) return value;
      if (nested is Map && nested['id'] is int) return nested['id'] as int;
      if (nested is Map && nested['id'] != null) {
        return int.tryParse(nested['id'].toString()) ?? 0;
      }
      if (value != null) return int.tryParse(value.toString()) ?? 0;
      return 0;
    }

    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    String? propName;
    String? propAddr;
    if (json['property'] is Map) {
      propName = (json['property']['name'] ?? json['property']['title'])?.toString();
      propAddr = json['property']['address']?.toString();
    }

    String? tName;
    String? tEmail;
    String? tPhone;
    if (json['tenant'] is Map) {
      tName = json['tenant']['fullName']?.toString();
      tEmail = json['tenant']['email']?.toString();
      tPhone = json['tenant']['phone']?.toString();
    } else {
      tName = json['tenantName']?.toString();
      tEmail = json['tenantEmail']?.toString();
    }

    String? lName;
    String? lEmail;
    if (json['landlord'] is Map) {
      lName = json['landlord']['fullName']?.toString();
      lEmail = json['landlord']['email']?.toString();
    } else if (json['property'] is Map && json['property']['landlord'] is Map) {
      lName = json['property']['landlord']['fullName']?.toString();
      lEmail = json['property']['landlord']['email']?.toString();
    } else {
      lName = json['landlordName']?.toString();
      lEmail = json['landlordEmail']?.toString();
    }

    String? creatorName = json['createdByName']?.toString();
    String? creatorRole = json['createdByRole']?.toString();
    if (json['createdBy'] is Map) {
      creatorName ??= json['createdBy']['fullName']?.toString();
      creatorRole ??= json['createdBy']['role']?.toString();
    }

    final rawApprovalStatus = json['approvalStatus'] ?? json['approvalStatusName'];

    return Lease(
      id: parseId(json['id']),
      propertyId: parseId(json['propertyId'], json['property']),
      tenantId: parseId(json['tenantId'], json['tenant']),
      rentAmount: parseAmount(json['rentAmount'] ?? json['monthlyRentAmount']),
      startDate: (json['startDate'] ?? '').toString(),
      propertyName: propName,
      propertyAddress: propAddr,
      status: json['status']?.toString(),
      approvalStatus: rawApprovalStatus?.toString(),
      createdByName: creatorName,
      createdByRole: creatorRole,
      rejectionReason: json['rejectionReason']?.toString(),
      inviteCode: json['inviteCode']?.toString(),
      contractFileUrl: json['contractFileUrl']?.toString(),
      tenantName: tName,
      tenantEmail: tEmail,
      tenantPhone: tPhone,
      depositAmount: json['depositAmount'] != null
          ? parseAmount(json['depositAmount'])
          : (json['deposit'] != null ? parseAmount(json['deposit']) : null),
      landlordName: lName,
      landlordEmail: lEmail,
      endDate: json['endDate']?.toString() ?? json['contractEndDate']?.toString(),
    );
  }
}
