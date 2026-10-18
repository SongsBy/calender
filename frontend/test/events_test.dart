import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/providers/calendars_provider.dart';
import 'package:frontend/router.dart';
import 'package:frontend/services/calendars_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/events/events_page.dart';
import 'package:frontend/models/calendar.dart';
import 'package:frontend/models/event.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/events_provider.dart';
import 'package:frontend/services/events_service.dart';
import 'package:timezone/timezone.dart' as tz;

const calendar = SharedCalendar(
  id: 'cal',
  name: '우리 일정',
  timezone: 'Asia/Seoul',
  members: [
    CalendarMember(id: 'me', name: '나', role: 'owner', slot: 1),
    CalendarMember(id: 'partner', name: '상대방', role: 'member', slot: 2),
  ],
);

class FakeEvents extends EventsService {
  FakeEvents() : super(Dio());
  List<CalendarEvent> items = [];
  EventDraft? saved;
  bool failRead = false, failSave = false;
  @override
  Future<List<CalendarEvent>> readMonth(String id, int year, int month) async {
    if (failRead) throw Exception('offline');
    return items;
  }

  @override
  Future<void> save(
    String calendarId,
    EventDraft draft, {
    String? eventId,
  }) async {
    if (failSave) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 403,
          data: {
            'detail': {'message': '저장 권한이 없습니다.'},
          },
        ),
      );
    }
    saved = draft;
    items = [
      CalendarEvent(
        id: eventId ?? 'new',
        calendarId: calendarId,
        createdBy: 'me',
        title: draft.title,
        description: draft.description,
        allDay: draft.allDay,
        start: draft.start,
        end: draft.end,
      ),
    ];
  }

  @override
  Future<void> delete(String calendarId, String eventId) async {
    items = [];
  }
}

Future<void> pumpPage(WidgetTester tester, FakeEvents service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
        eventsServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarSchedule(calendar: calendar),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CalendarEvent todayEvent({String author = 'me'}) {
  final now = tz.TZDateTime.now(calendarZone('Asia/Seoul'));
  return CalendarEvent(
    id: 'event',
    calendarId: 'cal',
    createdBy: author,
    title: '오늘 약속',
    allDay: true,
    start: DateTime.utc(now.year, now.month, now.day),
    end: DateTime.utc(now.year, now.month, now.day + 1),
  );
}

class PageAdapter implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls.add(options);
    final skip = options.queryParameters['skip'] as int;
    return ResponseBody.fromString(
      jsonEncode({
        'data': [
          for (var i = skip; i < (skip == 0 ? 100 : 101); i++)
            {
              'id': '$i',
              'calendar_id': 'cal',
              'created_by': 'me',
              'title': 'event',
              'all_day': true,
              'start_date': '2026-10-18',
              'end_date': '2026-10-19',
            },
        ],
        'count': 101,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class SignedInAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: true, user: UserPublic(id: 'me'));
}

class SingleCalendar extends CalendarsService {
  SingleCalendar() : super(Dio());
  @override
  Future<List<SharedCalendar>> readAll() async => [calendar];
}

void main() {
  testWidgets('shell navigation keeps calendar pages bounded and scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = await AppStorage.create(persistSession: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageProvider.overrideWithValue(storage),
          authProvider.overrideWith(SignedInAuth.new),
          calendarsServiceProvider.overrideWithValue(SingleCalendar()),
          calendarDetailProvider.overrideWith((ref, id) async => calendar),
          eventsServiceProvider.overrideWithValue(FakeEvents()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(App)),
    );
    container.read(routerProvider).go('/calendars');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('일정 보기'));
    await tester.tap(find.text('일정 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('editing title preserves original seconds and UTC instant', (
    tester,
  ) async {
    final base = todayEvent();
    final start = DateTime.utc(
      base.start.year,
      base.start.month,
      base.start.day,
      3,
      4,
      55,
    );
    final service = FakeEvents()
      ..items = [
        CalendarEvent(
          id: 'precision',
          calendarId: 'cal',
          createdBy: 'me',
          title: '시각 보존',
          allDay: false,
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
      ];
    await pumpPage(tester, service);
    await tester.ensureVisible(find.text('시각 보존'));
    await tester.tap(find.text('시각 보존'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '제목만 변경');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saved!.start, start);
  });
  test('exclusive boundaries, all-day dates, timezone and DST', () {
    final event = CalendarEvent.fromJson({
      'id': '1',
      'calendar_id': 'cal',
      'created_by': 'me',
      'title': 'night',
      'all_day': false,
      'starts_at': '2026-10-17T14:00:00Z',
      'ends_at': '2026-10-17T15:00:00Z',
    });
    expect(event.occursOn(DateTime.utc(2026, 10, 18), 'Asia/Seoul'), isFalse);
    expect(event.occursOn(DateTime.utc(2026, 10, 17), 'Asia/Seoul'), isTrue);
    final holiday = CalendarEvent.fromJson({
      'id': '2',
      'calendar_id': 'cal',
      'created_by': 'me',
      'title': 'holiday',
      'all_day': true,
      'start_date': '2026-10-18',
      'end_date': '2026-10-20',
    });
    expect(
      holiday.occursOn(DateTime.utc(2026, 10, 19), 'America/New_York'),
      isTrue,
    );
    expect(holiday.occursOn(DateTime.utc(2026, 10, 20), 'Asia/Seoul'), isFalse);
    final dst = CalendarEvent.fromJson({
      'id': '3',
      'calendar_id': 'cal',
      'created_by': 'me',
      'title': 'dst',
      'all_day': false,
      'starts_at': '2026-03-09T04:00:00Z',
      'ends_at': '2026-03-09T05:00:00Z',
    });
    expect(dst.occursOn(DateTime.utc(2026, 3, 8), 'America/New_York'), isFalse);
    expect(dst.occursOn(DateTime.utc(2026, 3, 9), 'America/New_York'), isTrue);
  });
  test('service fetches every page and exclusive next month', () async {
    final adapter = PageAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    expect((await EventsService(dio).readMonth('cal', 2026, 12)).length, 101);
    expect(adapter.calls.map((c) => c.queryParameters['skip']), [0, 100]);
    expect(adapter.calls.first.queryParameters['to'], '2027-01-01');
  });
  testWidgets('create validates, saves all-day and refreshes list', (
    tester,
  ) async {
    final service = FakeEvents();
    await pumpPage(tester, service);
    await tester.tap(find.text('일정 등록').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력해주세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '휴가');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saved!.allDay, isTrue);
    expect(service.saved!.end.difference(service.saved!.start).inDays, 1);
    expect(service.saved!.toJson()['starts_at'], isNull);
    expect(find.text('휴가'), findsOneWidget);
  });
  testWidgets('partner event is read-only', (tester) async {
    final service = FakeEvents()..items = [todayEvent(author: 'partner')];
    await pumpPage(tester, service);
    await tester.ensureVisible(find.text('오늘 약속'));
    await tester.tap(find.text('오늘 약속'));
    await tester.pumpAndSettle();
    expect(find.text('일정 상세'), findsOneWidget);
    expect(find.text('저장'), findsNothing);
    expect(find.text('일정 삭제'), findsNothing);
  });
  testWidgets(
    'own event edits, handles error, retries and deletes with confirmation',
    (tester) async {
      final service = FakeEvents()
        ..items = [todayEvent()]
        ..failSave = true;
      await pumpPage(tester, service);
      await tester.ensureVisible(find.text('오늘 약속'));
      await tester.tap(find.text('오늘 약속'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '바꾼 약속');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('저장 권한이 없습니다.'), findsOneWidget);
      service.failSave = false;
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('바꾼 약속'));
      await tester.tap(find.text('바꾼 약속'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일정 삭제'));
      await tester.pumpAndSettle();
      expect(service.items, isNotEmpty);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(service.items, isEmpty);
    },
  );
  testWidgets('loading failure retries and narrow calendar has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeEvents()..failRead = true;
    await pumpPage(tester, service);
    expect(find.text('일정 다시 불러오기'), findsOneWidget);
    service.failRead = false;
    await tester.tap(find.text('일정 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);
    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
