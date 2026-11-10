import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiraz_frontend/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Migration Tests', () {
    test('migrateLegacySession: JWT öncesi legacy anahtarlarını temizler ve bayrağı kaydeder', () async {
      SharedPreferences.setMockInitialValues({
        'userId': 4,
        'role': 'TENANT',
        'isLoggedIn': true,
        'email': 'legacy.tenant@example.com',
        'fullName': 'demo kiracı 4',
        'token': 'legacy-raw-token',
        'referenceCode': 'REF123',
        'isFirstLaunch': false,
      });

      final prefs = await SharedPreferences.getInstance();

      // Göçten önce eski değerler var
      expect(prefs.getInt('userId'), 4);
      expect(prefs.getString('role'), 'TENANT');
      expect(prefs.getString('fullName'), 'demo kiracı 4');
      expect(prefs.getBool(AuthService.legacyMigrationKey), isNull);

      // Göçü çalıştır
      await AuthService.migrateLegacySession(prefs: prefs);

      // Göçten sonra legacy anahtarlar silinmeli
      expect(prefs.getInt('userId'), isNull);
      expect(prefs.getString('role'), isNull);
      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('email'), isNull);
      expect(prefs.getString('fullName'), isNull);
      expect(prefs.getString('token'), isNull);
      expect(prefs.getString('referenceCode'), isNull);

      // Diğer ayarlar ve göç bayrağı korunmalı
      expect(prefs.getBool('isFirstLaunch'), isFalse);
      expect(prefs.getBool(AuthService.legacyMigrationKey), isTrue);

      // İkinci çağrıda yeni veriler silinmemeli
      await prefs.setString('role', 'LANDLORD');
      await AuthService.migrateLegacySession(prefs: prefs);
      expect(prefs.getString('role'), 'LANDLORD');
    });
  });
}
