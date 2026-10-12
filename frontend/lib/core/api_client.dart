import 'package:dio/dio.dart';

import 'config.dart';
import 'storage.dart';

/// Called when the API answers 401/403 so the app can drop the session and
/// send the user back to the login page.
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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = storage.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final status = error.response?.statusCode;
        final isLoginCall =
            error.requestOptions.path.contains('/login/access-token');
        if ((status == 401 || status == 403) && !isLoginCall) {
          onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}
