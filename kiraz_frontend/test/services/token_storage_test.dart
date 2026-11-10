import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiraz_frontend/services/token_storage.dart';

class FailingSecureStorage extends FlutterSecureStorage {
  const FailingSecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: "A required entitlement isn't present.",
    );
  }
}

class WorkingMockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _db = <String, String>{};

  WorkingMockSecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _db[key] = value;
    } else {
      _db.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _db[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _db.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _db.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenStorage Tests', () {
    test('1. Normal depolama durumunda token ve profil bilgileri başarıyla saklanır ve okunur', () async {
      final storage = TokenStorage(storage: WorkingMockSecureStorage());

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.hasRefreshToken(), isFalse);

      await storage.saveTokens(
        accessToken: 'mock-access-token-123',
        refreshToken: 'mock-refresh-token-456',
      );
      await storage.saveUserData(
        id: 42,
        role: 'LANDLORD',
        fullName: 'Ahmet Yılmaz',
        email: 'ahmet@example.com',
      );

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.hasRefreshToken(), isTrue);
      expect(await storage.getAccessToken(), 'mock-access-token-123');
      expect(await storage.getRefreshToken(), 'mock-refresh-token-456');
      expect(await storage.getUserId(), 42);
      expect(await storage.getUserRole(), 'LANDLORD');
      expect(await storage.getUserFullName(), 'Ahmet Yılmaz');
      expect(await storage.getUserEmail(), 'ahmet@example.com');

      await storage.clearTokens();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.hasRefreshToken(), isFalse);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getUserRole(), isNull);
    });

    test('2. macOS -34018 PlatformException fırlatıldığında TokenStorage çökmez ve bellek içi fallback çalışır', () async {
      final storage = TokenStorage(storage: const FailingSecureStorage());

      // Write çağrısı PlatformException fırlatmamalı
      await expectLater(
        () => storage.saveTokens(
          accessToken: 'mac-access-token-abc',
          refreshToken: 'mac-refresh-token-xyz',
        ),
        returnsNormally,
      );

      await expectLater(
        () => storage.saveUserData(
          id: 7,
          role: 'TENANT',
          fullName: 'Ayşe Demir',
          email: 'ayse@example.com',
        ),
        returnsNormally,
      );

      // Read çağrıları exception fırlatmadan bellekteki değeri döndürmeli
      expect(await storage.getAccessToken(), 'mac-access-token-abc');
      expect(await storage.getRefreshToken(), 'mac-refresh-token-xyz');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.hasRefreshToken(), isTrue);
      expect(await storage.getUserId(), 7);
      expect(await storage.getUserRole(), 'TENANT');
      expect(await storage.getUserFullName(), 'Ayşe Demir');

      // Clear çağrısı da PlatformException fırlatmamalı ve belleği temizlemeli
      await expectLater(
        () => storage.clearTokens(),
        returnsNormally,
      );

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.hasRefreshToken(), isFalse);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });
  });
}
