import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiraz_frontend/services/api_client.dart';
import 'package:kiraz_frontend/services/lease_service.dart';
import 'package:kiraz_frontend/services/token_storage.dart';

class MockTokenStorage extends TokenStorage {
  String? _token = 'test-token-xyz';

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

  group('LeaseService - Regenerate Invite Code & Contract Upload Tests', () {
    test('1. regenerateInviteCode: Başarılı yenileme durumunda 200 döner ve yeni kod/son kullanma parse edilir', () async {
      final tokenStorage = MockTokenStorage();

      String? capturedPath;
      String? capturedMethod;
      String? capturedAuth;

      final mockClient = MockClient((request) async {
        capturedPath = request.url.path;
        capturedMethod = request.method;
        capturedAuth = request.headers['Authorization'];

        final responseBody = {
          'leaseId': 42,
          'inviteCode': 'ARS-1234567890ABCDEF1234567890ABCDEF',
          'inviteCodeExpiresAt': '2026-11-17T05:00:00',
          'message': 'Yeni davet kodu başarıyla oluşturuldu.',
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

      final leaseService = LeaseService(apiClient: apiClient);
      final result = await leaseService.regenerateInviteCode(42);

      expect(capturedPath, '/api/landlord/leases/42/regenerate-invite');
      expect(capturedMethod, 'POST');
      expect(capturedAuth, 'Bearer test-token-xyz');
      expect(result.leaseId, 42);
      expect(result.inviteCode, 'ARS-1234567890ABCDEF1234567890ABCDEF');
      expect(result.inviteCodeExpiresAt, isNotNull);
      expect(result.inviteCodeExpiresAt!.year, 2026);
      expect(result.inviteCodeExpiresAt!.month, 11);
      expect(result.inviteCodeExpiresAt!.day, 17);
      expect(result.message, 'Yeni davet kodu başarıyla oluşturuldu.');
    });

    test('2. regenerateInviteCode: Kiracı zaten bağlanmışsa 409 Conflict döner ve uygun mesaj fırlatılır', () async {
      final tokenStorage = MockTokenStorage();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'status': 409,
            'error': 'Conflict',
            'message': 'Davet kodu zaten kabul edilmiş bir sözleşme için yeni kod üretilemez.',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        baseUrl: baseUrl,
      );

      final leaseService = LeaseService(apiClient: apiClient);

      expect(
        () => leaseService.regenerateInviteCode(42),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          409,
        )),
      );
    });

    test('3. regenerateInviteCode: Sözleşme bulunamazsa 404 Not Found fırlatılır', () async {
      final tokenStorage = MockTokenStorage();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'status': 404,
            'error': 'Not Found',
            'message': 'Sözleşme bulunamadı: 999',
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

      final leaseService = LeaseService(apiClient: apiClient);

      expect(
        () => leaseService.regenerateInviteCode(999),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        )),
      );
    });

    test('4. uploadContract: Sözleşme belgesi POST /api/leases/{id}/contract ucuna gönderilir', () async {
      final tokenStorage = MockTokenStorage();

      String? capturedPath;
      String? capturedMethod;

      // Create a temporary mock file for testing upload
      final tempDir = await Directory.systemTemp.createTemp('lease_test');
      final tempFile = File('${tempDir.path}/contract.pdf');
      await tempFile.writeAsBytes(utf8.encode('%PDF-1.4 test contract content'));

      try {
        final apiClient = ApiClient(
          httpClient: MockClient((req) async {
            capturedPath = req.url.path;
            capturedMethod = req.method;
            return http.Response(json.encode({'id': 10}), 200, headers: {'content-type': 'application/json'});
          }),
          tokenStorage: tokenStorage,
          baseUrl: baseUrl,
        );

        final leaseService = LeaseService(apiClient: apiClient);
        await leaseService.uploadContract(10, tempFile);

        expect(capturedPath, '/api/leases/10/contract');
        expect(capturedMethod, 'POST');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
