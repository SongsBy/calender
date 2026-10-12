import 'package:dio/dio.dart';

import '../core/config.dart';
import '../models/models.dart';

/// `/items` endpoints.
class ItemsService {
  ItemsService(this._dio);

  final Dio _dio;
  static const _p = AppConfig.apiPrefix;

  /// GET /items/
  Future<ItemsPublic> readItems({int skip = 0, int limit = 100}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_p/items/',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return ItemsPublic.fromJson(response.data!);
  }

  /// POST /items/
  Future<ItemPublic> createItem(ItemCreate body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/items/',
      data: body.toJson(),
    );
    return ItemPublic.fromJson(response.data!);
  }

  /// GET /items/{id}
  Future<ItemPublic> readItem(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('$_p/items/$id');
    return ItemPublic.fromJson(response.data!);
  }

  /// PUT /items/{id}
  Future<ItemPublic> updateItem(String id, ItemUpdate body) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '$_p/items/$id',
      data: body.toJson(),
    );
    return ItemPublic.fromJson(response.data!);
  }

  /// DELETE /items/{id}
  Future<Message> deleteItem(String id) async {
    final response =
        await _dio.delete<Map<String, dynamic>>('$_p/items/$id');
    return Message.fromJson(response.data!);
  }
}
