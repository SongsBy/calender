import 'package:dio/dio.dart';
import '../core/config.dart';
import '../models/calendar.dart';

class CalendarsService {
  CalendarsService(this._dio);
  final Dio _dio;
  static const _p = AppConfig.apiPrefix;

  Future<List<SharedCalendar>> readAll() async {
    final result = <SharedCalendar>[];
    var skip = 0;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_p/calendars',
        queryParameters: {'skip': skip, 'limit': 100},
      );
      final page = (response.data!['data'] as List)
          .map((e) => SharedCalendar.fromJson(e as Map<String, dynamic>))
          .toList();
      result.addAll(page);
      skip += page.length;
      if (page.isEmpty || skip >= (response.data!['count'] as int)) break;
    }
    return result;
  }

  Future<void> leave(String id) async {
    await _dio.post<void>('$_p/calendars/$id/leave');
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('$_p/calendars/$id');
  }

  Future<SharedCalendar> create(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/calendars',
      data: {'name': name, 'timezone': 'Asia/Seoul'},
    );
    return SharedCalendar.fromJson(response.data!);
  }

  Future<CalendarInvitation> issueInvitation(String calendarId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/calendars/$calendarId/invitations',
    );
    return CalendarInvitation.fromJson(response.data!);
  }

  Future<SharedCalendar> acceptInvitation(String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_p/invitations/accept',
      data: {'code': code},
    );
    return SharedCalendar.fromJson(response.data!);
  }
}
