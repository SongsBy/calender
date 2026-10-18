import 'package:flutter/services.dart';
import '../models/event.dart';

class DeviceCalendarService {
  static const channel = MethodChannel('shared_calendar/device');
  Future<bool> requestPermission() async =>
      await channel.invokeMethod<bool>('permission') ?? false;
  Future<void> settings() => channel.invokeMethod('settings');
  Future<String> installationId() async =>
      (await channel.invokeMethod<String>('installationId'))!;
  Future<List<Map<String, dynamic>>> calendars() async => _list('calendars');
  Future<List<Map<String, dynamic>>> _list(
    String method, [
    Map<String, dynamic>? args,
  ]) async => (await channel.invokeListMethod<dynamic>(
    method,
    args,
  ))!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<List<DeviceEvent>> events(
    String calendarId,
    DateTime from,
    DateTime to,
  ) async {
    // Padding includes date-only UTC all-day instances regardless of device zone.
    final rows = await _list('events', {
      'calendarId': calendarId,
      'from': from.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      'to': to.add(const Duration(days: 1)).millisecondsSinceEpoch,
    });
    return rows.map((r) => DeviceEvent(calendarId, r)).where((e) {
      final a = e.event.allDay ? calendarDate(from) : from;
      final b = e.event.allDay ? calendarDate(to) : to;
      return e.event.start.isBefore(b) && e.event.end.isAfter(a);
    }).toList();
  }
}

class DeviceEvent {
  DeviceEvent(this.calendarId, this.source);
  final String calendarId;
  final Map<String, dynamic> source;
  DateTime instant(String key) =>
      DateTime.fromMillisecondsSinceEpoch(source[key] as int, isUtc: true);
  String get key => '$calendarId:${source['id']}:${source['original']}';
  CalendarEvent get event => CalendarEvent(
    id: key,
    calendarId: calendarId,
    createdBy: '',
    title: (source['title'] as String?)?.trim().isNotEmpty == true
        ? source['title'] as String
        : '제목 없음',
    description: source['description'] as String?,
    allDay: source['allDay'] as bool,
    start: instant('start'),
    end: instant('end'),
  );
  Map<String, dynamic> toJson() => {
    ...EventDraft(
      title: event.title,
      description: event.description,
      allDay: event.allDay,
      start: event.start,
      end: event.end,
    ).toJson(),
    'source_calendar_id': calendarId,
    'source_event_id': source['id'],
    'occurrence_key': event.allDay
        ? dateText(instant('original'))
        : instant('original').toIso8601String(),
  };
}
