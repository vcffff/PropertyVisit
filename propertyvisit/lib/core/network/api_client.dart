import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One client per app. Never log requests: authentication bodies contain secrets.
class ApiClient {
  ApiClient({
    Future<String?> Function()? accessTokenProvider,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    String? baseUrl,
    Dio? transport,
    Dio? authTransport,
    // Public names keep existing dependency injection call sites compatible.
    // ignore: prefer_initializing_formals
  }) : _storage = storage,
       // ignore: prefer_initializing_formals
       _accessTokenProvider = accessTokenProvider {
    final url =
        (baseUrl ??
                const String.fromEnvironment(
                  'API_URL',
                  defaultValue: 'http://10.0.2.2:8080/api/v1',
                ))
            .replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw ArgumentError(
        'API_URL must be an absolute http(s) URL including /api/v1',
      );
    }
    BaseOptions options() => BaseOptions(
      baseUrl: url,
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    );
    dio = transport ?? Dio();
    dio.options = options();
    authDio = authTransport ?? Dio();
    authDio.options = options();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          try {
            final version = _version;
            final token = _accessTokenProvider != null
                ? await _accessTokenProvider()
                : (await tokens())?.access;
            if (version != _version) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  error: 'Session changed before request',
                ),
              );
              return;
            }
            request.extra['sessionVersion'] ??= _version;
            if (token != null) {
              request.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(request);
          } catch (_) {
            handler.reject(
              DioException(
                requestOptions: request,
                error: 'Не удалось прочитать защищённое хранилище.',
              ),
            );
          }
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              request.extra['retried'] == true) {
            if (error.response?.statusCode == 401 &&
                request.extra['retried'] == true &&
                request.extra['sessionVersion'] == _version) {
              try {
                await clearSession();
              } catch (_) {
                /* Still resolve the request. */
              }
            }
            handler.next(error);
            return;
          }
          try {
            if (request.extra['sessionVersion'] != _version) {
              handler.next(error);
              return;
            }
            final current = await tokens();
            if (current == null) {
              await clearSession();
              handler.next(error);
              return;
            }
            // A delayed 401 can refer to a token another request already rotated.
            if (request.headers['Authorization'] ==
                'Bearer ${current.access}') {
              await refresh();
            }
            if (request.extra['sessionVersion'] != _version) {
              handler.next(error);
              return;
            }
            request.extra['retried'] = true;
            handler.resolve(await dio.fetch<dynamic>(request));
          } on DioException catch (e) {
            handler.reject(e);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  static const sessionKey = 'pv_api_session_v1';
  final FlutterSecureStorage _storage;
  final Future<String?> Function()? _accessTokenProvider;
  late final Dio dio;
  late final Dio authDio; // Auth routes cannot enter the refresh interceptor.
  final _expired = StreamController<void>.broadcast(sync: true);
  Stream<void> get sessionExpired => _expired.stream;
  Future<void>? _refreshing;
  Future<void> _writes = Future.value();
  int _version = 0;

  Future<TokenPair?> tokens() async {
    await _writes;
    final raw = await _storage.read(key: sessionKey);
    if (raw == null) return null;
    try {
      return TokenPair.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> _write(TokenPair? pair) {
    final operation = _writes
        .catchError((Object _) {})
        .then(
          (_) => pair == null
              ? _storage.delete(key: sessionKey)
              : _storage.write(
                  key: sessionKey,
                  value: jsonEncode(pair.toJson()),
                ),
        );
    _writes = operation;
    return operation;
  }

  Future<void> startSession(Map<String, dynamic> json) async {
    final pair = TokenPair.fromJson(json);
    _version++;
    _refreshing = null;
    await _write(pair);
  }

  Future<void> clearSession() async {
    _version++;
    try {
      await _write(null);
    } finally {
      _expired.add(null);
    }
  }

  Future<void> refresh() {
    final existing = _refreshing;
    if (existing != null) return existing;
    late final Future<void> request;
    request = _rotate().whenComplete(() {
      if (identical(_refreshing, request)) _refreshing = null;
    });
    return _refreshing = request;
  }

  Future<void> _rotate() async {
    final version = _version;
    final pair = await tokens();
    if (pair == null) throw StateError('No refresh session');
    try {
      final response = await authDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': pair.refresh},
      );
      if (version != _version) throw StateError('Session changed');
      // One secure value prevents a partially stored rotated token pair.
      await _write(
        TokenPair.fromJson(
          response.data ??
              (throw const FormatException('Missing refresh token pair')),
        ),
      );
    } on DioException catch (e) {
      if (version == _version && [400, 401].contains(e.response?.statusCode)) {
        await clearSession();
      }
      rethrow; // Offline/429/5xx must not discard the session.
    } on FormatException {
      if (version == _version) await clearSession();
      rethrow;
    }
  }

  Future<void> logout() async {
    // Revoke the new token if a rotation is already running.
    try {
      await _refreshing;
    } catch (_) {
      /* Still clear the local session. */
    }
    final pair = await tokens();
    await clearSession();
    if (pair != null) {
      await authDio.post<void>(
        '/auth/logout',
        data: {'refresh_token': pair.refresh},
      );
    }
  }
}

class TokenPair {
  const TokenPair(this.access, this.refresh);
  final String access;
  final String refresh;
  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'], refresh = json['refresh_token'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('Invalid token pair');
    }
    return TokenPair(access, refresh);
  }
  Map<String, String> toJson() => {
    'access_token': access,
    'refresh_token': refresh,
  };
}

/// Never stringify DioException: it can include secret request data.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    return switch (error.response?.statusCode) {
      400 => 'Проверьте введённые данные.',
      401 => 'Сессия истекла. Войдите снова.',
      403 => 'Недостаточно прав для этого действия.',
      404 => 'Запись не найдена. Обновите список.',
      409 => 'Данные уже изменились. Обновите список.',
      429 => 'Лимит API: 5 запросов в минуту. Подождите минуту и повторите.',
      int code when code >= 500 =>
        'Сервис временно недоступен. Повторите позже.',
      _ =>
        'Не удалось связаться с сервером. Проверьте подключение и повторите.',
    };
  }
  return 'Не удалось обработать данные. Повторите попытку.';
}
