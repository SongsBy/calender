import 'package:dio/dio.dart';

import '../core/config.dart';
import '../models/models.dart';

/// `/users` endpoints.
class UsersService {
  UsersService(this._dio);

  final Dio _dio;
  static const _p = AppConfig.apiPrefix;

  /// GET /users/
  Future<UsersPublic> readUsers({int skip = 0, int limit = 100}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_p/users/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return UsersPublic.fromJson(response.data!);
  }

  /// POST /users/
  Future<UserPublic> createUser(UserCreate body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/users/',
      data: body.toJson(),
    );
    return UserPublic.fromJson(response.data!);
  }

  /// GET /users/me
  Future<UserPublic> readUserMe() async {
    final response = await _dio.get<Map<String, dynamic>>('$_p/users/me');
    return UserPublic.fromJson(response.data!);
  }

  /// DELETE /users/me
  Future<Message> deleteUserMe() async {
    final response = await _dio.delete<Map<String, dynamic>>('$_p/users/me');
    return Message.fromJson(response.data!);
  }

  /// PATCH /users/me
  Future<UserPublic> updateUserMe(UserUpdateMe body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_p/users/me',
      data: body.toJson(),
    );
    return UserPublic.fromJson(response.data!);
  }

  /// PATCH /users/me/password
  Future<Message> updatePasswordMe(UpdatePassword body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_p/users/me/password',
      data: body.toJson(),
    );
    return Message.fromJson(response.data!);
  }

  /// POST /users/signup
  Future<UserPublic> registerUser(UserRegister body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/users/signup',
      data: body.toJson(),
    );
    return UserPublic.fromJson(response.data!);
  }

  /// GET /users/{user_id}
  Future<UserPublic> readUserById(String userId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('$_p/users/$userId');
    return UserPublic.fromJson(response.data!);
  }

  /// PATCH /users/{user_id}
  Future<UserPublic> updateUser(String userId, UserUpdate body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '$_p/users/$userId',
      data: body.toJson(),
    );
    return UserPublic.fromJson(response.data!);
  }

  /// DELETE /users/{user_id}
  Future<Message> deleteUser(String userId) async {
    final response =
        await _dio.delete<Map<String, dynamic>>('$_p/users/$userId');
    return Message.fromJson(response.data!);
  }
}
