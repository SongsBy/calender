import 'package:dio/dio.dart';

import '../core/config.dart';
import '../models/models.dart';

/// `/login`, `/password-recovery` and `/reset-password` endpoints.
class LoginService {
  LoginService(this._dio);

  final Dio _dio;
  static const _p = AppConfig.apiPrefix;

  /// POST /login/access-token (OAuth2 password form).
  Future<Token> loginAccessToken({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/login/access-token',
      data: {'username': username, 'password': password},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        extra: {'public': true},
      ),
    );
    return Token.fromJson(response.data!);
  }

  Future<void> logout() async {
    await _dio.post<void>('$_p/login/logout');
  }

  /// POST /login/test-token
  Future<UserPublic> testToken() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/login/test-token',
    );
    return UserPublic.fromJson(response.data!);
  }

  /// POST /password-recovery/{email}
  Future<Message> recoverPassword(String email) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/password-recovery/${Uri.encodeComponent(email)}',
      options: Options(extra: {'public': true}),
    );
    return Message.fromJson(response.data!);
  }

  /// POST /reset-password/
  Future<Message> resetPassword(NewPassword body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/reset-password/',
      data: body.toJson(),
      options: Options(extra: {'public': true}),
    );
    return Message.fromJson(response.data!);
  }
}
