class RegenerateInviteResponse {
  final int leaseId;
  final String inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final String message;

  RegenerateInviteResponse({
    required this.leaseId,
    required this.inviteCode,
    this.inviteCodeExpiresAt,
    required this.message,
  });

  factory RegenerateInviteResponse.fromJson(Map<String, dynamic> json) {
    DateTime? parsedExpiry;
    if (json['inviteCodeExpiresAt'] != null) {
      try {
        parsedExpiry = DateTime.parse(json['inviteCodeExpiresAt'].toString());
      } catch (_) {}
    }

    return RegenerateInviteResponse(
      leaseId: json['leaseId'] is int
          ? json['leaseId'] as int
          : int.tryParse(json['leaseId'].toString()) ?? 0,
      inviteCode: (json['inviteCode'] ?? '').toString(),
      inviteCodeExpiresAt: parsedExpiry,
      message: (json['message'] ?? 'Yeni davet kodu başarıyla oluşturuldu.').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leaseId': leaseId,
      'inviteCode': inviteCode,
      'inviteCodeExpiresAt': inviteCodeExpiresAt?.toIso8601String(),
      'message': message,
    };
  }
}
