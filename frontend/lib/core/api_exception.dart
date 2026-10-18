import 'package:dio/dio.dart';

/// Extracts a human readable message from an API error: the first
/// validation error `msg`, a plain `detail` string, or a generic fallback.
String extractErrorMessage(Object error) {
  if (error is DioException) {
    if (isConnectionError(error)) {
      return '서버에 연결할 수 없어요. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
      if (detail is String) {
        return detail;
      }
    }
    return error.message ?? 'Something went wrong.';
  }
  return 'Something went wrong.';
}

/// `{"detail": {"code": "...", "message": "..."}}` 형태 응답의 오류 코드.
String? errorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map && detail['code'] is String) {
        return detail['code'] as String;
      }
    }
  }
  return null;
}

/// HTTP 상태 코드 (응답이 없으면 null).
int? statusCode(Object error) =>
    error is DioException ? error.response?.statusCode : null;

/// 서버에 도달하지 못한 오류(오프라인·타임아웃 등).
bool isConnectionError(Object error) =>
    error is DioException &&
    (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        (error.type == DioExceptionType.unknown && error.response == null));
