import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;

  ApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient();

  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final String _baseUrl;

  /// Oturum süresi dolduğunda ve refresh başarısız olduğunda çağrılacak geri çağırma fonksiyonu.
  void Function()? onSessionExpired;

  // Eşzamanlı 401'ler için tek-uçuş (single-flight) refresh kilidi
  Completer<bool>? _refreshCompleter;

  ApiClient({
    http.Client? httpClient,
    TokenStorage? tokenStorage,
    String? baseUrl,
    this.onSessionExpired,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  // Testler veya özel durumlar için instance'ı güncelleme
  static void setInstance(ApiClient client) {
    _instance = client;
  }

  TokenStorage get tokenStorage => _tokenStorage;
  http.Client get httpClient => _httpClient;
  String get baseUrl => _baseUrl;

  Uri resolveUri(String path, [Map<String, dynamic>? queryParameters]) {
    Uri uri;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      uri = Uri.parse(path);
    } else {
      String cleanPath = path.startsWith('/') ? path : '/$path';
      if (_baseUrl.endsWith('/api') && cleanPath.startsWith('/api/')) {
        cleanPath = cleanPath.substring(4);
      }
      final normalizedBase = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      uri = Uri.parse('$normalizedBase$cleanPath');
    }

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final sanitizedParams = <String, String>{};
      queryParameters.forEach((key, value) {
        if (value != null) {
          sanitizedParams[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: sanitizedParams);
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final accessToken = await _tokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// 401 durumunda tek bir refresh çağrısı yürütür, diğer istekler onu bekler.
  Future<bool> _refreshTokenWithLock() async {
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      final refreshUrl = Uri.parse('$_baseUrl/auth/refresh');
      final response = await _httpClient.post(
        refreshUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(response.bodyBytes));
        final newAccessToken = (data['accessToken'] ?? data['token'] ?? '').toString();
        final newRefreshToken = (data['refreshToken'] ?? '').toString();

        if (newAccessToken.isNotEmpty) {
          await _tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken.isNotEmpty ? newRefreshToken : refreshToken,
          );
          completer.complete(true);
          return true;
        }
      }

      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _handleSessionExpired() async {
    await _tokenStorage.clearTokens();
    onSessionExpired?.call();
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
          return decoded['message'].toString();
        }
        if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
          return decoded['error'].toString();
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'Geçersiz istek gönderildi.';
      case 401:
        return 'Oturum süresi doldu. Lütfen tekrar giriş yapınız.';
      case 403:
      case 404:
        return 'Kayıt bulunamadı veya bu işlem için yetkiniz yok.';
      case 409:
        return 'Ev sahibi onayı bekleniyor veya çakışma oluştu.';
      case 429:
        return 'Çok fazla istek yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
      default:
        if (response.statusCode >= 500) {
          return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
        }
        return 'İşlem başarısız oldu (${response.statusCode}).';
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
        body: response.body,
      );
    }
  }

  Future<http.Response> _executeWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) sendRequest, {
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = await _buildHeaders(extraHeaders: extraHeaders, requiresAuth: requiresAuth);

    http.Response response;
    try {
      response = await sendRequest(headers);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Ağ hatası: Sunucuya ulaşılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
      );
    }

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await _refreshTokenWithLock();
      if (refreshed) {
        final retryHeaders = await _buildHeaders(extraHeaders: extraHeaders, requiresAuth: true);
        try {
          response = await sendRequest(retryHeaders);
        } catch (e) {
          if (e is ApiException) rethrow;
          throw ApiException(
            statusCode: 0,
            message: 'Ağ hatası: İstek tekrarlanamadı.',
          );
        }
      } else {
        await _handleSessionExpired();
        throw ApiException(
          statusCode: 401,
          message: 'Oturum süresi doldu. Lütfen tekrar giriş yapınız.',
        );
      }
    }

    return response;
  }

  // --- HTTP METOTLARI ---

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final response = await _executeWithAuthRetry(
      (h) => _httpClient.get(uri, headers: h),
      extraHeaders: headers,
      requiresAuth: requiresAuth,
    );
    _checkResponse(response);
    return response;
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await _executeWithAuthRetry(
      (h) => _httpClient.post(
        uri,
        headers: h,
        body: body is Map || body is List ? json.encode(body) : body,
      ),
      extraHeaders: headers,
      requiresAuth: requiresAuth,
    );
    _checkResponse(response);
    return response;
  }

  Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await _executeWithAuthRetry(
      (h) => _httpClient.put(
        uri,
        headers: h,
        body: body is Map || body is List ? json.encode(body) : body,
      ),
      extraHeaders: headers,
      requiresAuth: requiresAuth,
    );
    _checkResponse(response);
    return response;
  }

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await _executeWithAuthRetry(
      (h) => _httpClient.delete(
        uri,
        headers: h,
        body: body is Map || body is List ? json.encode(body) : body,
      ),
      extraHeaders: headers,
      requiresAuth: requiresAuth,
    );
    _checkResponse(response);
    return response;
  }

  /// Güvenli dosya indirme (Örn: Dekont ve sözleşme belgeleri).
  /// Doğrudan byte listesi döndürür.
  Future<Uint8List> downloadFile(Uri uri) async {
    final response = await _executeWithAuthRetry(
      (h) {
        final downloadHeaders = Map<String, String>.from(h)..remove('Content-Type');
        return _httpClient.get(uri, headers: downloadHeaders);
      },
      requiresAuth: true,
    );
    _checkResponse(response);
    return response.bodyBytes;
  }

  /// Multipart form-data yüklemesi (401 durumunda retry desteğiyle fabrika deseni kullanır).
  Future<http.Response> sendMultipart(
    Future<http.MultipartRequest> Function() createRequest, {
    bool requiresAuth = true,
  }) async {
    Future<http.Response> sendOne() async {
      final request = await createRequest();
      if (requiresAuth) {
        final token = await _tokenStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      final streamed = await _httpClient.send(request);
      return await http.Response.fromStream(streamed);
    }

    http.Response response;
    try {
      response = await sendOne();
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Dosya yüklenirken ağ hatası oluştu: $e',
      );
    }

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await _refreshTokenWithLock();
      if (refreshed) {
        response = await sendOne();
      } else {
        await _handleSessionExpired();
        throw ApiException(
          statusCode: 401,
          message: 'Oturum süresi doldu. Lütfen tekrar giriş yapınız.',
        );
      }
    }

    _checkResponse(response);
    return response;
  }
}
