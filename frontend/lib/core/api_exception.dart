import 'package:dio/dio.dart';

/// Extracts a human readable message from an API error: the first
/// validation error `msg`, a plain `detail` string, or a generic fallback.
String extractErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
      if (detail is String) {
        return detail;
      }
    }
    return error.message ?? 'Something went wrong.';
  }
  return 'Something went wrong.';
}
