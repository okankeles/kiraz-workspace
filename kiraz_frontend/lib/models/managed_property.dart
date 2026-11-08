import 'property.dart';
import 'property_delegation.dart';

class ManagedProperty {
  final int id;
  final String name;
  final String address;
  final String? city;
  final String? landlordName;
  final String? landlordEmail;
  final String? landlordPhone;
  final int activeLeasesCount;
  final String? statusSummary;
  final String? tenantName;
  final String? tenantPhone;
  final DateTime? daskEndDate;
  final double? depositAmount;
  final int? delegationId;
  final String? delegationStatus;
  final String? referenceCode;

  ManagedProperty({
    required this.id,
    required this.name,
    required this.address,
    this.city,
    this.landlordName,
    this.landlordEmail,
    this.landlordPhone,
    this.activeLeasesCount = 0,
    this.statusSummary,
    this.tenantName,
    this.tenantPhone,
    this.daskEndDate,
    this.depositAmount,
    this.delegationId,
    this.delegationStatus,
    this.referenceCode,
  });

  /// Genel durum metnini döndürür (Örn: "2 aktif sözleşme", "1 aktif sözleşme", "Aktif sözleşme yok")
  String get displayStatus {
    if (statusSummary != null && statusSummary!.trim().isNotEmpty) {
      return statusSummary!;
    }
    if (activeLeasesCount > 0) {
      return '$activeLeasesCount aktif sözleşme';
    }
    if (tenantName != null && tenantName!.trim().isNotEmpty) {
      return '1 aktif sözleşme';
    }
    return 'Aktif sözleşme yok';
  }

  /// Ev sahibi adını güvenli şekilde döndürür
  String get displayLandlord {
    if (landlordName != null && landlordName!.trim().isNotEmpty) {
      return landlordName!;
    }
    if (landlordEmail != null && landlordEmail!.trim().isNotEmpty) {
      return landlordEmail!;
    }
    return 'Ev Sahibi';
  }

  bool get isOccupied => (tenantName != null && tenantName!.trim().isNotEmpty) || activeLeasesCount > 0;

  factory ManagedProperty.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    double? parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    // Property bilgileri
    int propId = parseId(json['id'] ?? json['propertyId']);
    String propName = '';
    String propAddress = '';
    String? propCity = json['city']?.toString();

    if (json['property'] is Map) {
      final p = json['property'] as Map<String, dynamic>;
      propId = propId != 0 ? propId : parseId(p['id']);
      propName = (p['name'] ?? p['title'] ?? '').toString();
      propAddress = (p['address'] ?? '').toString();
      propCity = propCity ?? p['city']?.toString();
    } else {
      propName = (json['name'] ?? json['title'] ?? json['propertyName'] ?? json['propertyTitle'] ?? '').toString();
      propAddress = (json['address'] ?? json['propertyAddress'] ?? '').toString();
    }

    // Ev Sahibi bilgileri
    String? lName;
    String? lEmail;
    String? lPhone;

    if (json['landlord'] is Map) {
      final l = json['landlord'] as Map<String, dynamic>;
      lName = (l['fullName'] ?? l['name'])?.toString();
      lEmail = l['email']?.toString();
      lPhone = l['phone']?.toString();
    } else if (json['grantedBy'] is Map) {
      final g = json['grantedBy'] as Map<String, dynamic>;
      lName = (g['fullName'] ?? g['name'])?.toString();
      lEmail = g['email']?.toString();
    }

    lName = lName ?? json['landlordName']?.toString() ?? json['grantedByName']?.toString() ?? json['ownerName']?.toString();
    lEmail = lEmail ?? json['landlordEmail']?.toString() ?? json['grantedByEmail']?.toString();
    lPhone = lPhone ?? json['landlordPhone']?.toString();

    // Aktif sözleşme sayısı
    int leasesCount = 0;
    if (json['activeLeasesCount'] != null) {
      leasesCount = parseId(json['activeLeasesCount']);
    } else if (json['activeContractsCount'] != null) {
      leasesCount = parseId(json['activeContractsCount']);
    } else if (json['activeLeaseCount'] != null) {
      leasesCount = parseId(json['activeLeaseCount']);
    } else if (json['leases'] is List) {
      leasesCount = (json['leases'] as List).length;
    } else if (json['contracts'] is List) {
      leasesCount = (json['contracts'] as List).length;
    }

    // Kiracı bilgisi
    String? tName = json['tenantName']?.toString();
    String? tPhone = json['tenantPhone']?.toString();
    if (json['tenant'] is Map) {
      final t = json['tenant'] as Map<String, dynamic>;
      tName = tName ?? (t['fullName'] ?? t['name'])?.toString();
      tPhone = tPhone ?? t['phone']?.toString();
    }

    return ManagedProperty(
      id: propId,
      name: propName.isNotEmpty ? propName : 'Yönetilen Mülk #$propId',
      address: propAddress,
      city: propCity,
      landlordName: lName,
      landlordEmail: lEmail,
      landlordPhone: lPhone,
      activeLeasesCount: leasesCount,
      statusSummary: json['statusSummary']?.toString() ?? json['contractStatus']?.toString(),
      tenantName: tName,
      tenantPhone: tPhone,
      daskEndDate: parseDate(json['daskEndDate']),
      depositAmount: parseAmount(json['depositAmount'] ?? json['deposit']),
      delegationId: json['delegationId'] != null ? parseId(json['delegationId']) : null,
      delegationStatus: json['delegationStatus']?.toString() ?? json['status']?.toString(),
      referenceCode: json['referenceCode']?.toString(),
    );
  }

  factory ManagedProperty.fromProperty(
    Property property, {
    String? landlordName,
    String? landlordEmail,
    String? landlordPhone,
    int? activeLeasesCount,
    String? statusSummary,
  }) {
    return ManagedProperty(
      id: property.id,
      name: property.name,
      address: property.address,
      landlordName: landlordName,
      landlordEmail: landlordEmail,
      landlordPhone: landlordPhone,
      activeLeasesCount: activeLeasesCount ?? (property.isOccupied ? 1 : 0),
      statusSummary: statusSummary,
      tenantName: property.tenantName,
      tenantPhone: property.tenantPhone,
      daskEndDate: property.daskEndDate,
      depositAmount: property.depositAmount,
    );
  }

  factory ManagedProperty.fromDelegation(PropertyDelegation delegation) {
    return ManagedProperty(
      id: delegation.propertyId,
      name: delegation.propertyTitle.isNotEmpty ? delegation.propertyTitle : 'Yönetilen Mülk #${delegation.propertyId}',
      address: delegation.propertyAddress ?? '',
      city: delegation.propertyCity,
      landlordName: delegation.grantedByName,
      landlordEmail: delegation.grantedByEmail,
      activeLeasesCount: delegation.isActive ? 1 : 0,
      statusSummary: delegation.isActive ? '1 aktif sözleşme' : 'Yetki Beklemede',
      delegationId: delegation.id,
      delegationStatus: delegation.status,
      referenceCode: delegation.referenceCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'city': city,
    'landlordName': landlordName,
    'landlordEmail': landlordEmail,
    'landlordPhone': landlordPhone,
    'activeLeasesCount': activeLeasesCount,
    'statusSummary': statusSummary,
    'tenantName': tenantName,
    'tenantPhone': tenantPhone,
    'daskEndDate': daskEndDate?.toIso8601String(),
    'depositAmount': depositAmount,
    'delegationId': delegationId,
    'delegationStatus': delegationStatus,
    'referenceCode': referenceCode,
  };
}
