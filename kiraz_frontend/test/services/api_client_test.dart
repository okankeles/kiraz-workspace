import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiraz_frontend/services/api_client.dart';
import 'package:kiraz_frontend/services/token_storage.dart';

class InMemoryTokenStorage extends TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  InMemoryTokenStorage({String? initialAccessToken, String? initialRefreshToken})
      : _accessToken = initialAccessToken,
        _refreshToken = initialRefreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<bool> hasAccessToken() async =>
      _accessToken != null && _accessToken!.isNotEmpty;
}

void main() {
  const baseUrl = 'http://localhost:8080/api';

  group('ApiClient Unit Tests', () {
    test('1. Başarılı istekte Authorization Bearer başlığı gönderilir', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'initial-access-token-123',
        initialRefreshToken: 'initial-refresh-token-123',
      );

      String? capturedAuthHeader;

      final mockHttpClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(json.encode({'status': 'ok'}), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final uri = apiClient.resolveUri('/landlord/properties');
      final response = await apiClient.get(uri);

      expect(response.statusCode, 200);
      expect(capturedAuthHeader, 'Bearer initial-access-token-123');
    });

    test('2. 401 durumunda başarılı refresh: token yenilenir ve istek tekrarlanır', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'expired-access-token',
        initialRefreshToken: 'valid-refresh-token',
      );

      int requestCount = 0;
      int refreshCallCount = 0;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCallCount++;
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['refreshToken'], 'valid-refresh-token');

          return http.Response(
            json.encode({
              'accessToken': 'new-access-token-789',
              'refreshToken': 'new-refresh-token-789',
              'expiresIn': 900,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        requestCount++;
        final authHeader = request.headers['Authorization'];

        if (requestCount == 1) {
          // İlk istek: süresi dolmuş token ile 401 döner
          expect(authHeader, 'Bearer expired-access-token');
          return http.Response(
            json.encode({'status': 401, 'message': 'Token expired'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        } else {
          // İkinci istek (retry): yeni token ile başarılı 200 döner
          expect(authHeader, 'Bearer new-access-token-789');
          return http.Response(
            json.encode({'properties': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final uri = apiClient.resolveUri('/landlord/properties');
      final response = await apiClient.get(uri);

      expect(response.statusCode, 200);
      expect(refreshCallCount, 1);
      expect(requestCount, 2);
      expect(await tokenStorage.getAccessToken(), 'new-access-token-789');
      expect(await tokenStorage.getRefreshToken(), 'new-refresh-token-789');
    });

    test('3. 401 durumunda başarısız refresh: oturum kapatılır ve hata fırlatılır', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'expired-access-token',
        initialRefreshToken: 'revoked-refresh-token',
      );

      bool sessionExpiredCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            json.encode({'status': 401, 'message': 'Refresh token expired or invalid'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          json.encode({'status': 401, 'message': 'Unauthorized'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
        onSessionExpired: () {
          sessionExpiredCalled = true;
        },
      );

      final uri = apiClient.resolveUri('/landlord/properties');

      await expectLater(
        () => apiClient.get(uri),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      // Oturum sonlandırıldı ve secure storage temizlendi
      expect(sessionExpiredCalled, isTrue);
      expect(await tokenStorage.getAccessToken(), isNull);
      expect(await tokenStorage.getRefreshToken(), isNull);
    });

    test('4. Eşzamanlı 401 istekleri: TEK BİR refresh çağrısı yapılır (mutex/single-flight)', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'stale-token',
        initialRefreshToken: 'active-refresh-token',
      );

      int refreshCallCount = 0;
      int endpointCallCount = 0;

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCallCount++;
          // Ağ gecikmesini simüle etmek için kısa bir gecikme
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response(
            json.encode({
              'accessToken': 'fresh-rotated-access-token',
              'refreshToken': 'fresh-rotated-refresh-token',
              'expiresIn': 900,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        endpointCallCount++;
        final authHeader = request.headers['Authorization'];

        if (authHeader == 'Bearer stale-token') {
          return http.Response(
            json.encode({'status': 401, 'message': 'Token expired'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        } else if (authHeader == 'Bearer fresh-rotated-access-token') {
          return http.Response(
            json.encode({'status': 'success', 'data': request.url.path}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Forbidden', 403);
      });

      final apiClient = ApiClient(
        httpClient: mockHttpClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      // Aynı anda 3 farklı istek başlat
      final uri1 = apiClient.resolveUri('/landlord/properties');
      final uri2 = apiClient.resolveUri('/landlord/dashboard');
      final uri3 = apiClient.resolveUri('/landlord/leases');

      final results = await Future.wait([
        apiClient.get(uri1),
        apiClient.get(uri2),
        apiClient.get(uri3),
      ]);

      // Tümü başarıyla 200 dönmeli
      for (final res in results) {
        expect(res.statusCode, 200);
      }

      // En kritik kural: 3 adet 401 isteğine karşılık yalnızca 1 kez refresh çağrısı yapılmış olmalı!
      expect(refreshCallCount, 1);
      // Toplam istek sayısı: 3 ilk istek (401) + 3 retry isteği (200) = 6 istek
      expect(endpointCallCount, 6);
      expect(await tokenStorage.getAccessToken(), 'fresh-rotated-access-token');
      expect(await tokenStorage.getRefreshToken(), 'fresh-rotated-refresh-token');
    });
  });
}
