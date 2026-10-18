import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/events/event_import_page.dart';
import 'package:frontend/services/device_calendar_service.dart';

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
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EventImportPage(calendarId: '1', zone: 'Asia/Seoul'),
        ),
      ),
    );
    expect(calls, isEmpty);
    await tester.tap(find.text('읽기 권한 허용하고 시작'));
    await tester.pumpAndSettle();
    expect(calls, ['permission']);
    expect(find.text('앱 설정 열기'), findsOneWidget);
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
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EventImportPage(calendarId: '1', zone: 'Asia/Seoul'),
          ),
        ),
      );
      await tester.tap(find.text('읽기 권한 허용하고 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일정 조회'));
      await tester.pumpAndSettle();
      expect(find.text('조회 실패'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('일정 조회'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '0개 가져오기'))
            .onPressed,
        null,
      );
      await tester.tap(find.text('개인 약속'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('1개 가져오기'));
      await tester.tap(find.text('1개 가져오기'));
      await tester.pumpAndSettle();
      expect(find.text('1개 일정을 공유할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('개인 약속'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
