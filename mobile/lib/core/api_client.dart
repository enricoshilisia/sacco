import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import 'client_context.dart';
import '../models/sacco.dart';
import 'secure_store.dart';

class ApiException implements Exception {
  final int? status;
  final String message;
  ApiException(this.status, this.message);

  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

/// Pulls a human-readable message out of a DRF error body: {"detail": ...},
/// {"non_field_errors": [...]}, or {"field": ["..."]}.
String _extractMessage(Object? data) {
  if (data is Map) {
    if (data['detail'] is String) return data['detail'] as String;
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        final text = value.first.toString();
        return entry.key == 'non_field_errors' ? text : '${entry.key}: $text';
      }
      if (value is String) return value;
    }
  }
  if (data is List && data.isNotEmpty) return data.first.toString();
  return '';
}

ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final response = error.response;
    if (response == null) {
      return ApiException(null, 'network');
    }
    return ApiException(response.statusCode, _extractMessage(response.data));
  }
  return ApiException(null, error.toString());
}

/// Talks to ONE SACCO's API. Tenants are routed by Host header
/// (django-tenants), so the base URL is that SACCO's own domain - or, with
/// TENANT_CONNECT_OVERRIDE, a fixed origin plus an explicit Host header.
class ApiClient {
  final Sacco sacco;
  final SecureStore store;
  final void Function() onSessionExpired;
  late final Dio dio;

  Completer<bool>? _refreshing;

  ApiClient({required this.sacco, required this.store, required this.onSessionExpired}) {
    final override = AppConfig.tenantConnectOverride;
    final port = AppConfig.tenantPort.isEmpty ? '' : ':${AppConfig.tenantPort}';
    dio = Dio(
      BaseOptions(
        baseUrl: override.isNotEmpty ? override : '${AppConfig.tenantScheme}://${sacco.domain}$port',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          if (override.isNotEmpty) 'Host': sacco.domain,
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Device and (if allowed) location, for the SACCO's audit log.
          options.headers.addAll(ClientContext.instance.headers);
          if (options.extra['auth'] != false) {
            final token = await store.readAccess();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          final isAuthFailure = error.response?.statusCode == 401;
          if (!isAuthFailure || options.extra['auth'] == false || options.extra['retried'] == true) {
            return handler.next(error);
          }
          if (await _refreshTokens()) {
            options.extra['retried'] = true;
            options.headers['Authorization'] = 'Bearer ${await store.readAccess()}';
            try {
              return handler.resolve(await dio.fetch(options));
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
          onSessionExpired();
          handler.next(error);
        },
      ),
    );
  }

  /// One refresh at a time. The backend rotates refresh tokens and
  /// blacklists the old one (SIMPLE_JWT ROTATE/BLACKLIST_AFTER_ROTATION),
  /// so two concurrent refreshes with the same token would make the second
  /// one fail and log the member out for no reason.
  Future<bool> _refreshTokens() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = _refreshing = Completer<bool>();
    try {
      final refresh = await store.readRefresh();
      if (refresh == null) {
        completer.complete(false);
      } else {
        final response = await dio.post(
          '/api/auth/token/refresh/',
          data: {'refresh': refresh},
          options: Options(extra: {'auth': false}),
        );
        final data = response.data as Map<String, dynamic>;
        await store.writeTokens(data['access'] as String, (data['refresh'] as String?) ?? refresh);
        completer.complete(true);
      }
    } catch (_) {
      completer.complete(false);
    } finally {
      _refreshing = null;
    }
    return completer.future;
  }

  Future<bool> refreshNow() => _refreshTokens();

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _wrap(() => dio.get(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data, bool auth = true}) =>
      _wrap(() => dio.post(path, data: data, options: Options(extra: {'auth': auth})));

  Future<T> patch<T>(String path, {Object? data}) => _wrap(() => dio.patch(path, data: data));

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } catch (error) {
      throw toApiException(error);
    }
  }
}
