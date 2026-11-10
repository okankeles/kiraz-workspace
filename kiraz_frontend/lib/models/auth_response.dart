class AuthUser {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String referenceCode;

  AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.referenceCode = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    return AuthUser(
      id: parseId(json['id']),
      fullName: (json['fullName'] ?? json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      referenceCode: (json['referenceCode'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role,
    'referenceCode': referenceCode,
  };
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn = 900,
    required this.user,
  });

  // Geriye dönük uyumluluk için getter'lar
  int get id => user.id;
  String get fullName => user.fullName;
  String get email => user.email;
  String get role => user.role;
  String get referenceCode => user.referenceCode;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    int parseExpiresIn(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString()) ?? 900;
      return 900;
    }

    final token = (json['accessToken'] ?? json['token'] ?? '').toString();
    final refresh = (json['refreshToken'] ?? '').toString();
    final exp = parseExpiresIn(json['expiresIn']);

    AuthUser parsedUser;
    if (json['user'] is Map<String, dynamic>) {
      parsedUser = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    } else {
      parsedUser = AuthUser.fromJson(json);
    }

    return AuthResponse(
      accessToken: token,
      refreshToken: refresh,
      expiresIn: exp,
      user: parsedUser,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'user': user.toJson(),
  };
}
