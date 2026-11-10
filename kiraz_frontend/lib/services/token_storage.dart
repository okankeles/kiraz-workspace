import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _userFullNameKey = 'user_fullname';
  static const String _userEmailKey = 'user_email';

  final FlutterSecureStorage _storage;
  // Güvenlik anahtarlığına erişilemediği durumlarda (örn. imzasız macOS build, -34018)
  // oturumun çökmeden bellek üzerinde sürdürülmesi için fallback saklayıcı.
  final Map<String, String> _memoryFallback = <String, String>{};

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
                useDataProtectionKeyChain: true,
              ),
            );

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      _memoryFallback[key] = value;
    } on PlatformException catch (e) {
      debugPrint('TokenStorage PlatformException [_write $key]: [Code: ${e.code}] ${e.message}');
      _memoryFallback[key] = value;
    } catch (e, stack) {
      debugPrint('TokenStorage write error [$key]: $e\n$stack');
      _memoryFallback[key] = value;
    }
  }

  Future<String?> _read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        _memoryFallback[key] = value;
        return value;
      }
      return _memoryFallback[key];
    } on PlatformException catch (e) {
      debugPrint('TokenStorage PlatformException [_read $key]: [Code: ${e.code}] ${e.message}');
      return _memoryFallback[key];
    } catch (e, stack) {
      debugPrint('TokenStorage read error [$key]: $e\n$stack');
      return _memoryFallback[key];
    }
  }

  Future<void> _delete(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (e) {
      debugPrint('TokenStorage PlatformException [_delete $key]: [Code: ${e.code}] ${e.message}');
    } catch (e, stack) {
      debugPrint('TokenStorage delete error [$key]: $e\n$stack');
    }
  }

  Future<void> _deleteAll() async {
    _memoryFallback.clear();
    try {
      await _storage.deleteAll();
    } on PlatformException catch (e) {
      debugPrint('TokenStorage PlatformException [_deleteAll]: [Code: ${e.code}] ${e.message}');
    } catch (e, stack) {
      debugPrint('TokenStorage deleteAll error: $e\n$stack');
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _write(_accessTokenKey, accessToken);
    await _write(_refreshTokenKey, refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _write(_accessTokenKey, accessToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _write(_refreshTokenKey, refreshToken);
  }

  Future<void> saveUserData({
    required int id,
    required String role,
    required String fullName,
    required String email,
  }) async {
    await _write(_userIdKey, id.toString());
    await _write(_userRoleKey, role);
    await _write(_userFullNameKey, fullName);
    await _write(_userEmailKey, email);
  }

  Future<String?> getAccessToken() async {
    return await _read(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }

  Future<int?> getUserId() async {
    final val = await _read(_userIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  Future<String?> getUserRole() async {
    return await _read(_userRoleKey);
  }

  Future<String?> getUserFullName() async {
    return await _read(_userFullNameKey);
  }

  Future<String?> getUserEmail() async {
    return await _read(_userEmailKey);
  }

  Future<void> clearTokens() async {
    await _delete(_accessTokenKey);
    await _delete(_refreshTokenKey);
    await _delete(_userIdKey);
    await _delete(_userRoleKey);
    await _delete(_userFullNameKey);
    await _delete(_userEmailKey);
  }

  Future<void> clearAll() async {
    await _deleteAll();
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }
}
