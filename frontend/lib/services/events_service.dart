import 'package:dio/dio.dart';
import '../core/config.dart';
import '../models/event.dart';

class EventsService {
  EventsService(this.dio);
  final Dio dio;
  String _path(String id) => '${AppConfig.apiPrefix}/calendars/$id/events';
  Future<List<CalendarEvent>> readMonth(String id, int year, int month) async {
    final result = <CalendarEvent>[];
    var skip = 0;
    while (true) {
      final response = await dio.get<Map<String, dynamic>>(
        _path(id),
        queryParameters: {
          'from': dateText(DateTime.utc(year, month)),
          'to': dateText(DateTime.utc(year, month + 1)),
          'skip': skip,
          'limit': 100,
        },
      );
      final data = response.data!;
      final page = (data['data'] as List)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      result.addAll(page);
      skip += page.length;
      if (skip >= (data['count'] as int)) break;
      if (page.isEmpty) throw StateError('Incomplete event page');
    }
    return result;
  }

  Future<CalendarEvent> read(String calendarId, String eventId) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${_path(calendarId)}/$eventId',
    );
    return CalendarEvent.fromJson(response.data!);
  }

  Future<void> save(
    String calendarId,
    EventDraft draft, {
    String? eventId,
  }) async {
    if (eventId == null) {
      await dio.post<dynamic>(_path(calendarId), data: draft.toJson());
    } else {
      await dio.patch<dynamic>(
        '${_path(calendarId)}/$eventId',
        data: draft.toJson(),
      );
    }
  }

  Future<void> delete(String calendarId, String eventId) async =>
      dio.delete<dynamic>('${_path(calendarId)}/$eventId');
}
