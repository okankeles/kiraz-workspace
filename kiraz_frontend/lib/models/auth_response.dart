class AuthResponse {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String referenceCode;

  AuthResponse({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.referenceCode,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'],
      referenceCode: json['referenceCode'] ?? '',
    );
  }
}
