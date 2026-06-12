import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../error/exceptions.dart';
import '../utils/logout_stream.dart';
import '../utils/token_storage.dart';
import 'api_constants.dart';

class DioClient {
  DioClient._();

  static Dio create(TokenStorage tokenStorage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _ConnectivityInterceptor(),
      _AuthInterceptor(tokenStorage),
      _ErrorInterceptor(),
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint('[DIO] $o'),
        ),
    ]);

    return dio;
  }
}

// ─── Connectivity Interceptor ─────────────────────────────────────────────────

class _ConnectivityInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const NetworkException(),
            type: DioExceptionType.unknown,
          ),
        );
      }
    } catch (_) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: const NetworkException(),
          type: DioExceptionType.unknown,
        ),
      );
    }
    handler.next(options);
  }
}

// ─── Auth Interceptor ─────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final TokenStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// ─── Error Interceptor ────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Connectivity interceptor already wraps with NetworkException
    if (err.error is NetworkException) {
      return handler.next(err);
    }

    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return handler.reject(_wrap(err, const NetworkException()));

      case DioExceptionType.badResponse:
        final code = err.response?.statusCode;
        final body = err.response?.data;
        final msg = _message(body);

        if (code == 401) {
          triggerForceLogout();
          return handler.reject(_wrap(err, UnauthorizedException(msg)));
        }
        if (code == 422) {
          return handler.reject(
            _wrap(err, ValidationException(msg, errors: _validationErrors(body))),
          );
        }
        return handler.reject(_wrap(err, ServerException(msg, statusCode: code)));

      default:
        return handler.reject(_wrap(err, const ServerException('حدث خطأ غير متوقع')));
    }
  }

  DioException _wrap(DioException src, Exception error) => DioException(
        requestOptions: src.requestOptions,
        response: src.response,
        error: error,
        type: DioExceptionType.unknown,
      );

  String _message(dynamic body) {
    if (body is Map) return body['message']?.toString() ?? 'حدث خطأ في الخادم';
    return 'حدث خطأ في الخادم';
  }

  Map<String, List<String>>? _validationErrors(dynamic body) {
    if (body is! Map || body['errors'] is! Map) return null;
    return Map.fromEntries(
      (body['errors'] as Map).entries.map(
        (e) => MapEntry(e.key.toString(), List<String>.from(e.value as List)),
      ),
    );
  }
}
