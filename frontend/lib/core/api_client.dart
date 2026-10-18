import 'package:dio/dio.dart';

import '../models/auth.dart';
import 'config.dart';
import 'storage.dart';

typedef UnauthorizedHandler = void Function();

Dio createApiClient(AppStorage storage, UnauthorizedHandler onUnauthorized) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  Future<bool>? refreshing;
  int? refreshingEpoch;

  Future<void> expire(int epoch) async {
    if (storage.sessionEpoch != epoch) return;
    try {
      await storage.clearAccessToken();
    } finally {
      onUnauthorized();
    }
  }

  Future<bool> refresh(int epoch) async {
    final raw = storage.refreshToken;
    if (raw == null) {
      await expire(epoch);
      return false;
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '${AppConfig.apiPrefix}/login/refresh',
        data: {'refresh_token': raw},
        options: Options(extra: {'public': true}),
      );
      if (storage.sessionEpoch != epoch) return false;
      await storage.setTokens(
        Token.fromJson(response.data!),
        newSession: false,
      );
      return storage.sessionEpoch == epoch;
    } catch (_) {
      // Rotation may have committed even if the response was lost. Never reuse it.
      await expire(epoch);
      return false;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.extra.putIfAbsent('sessionEpoch', () => storage.sessionEpoch);
        if (options.extra['public'] != true && storage.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${storage.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.extra['public'] == true) {
          handler.next(
            error,
          ); // In particular, 403 must not refresh or log out.
          return;
        }
        final epoch = request.extra['sessionEpoch'] as int;
        if (storage.sessionEpoch != epoch) {
          handler.next(error);
          return;
        }
        if (request.extra['retried'] == true) {
          await expire(epoch);
          handler.next(error);
          return;
        }
        // A late 401 may belong to the token already replaced by another request.
        var ready =
            storage.accessToken != null &&
            request.headers['Authorization'] != 'Bearer ${storage.accessToken}';
        if (!ready) {
          if (refreshing == null || refreshingEpoch != epoch) {
            refreshingEpoch = epoch;
            refreshing = refresh(epoch);
          }
          final pending = refreshing!;
          ready = await pending;
          if (identical(refreshing, pending)) refreshing = null;
        }
        if (!ready || storage.sessionEpoch != epoch) {
          handler.next(error);
          return;
        }
        request.extra['retried'] = true;
        request.headers['Authorization'] = 'Bearer ${storage.accessToken}';
        try {
          handler.resolve(await dio.fetch<dynamic>(request));
        } on DioException catch (retryError) {
          handler.reject(retryError);
        }
      },
    ),
  );
  return dio;
}
