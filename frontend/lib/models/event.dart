import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _zonesReady = false;
tz.Location calendarZone(String name) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  return tz.getLocation(name);
}

DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
String dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String timeText(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.allDay,
    required this.start,
    required this.end,
    this.createdAt,
    this.updatedAt,
  });
  final String id, calendarId, createdBy, title;
  final String? description;
  final bool allDay;
  // All-day dates use UTC as a date-only container; timed values are UTC instants.
  final DateTime start, end;
  final DateTime? createdAt, updatedAt;

  /// 종일 일정의 마지막 날짜 (포함). `end`는 배타적 다음 날입니다.
  DateTime get lastDay => end.subtract(const Duration(days: 1));
  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    calendarId: json['calendar_id'] as String,
    createdBy: json['created_by'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    allDay: json['all_day'] as bool,
    start: DateTime.parse(
      json[json['all_day'] == true ? 'start_date' : 'starts_at'] as String,
    ).toUtcDate(json['all_day'] == true),
    end: DateTime.parse(
      json[json['all_day'] == true ? 'end_date' : 'ends_at'] as String,
    ).toUtcDate(json['all_day'] == true),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'] as String)?.toUtc(),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.tryParse(json['updated_at'] as String)?.toUtc(),
  );
  DateTime localStart(String zone) =>
      allDay ? start : tz.TZDateTime.from(start, calendarZone(zone));
  DateTime localEnd(String zone) =>
      allDay ? end : tz.TZDateTime.from(end, calendarZone(zone));
  bool occursOn(DateTime day, String zone) {
    final date = calendarDate(day);
    if (allDay) {
      return start.isBefore(date.add(const Duration(days: 1))) &&
          end.isAfter(date);
    }
    final location = calendarZone(zone);
    final from = tz.TZDateTime(location, day.year, day.month, day.day);
    final to = tz.TZDateTime(location, day.year, day.month, day.day + 1);
    return start.isBefore(to) && end.isAfter(from);
  }

  String periodLabel(String zone) {
    if (allDay) {
      final last = end.subtract(const Duration(days: 1));
      return start == last
          ? '종일 · ${dateText(start)}'
          : '종일 · ${dateText(start)} ~ ${dateText(last)}';
    }
    final a = localStart(zone), b = localEnd(zone);
    return '${dateText(a)} ${timeText(a)} ~ ${calendarDate(a) == calendarDate(b) ? '' : '${dateText(b)} '}${timeText(b)}';
  }
}

extension on DateTime {
  DateTime toUtcDate(bool dateOnly) => dateOnly ? calendarDate(this) : toUtc();
}

class EventDraft {
  const EventDraft({
    required this.title,
    this.description,
    required this.allDay,
    required this.start,
    required this.end,
  });
  final String title;
  final String? description;
  final bool allDay;
  final DateTime start, end;
  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description?.trim().isEmpty == true
        ? null
        : description?.trim(),
    'all_day': allDay,
    'starts_at': allDay ? null : start.toUtc().toIso8601String(),
    'ends_at': allDay ? null : end.toUtc().toIso8601String(),
    'start_date': allDay ? dateText(start) : null,
    'end_date': allDay ? dateText(end) : null,
  };
}
