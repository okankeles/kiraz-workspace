import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response.dart';
import '../utils/constants.dart';
import 'token_storage.dart';

class AuthService {
  final TokenStorage _tokenStorage;
  final http.Client _httpClient;

  AuthService({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _httpClient = httpClient ?? http.Client();

  Future<void> _persistSession(AuthResponse authResponse) async {
    // 1. JWT Tokens ve kullanıcı profil bilgileri FlutterSecureStorage'a
    if (authResponse.accessToken.isNotEmpty) {
      await _tokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );
    }
    await _tokenStorage.saveUserData(
      id: authResponse.user.id,
      role: authResponse.user.role,
      fullName: authResponse.user.fullName,
      email: authResponse.user.email,
    );

    // 2. Kullanıcı profil bilgileri SharedPreferences'a (ekranlar ve senkron erişim için)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', authResponse.user.id);
    await prefs.setString('role', authResponse.user.role);
    await prefs.setString('fullName', authResponse.user.fullName);
    await prefs.setString('email', authResponse.user.email);
    if (authResponse.referenceCode.isNotEmpty) {
      await prefs.setString('referenceCode', authResponse.referenceCode);
    }
  }

  Future<AuthResponse> register(Map<String, dynamic> userData) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/auth/register');

    try {
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        final authResponse = AuthResponse.fromJson(data as Map<String, dynamic>);
        await _persistSession(authResponse);
        return authResponse;
      } else {
        String errorMessage = 'Kayıt başarısız (${response.statusCode})';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData is Map && errorData.containsKey('message') && errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception && !e.toString().startsWith('Exception: Network error')) {
        rethrow;
      }
      throw Exception('Ağ hatası: $e');
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/auth/login');

    final http.Response response;
    try {
      response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email.trim(),
          'password': password,
        }),
      );
    } catch (e) {
      throw Exception('Ağ hatası: $e');
    }

    if (response.statusCode == 200) {
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      final authResponse = AuthResponse.fromJson(data as Map<String, dynamic>);
      await _persistSession(authResponse);
      return authResponse;
    } else {
      String errorMessage = 'E-posta veya şifre hatalı.';
      try {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData.containsKey('message') && errorData['message'] != null) {
          errorMessage = errorData['message'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final url = Uri.parse('${ApiConstants.baseUrl}/auth/logout');
        await _httpClient.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode({'refreshToken': refreshToken}),
        ).catchError((_) => http.Response('{}', 200));
      }
    } catch (_) {}

    // Clear secure storage and shared preferences
    try {
      await _tokenStorage.clearTokens();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('role');
      await prefs.remove('fullName');
      await prefs.remove('email');
      await prefs.remove('token');
      await prefs.remove('referenceCode');
      await prefs.remove('isLoggedIn');
    } catch (_) {}
  }

  static const String legacyMigrationKey = 'jwt_legacy_migration_v1_done';

  /// JWT öncesinden kalan legacy shared_preferences oturum verilerini ilk açılışta bir kez temizler.
  static Future<void> migrateLegacySession({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final isDone = p.getBool(legacyMigrationKey) ?? false;
      if (!isDone) {
        final legacyKeys = [
          'userId',
          'role',
          'isLoggedIn',
          'email',
          'fullName',
          'token',
          'referenceCode',
          'tenantName',
          'userRole',
          'userName',
        ];
        for (final key in legacyKeys) {
          await p.remove(key);
        }
        await p.setBool(legacyMigrationKey, true);
      }
    } catch (_) {}
  }
}
