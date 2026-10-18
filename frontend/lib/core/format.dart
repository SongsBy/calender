/// 한국어 날짜·시간 표기 도우미. 디자인 시안의 문구 형식을 그대로 따릅니다.
library;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '토'
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

/// '토요일'
String weekdayLong(DateTime d) => '${weekdayShort(d)}요일';

/// '10월 24일'
String monthDay(DateTime d) => '${d.month}월 ${d.day}일';

/// '10월 24일 (토)'
String monthDayWeekday(DateTime d) => '${monthDay(d)} (${weekdayShort(d)})';

/// '10월 24일 토요일'
String monthDayWeekdayLong(DateTime d) => '${monthDay(d)} ${weekdayLong(d)}';

/// '2026년 10월'
String yearMonth(DateTime d) => '${d.year}년 ${d.month}월';

/// '2026년 10월 24일 (토)'
String fullDate(DateTime d) => '${d.year}년 ${monthDayWeekday(d)}';

/// '오후 2:00'
String timeKo(DateTime d) {
  final period = d.hour < 12 ? '오전' : '오후';
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$period $hour:${d.minute.toString().padLeft(2, '0')}';
}

/// '오후 2:00 – 4:30' · 오전/오후가 다르면 '오전 9:00 – 오후 6:00'
/// 날짜가 다르면 '오전 9:00 – 다음날 오후 6:00' 또는 '… – 10월 26일 오후 6:00'
String timeRange(DateTime a, DateTime b) {
  final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
  final start = timeKo(a);
  if (sameDay) {
    final samePeriod = (a.hour < 12) == (b.hour < 12);
    final end = samePeriod ? timeKo(b).split(' ').last : timeKo(b);
    return '$start – $end';
  }
  final nextDay = DateTime(a.year, a.month, a.day + 1);
  final isNextDay =
      b.year == nextDay.year &&
      b.month == nextDay.month &&
      b.day == nextDay.day;
  return isNextDay
      ? '$start – 다음날 ${timeKo(b)}'
      : '$start – ${monthDay(b)} ${timeKo(b)}';
}

/// '2시간 30분', '45분', '3일'
String durationKo(Duration d) {
  if (d.inMinutes <= 0) return '0분';
  if (d.inHours >= 24 && d.inMinutes % (24 * 60) == 0) return '${d.inDays}일';
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}

/// '10월 24일 – 10월 25일 · 2일' (종일 여러 날). `last`는 포함되는 마지막 날짜.
String allDayRange(DateTime start, DateTime last) {
  final days = last.difference(start).inDays + 1;
  if (days <= 1) return monthDay(start);
  return '${monthDay(start)} – ${monthDay(last)} · $days일';
}

/// '10월 19일 (월) 오후 4시 52분까지'
String deadlineKo(DateTime d) {
  final period = d.hour < 12 ? '오전' : '오후';
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute == 0 ? '' : ' ${d.minute}분';
  return '${monthDayWeekday(d)} $period $hour시$minute까지';
}

/// '방금 갱신됨' 또는 '오후 4:37에 마지막 갱신'
String refreshedLabel(DateTime? at, DateTime now) {
  if (at == null) return '';
  if (now.difference(at).inSeconds < 60) return '방금 갱신됨';
  return '${timeKo(at)}에 마지막 갱신';
}

/// 1,000 단위 콤마 — '5,000'
String thousands(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
