class PropertyDelegation {
  final int id;
  final int propertyId;
  final String propertyTitle;
  final String? propertyAddress;
  final String? propertyCity;
  final int agentId;
  final String? agentName;
  final String? agentEmail;
  final String? agentPhone;
  final int? grantedById;
  final String? grantedByName;
  final String? grantedByEmail;
  final String status; // ACTIVE, REVOKED, EXPIRED
  final String? startDate;
  final String? endDate;
  final String? revokedAt;
  final String? revocationReason;
  final String? createdAt;
  final String? referenceCode;

  PropertyDelegation({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    this.propertyAddress,
    this.propertyCity,
    required this.agentId,
    this.agentName,
    this.agentEmail,
    this.agentPhone,
    this.grantedById,
    this.grantedByName,
    this.grantedByEmail,
    required this.status,
    this.startDate,
    this.endDate,
    this.revokedAt,
    this.revocationReason,
    this.createdAt,
    this.referenceCode,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isRevoked => status.toUpperCase() == 'REVOKED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return 'Aktif Yetki';
      case 'REVOKED':
        return 'İptal Edildi';
      case 'EXPIRED':
        return 'Süresi Doldu';
      default:
        return status;
    }
  }

  factory PropertyDelegation.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    String propTitle = '';
    String? propAddr;
    String? propCity;
    int propId = 0;

    if (json['property'] is Map) {
      final p = json['property'] as Map<String, dynamic>;
      propId = parseId(p['id']);
      propTitle = (p['title'] ?? p['name'] ?? '').toString();
      propAddr = p['address']?.toString();
      propCity = p['city']?.toString();
    } else {
      propId = parseId(json['propertyId']);
      propTitle = (json['propertyName'] ?? json['propertyTitle'] ?? '').toString();
      propAddr = json['propertyAddress']?.toString();
      propCity = json['propertyCity']?.toString();
    }

    int aId = 0;
    String? aName;
    String? aEmail;
    String? aPhone;

    if (json['agent'] is Map) {
      final a = json['agent'] as Map<String, dynamic>;
      aId = parseId(a['id']);
      aName = a['fullName']?.toString();
      aEmail = a['email']?.toString();
      aPhone = a['phone']?.toString();
    } else {
      aId = parseId(json['agentId']);
      aName = json['agentName']?.toString();
      aEmail = json['agentEmail']?.toString();
      aPhone = json['agentPhone']?.toString();
    }

    int? gId;
    String? gName;
    String? gEmail;

    if (json['grantedBy'] is Map) {
      final g = json['grantedBy'] as Map<String, dynamic>;
      gId = parseId(g['id']);
      gName = g['fullName']?.toString();
      gEmail = g['email']?.toString();
    } else {
      gId = json['grantedById'] != null ? parseId(json['grantedById']) : null;
      gName = json['grantedByName']?.toString();
      gEmail = json['grantedByEmail']?.toString();
    }

    return PropertyDelegation(
      id: parseId(json['id']),
      propertyId: propId,
      propertyTitle: propTitle,
      propertyAddress: propAddr,
      propertyCity: propCity,
      agentId: aId,
      agentName: aName,
      agentEmail: aEmail,
      agentPhone: aPhone,
      grantedById: gId,
      grantedByName: gName,
      grantedByEmail: gEmail,
      status: (json['status'] ?? 'ACTIVE').toString(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      revokedAt: json['revokedAt']?.toString(),
      revocationReason: json['revocationReason']?.toString(),
      createdAt: json['createdAt']?.toString(),
      referenceCode: json['referenceCode']?.toString() ??
          json['agentReferenceCode']?.toString() ??
          json['inviteCode']?.toString() ??
          json['invitationCode']?.toString() ??
          (json['agent'] is Map ? json['agent']['referenceCode']?.toString() : null),
    );
  }
}
