import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/korean_holidays.dart';

void main() {
  test('고정 공휴일은 어느 해든 표시된다', () {
    expect(koreanHoliday(DateTime.utc(2026, 1, 1)), '신정');
    expect(koreanHoliday(DateTime.utc(2026, 3, 1)), '삼일절');
    expect(koreanHoliday(DateTime.utc(2026, 10, 9)), '한글날');
    expect(koreanHoliday(DateTime.utc(2040, 12, 25)), '성탄절');
    expect(koreanHoliday(DateTime.utc(2026, 10, 19)), isNull);
  });

  test('음력 공휴일과 대체공휴일은 연도별 표에서 나온다', () {
    expect(koreanHoliday(DateTime.utc(2026, 2, 17)), '설날');
    expect(koreanHoliday(DateTime.utc(2026, 3, 2)), '대체공휴일');
    expect(koreanHoliday(DateTime.utc(2026, 5, 24)), '부처님오신날');
    expect(koreanHoliday(DateTime.utc(2026, 9, 25)), '추석');
    expect(koreanHoliday(DateTime.utc(2026, 10, 5)), '대체공휴일');
    expect(koreanHoliday(DateTime.utc(2025, 5, 5)), '어린이날·부처님오신날');
    expect(koreanHolidays(DateTime.utc(2025, 5, 5)), ['어린이날', '부처님오신날']);
    expect(koreanHolidays(DateTime.utc(2028, 10, 3)), ['개천절', '추석']);
    expect(koreanHolidays(DateTime.utc(2026, 10, 19)), isEmpty);
    expect(isKoreanHoliday(DateTime(2027, 2, 8, 23, 59)), isTrue);
  });

  test('표의 모든 날짜는 실제 존재하는 날짜다', () {
    final (from, to) = koreanHolidayTableYears;
    for (var y = from; y <= to; y++) {
      for (var m = 1; m <= 12; m++) {
        final days = DateTime.utc(y, m + 1, 0).day;
        for (var d = 1; d <= days; d++) {
          // 예외 없이 조회되어야 합니다.
          koreanHoliday(DateTime.utc(y, m, d));
        }
      }
    }
  });
}
