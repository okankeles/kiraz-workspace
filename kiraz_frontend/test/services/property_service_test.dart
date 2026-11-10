import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiraz_frontend/services/api_client.dart';
import 'package:kiraz_frontend/services/property_service.dart';
import 'package:kiraz_frontend/services/token_storage.dart';

class MockTokenStorage extends TokenStorage {
  String? _token = 'landlord-token-123';

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  Future<String?> getRefreshToken() async => 'refresh-token-xyz';

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _token = accessToken;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async {
    _token = accessToken;
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}

  @override
  Future<void> clearTokens() async {
    _token = null;
  }

  @override
  Future<bool> hasAccessToken() async => _token != null;
}

void main() {
  const baseUrl = 'http://localhost:8080/api';

  group('PropertyService - updateProperty Tests', () {
    test('1. updateProperty: Başarılı istekte PUT /api/properties/{id} çağrılır, gövde doğru gönderilir ve güncellenmiş mülk döner', () async {
      final tokenStorage = MockTokenStorage();

      String? capturedPath;
      String? capturedMethod;
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedPath = request.url.path;
        capturedMethod = request.method;
        capturedAuth = request.headers['Authorization'];
        capturedBody = json.decode(request.body) as Map<String, dynamic>;

        final responseBody = {
          'id': 15,
          'title': 'Kadıköy 2+1 Lüks Daire',
          'name': 'Kadıköy 2+1 Lüks Daire',
          'address': 'Moda Cad. No:12',
          'city': 'İstanbul',
          'daskEndDate': '2027-05-15',
          'depositAmount': 30000.0,
          'status': 'EMPTY',
        };

        return http.Response(
          json.encode(responseBody),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final propertyService = PropertyService(apiClient: apiClient);

      final result = await propertyService.updateProperty(
        15,
        'Kadıköy 2+1 Lüks Daire',
        'Moda Cad. No:12',
        'İstanbul',
        daskEndDate: '2027-05-15',
        depositAmount: 30000.0,
      );

      expect(capturedPath, '/api/properties/15');
      expect(capturedMethod, 'PUT');
      expect(capturedAuth, 'Bearer landlord-token-123');
      expect(capturedBody!['title'], 'Kadıköy 2+1 Lüks Daire');
      expect(capturedBody!['address'], 'Moda Cad. No:12');
      expect(capturedBody!['city'], 'İstanbul');
      expect(capturedBody!['daskEndDate'], '2027-05-15');
      expect(capturedBody!['depositAmount'], 30000.0);
      expect(capturedBody!.containsKey('landlordId'), isFalse); // landlordId gönderilmemeli

      expect(result.id, 15);
      expect(result.name, 'Kadıköy 2+1 Lüks Daire');
      expect(result.address, 'Moda Cad. No:12');
      expect(result.city, 'İstanbul');
      expect(result.depositAmount, 30000.0);
    });

    test('2. updateProperty: Kullanıcı ev sahibi değilse 403 hatası yakalanır ve açıklayıcı hata mesajı döner', () async {
      final tokenStorage = MockTokenStorage();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'status': 403,
            'error': 'Forbidden',
            'message': 'Access Denied',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final propertyService = PropertyService(apiClient: apiClient);

      expect(
        () => propertyService.updateProperty(15, 'Yeni Başlık', 'Adres', 'Ankara'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', contains('Bu mülkü düzenleme yetkiniz yok'))),
      );
    });

    test('3. updateProperty: Mülk yoksa veya başkasına aitse 404 hatası döner', () async {
      final tokenStorage = MockTokenStorage();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'status': 404,
            'error': 'Not Found',
            'message': 'Mülk bulunamadı',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final propertyService = PropertyService(apiClient: apiClient);

      expect(
        () => propertyService.updateProperty(999, 'Yeni Başlık', 'Adres', 'İzmir'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', contains('Mülk bulunamadı veya başka bir ev sahibine ait'))),
      );
    });

    test('4. updateProperty: Başlık boşsa 400 hatası döner', () async {
      final tokenStorage = MockTokenStorage();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'status': 400,
            'error': 'Bad Request',
            'message': 'Mülk başlığı (title) zorunludur.',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final propertyService = PropertyService(apiClient: apiClient);

      expect(
        () => propertyService.updateProperty(15, '', 'Adres', 'Bursa'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });
}
