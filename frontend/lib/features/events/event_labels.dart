import '../../core/format.dart';
import '../../models/event.dart';

/// 일정 카드·목록에서 쓰는 시간 표기.
extension EventLabels on CalendarEvent {
  /// 시간 일정: '오후 2:00 – 4:30' · 종일: '종일'
  String timeLabel(String zone) =>
      allDay ? '종일' : timeRange(localStart(zone), localEnd(zone));

  /// 종일 여러 날일 때만: '10월 24일 – 10월 25일 · 2일', 아니면 null.
  String? allDaySpan() {
    if (!allDay) return null;
    final days = lastDay.difference(start).inDays + 1;
    return days > 1 ? allDayRange(start, lastDay) : null;
  }

  /// 가져오기 목록용 한 줄: '10월 22일 (목) 오전 10:30 – 11:30' · '11월 3일 (화) · 종일'
  String whenLabel(String zone) {
    if (allDay) {
      final days = lastDay.difference(start).inDays + 1;
      return days > 1
          ? '${monthDayWeekday(start)} – ${monthDayWeekday(lastDay)} · 종일'
          : '${monthDayWeekday(start)} · 종일';
    }
    final a = localStart(zone), b = localEnd(zone);
    final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
    return sameDay
        ? '${monthDayWeekday(a)} ${timeRange(a, b)}'
        : '${monthDayWeekday(a)} ${timeKo(a)} – ${monthDayWeekday(b)} ${timeKo(b)}';
  }

  /// 상세 화면 시간 길이: '2시간 30분' (시간 일정만).
  String? durationLabel(String zone) =>
      allDay ? null : durationKo(localEnd(zone).difference(localStart(zone)));
}
