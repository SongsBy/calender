import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/events/import_page.dart';
import 'package:frontend/models/calendar.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/device_calendar_service.dart';
import 'package:frontend/shared/ds.dart';

const _calendar = SharedCalendar(
  id: '1',
  name: '우리의 하루',
  timezone: 'Asia/Seoul',
  members: [
    CalendarMember(id: 'me', name: '민지', role: 'owner', slot: 1),
    CalendarMember(id: 'partner', name: '준호', role: 'member', slot: 2),
  ],
);

Widget _page() => ProviderScope(
  overrides: [
    currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
  ],
  child: const MaterialApp(
    home: ImportPage(calendarId: '1', calendar: _calendar),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarService.channel, null),
  );
  test(
    'native mapping preserves UTC all-day dates and recurrence identity',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarService.channel, (
            call,
          ) async {
            expect(call.method, 'events');
            return [
              {
                'id': '2',
                'title': '휴가',
                'description': null,
                'allDay': true,
                'start': DateTime.utc(2026, 10, 18).millisecondsSinceEpoch,
                'end': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
                'original': DateTime.utc(2026, 10, 18).millisecondsSinceEpoch,
              },
              {
                'id': '3',
                'title': '범위 밖',
                'description': null,
                'allDay': true,
                'start': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
                'end': DateTime.utc(2026, 10, 20).millisecondsSinceEpoch,
                'original': DateTime.utc(2026, 10, 19).millisecondsSinceEpoch,
              },
            ];
          });
      final values = await DeviceCalendarService().events(
        '1',
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
      );
      expect(values, hasLength(1));
      expect(values.single.toJson()['start_date'], '2026-10-18');
      expect(values.single.toJson()['end_date'], '2026-10-19');
      expect(values.single.toJson()['starts_at'], null);
      expect(values.single.toJson()['occurrence_key'], '2026-10-18');
    },
  );
  testWidgets('permission denial offers settings without reading events', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarService.channel, (call) async {
          calls.add(call.method);
          return false;
        });
    await tester.pumpWidget(_page());
    expect(calls, isEmpty);
    expect(find.text('1/5 단계 · 권한'), findsOneWidget);
    await tester.tap(find.text('권한 허용하고 계속'));
    await tester.pumpAndSettle();
    expect(calls, ['permission']);
    expect(
      find.text('캘린더 읽기 권한이 꺼져 있어요. 허용해야 기기 일정을 볼 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('다시 요청'), findsOneWidget);
    expect(find.text('앱 설정에서 허용하기'), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets(
    'selection and consent are required; read errors remain visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var fail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarService.channel, (
            call,
          ) async {
            if (call.method == 'permission') return true;
            if (call.method == 'calendars') {
              return [
                {'id': '1', 'name': '개인 캘린더'},
              ];
            }
            if (call.method == 'events') {
              if (fail) {
                throw PlatformException(code: 'READ_FAILED', message: '조회 실패');
              }
              final now = DateTime.now();
              final day = DateTime.utc(now.year, now.month, now.day);
              return [
                {
                  'id': '2',
                  'title': '개인 약속',
                  'description': '공유 전 확인',
                  'allDay': true,
                  'start': day.millisecondsSinceEpoch,
                  'end': day
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch,
                  'original': day.millisecondsSinceEpoch,
                },
              ];
            }
            throw StateError('unexpected upload or installation access');
          });
      await tester.pumpWidget(_page());
      await tester.tap(find.text('권한 허용하고 계속'));
      await tester.pumpAndSettle();
      expect(find.text('2/5 단계 · 캘린더 선택'), findsOneWidget);
      expect(find.text('개인 캘린더'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('3/5 단계 · 기간 선택'), findsOneWidget);
      await tester.tap(find.text('일정 조회'));
      await tester.pumpAndSettle();
      expect(find.text('조회 실패'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('일정 조회'));
      await tester.pumpAndSettle();
      expect(find.text('4/5 단계 · 일정 선택'), findsOneWidget);
      expect(
        tester
            .widget<DsButton>(find.widgetWithText(DsButton, '선택한 0개 가져오기'))
            .onPressed,
        null,
      );
      await tester.tap(find.text('개인 약속'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 100 선택'), findsOneWidget);
      await tester.tap(find.text('선택한 1개 가져오기'));
      await tester.pumpAndSettle();
      expect(find.text('5/5 단계 · 확인'), findsOneWidget);
      expect(find.text("이 일정 1개를 '우리의 하루'에 복사할까요?"), findsOneWidget);
      expect(find.text('선택한 일정의 제목·시간·설명이 상대방(준호)에게 공개됩니다.'), findsOneWidget);
      expect(
        tester
            .widget<DsButton>(find.widgetWithText(DsButton, '공유 캘린더에 추가'))
            .onPressed,
        null,
      );
      await tester.tap(find.text('돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('개인 약속'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
