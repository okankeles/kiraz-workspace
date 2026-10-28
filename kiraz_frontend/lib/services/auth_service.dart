import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../utils/constants.dart';

class AuthService {
  Future<AuthResponse?> register(Map<String, dynamic> userData) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/auth/register');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return AuthResponse.fromJson(data);
      } else {
        String errorMessage = 'Kayıt başarısız (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: Network error')) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/auth/login');

    final http.Response response;
    try {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
    } catch (e) {
      throw Exception('Ağ hatası: $e');
    }

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final authResponse = AuthResponse.fromJson(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', authResponse.id);
      await prefs.setString('role', authResponse.role);
      await prefs.setString('fullName', authResponse.fullName);

      return authResponse;
    } else {
      String errorMessage = 'Giriş başarısız (${response.statusCode})';
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}
