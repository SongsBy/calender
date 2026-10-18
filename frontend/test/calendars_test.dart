import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendars/calendars_page.dart';
import 'package:frontend/models/calendar.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/calendars_provider.dart';
import 'package:frontend/services/calendars_service.dart';

class FakeCalendars extends CalendarsService {
  FakeCalendars() : super(Dio());
  List<SharedCalendar> calendars = [];
  bool rejectJoin = false;
  int issued = 0;
  bool rejectRemoval = false;
  int removed = 0;
  @override
  Future<void> delete(String id) async {
    if (rejectRemoval) throw Exception('삭제 실패');
    removed++;
    calendars = [];
  }

  @override
  Future<void> leave(String id) => delete(id);
  @override
  Future<List<SharedCalendar>> readAll() async => calendars;
  @override
  Future<SharedCalendar> create(String name) async {
    final calendar = SharedCalendar(
      id: 'calendar',
      name: name,
      timezone: 'Asia/Seoul',
      members: const [
        CalendarMember(id: 'me', name: '나', role: 'owner', slot: 1),
      ],
    );
    calendars = [calendar];
    return calendar;
  }

  @override
  Future<CalendarInvitation> issueInvitation(String calendarId) async {
    issued++;
    return CalendarInvitation(
      code: 'ABCDEFGH2345',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );
  }

  @override
  Future<SharedCalendar> acceptInvitation(String code) async {
    if (rejectJoin) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 400,
          data: {
            'detail': {'code': 'INVALID_INVITATION', 'message': '만료된 초대코드입니다.'},
          },
        ),
      );
    }
    final calendar = SharedCalendar(
      id: 'joined',
      name: '함께 쓰는 일정',
      timezone: 'Asia/Seoul',
      members: const [
        CalendarMember(id: 'other', name: '상대방', role: 'owner', slot: 1),
        CalendarMember(id: 'me', name: '나', role: 'member', slot: 2),
      ],
    );
    calendars = [calendar];
    return calendar;
  }
}

Future<void> showPage(WidgetTester tester, FakeCalendars service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
        calendarsServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CalendarsPage())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final deleting in [true, false]) {
    testWidgets('removal confirmation cancellation error retry $deleting', (
      tester,
    ) async {
      final service = FakeCalendars();
      if (deleting) {
        await service.create('우리 일정');
      } else {
        await service.acceptInvitation('code');
      }
      await showPage(tester, service);
      final label = deleting ? '캘린더 삭제' : '캘린더 나가기';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('휴대폰의 원본 일정은 변경되지 않습니다.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(service.removed, 0);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      service.rejectRemoval = true;
      await tester.tap(find.text(deleting ? '삭제하기' : '나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      service.rejectRemoval = false;
      await tester.tap(find.text(deleting ? '삭제하기' : '나가기'));
      await tester.pumpAndSettle();
      expect(service.removed, 1);
      expect(find.text('아직 연결된 캘린더가 없어요.'), findsOneWidget);
    });
  }

  testWidgets(
    'create validates, refreshes list, and issues code only on request',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final service = FakeCalendars();
      await showPage(tester, service);
      expect(find.text('아직 연결된 캘린더가 없어요.'), findsOneWidget);
      await tester.tap(find.text('새 캘린더'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(find.text('이름을 입력해주세요.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '우리 일정');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(find.text('상대방의 참여를 기다리고 있어요 · 1/2명'), findsOneWidget);
      await tester.tap(find.text('상대방 초대하기'));
      await tester.pumpAndSettle();
      expect(service.issued, 0);
      await tester.tap(find.text('초대코드 발급'));
      await tester.pumpAndSettle();
      expect(find.text('ABCD-EFGH-2345'), findsOneWidget);
      expect(service.issued, 1);
      await tester.tap(find.text('코드 복사'));
      await tester.pumpAndSettle();
      expect(find.text('복사했어요'), findsOneWidget);
      expect(copied, 'ABCD-EFGH-2345');
    },
  );

  testWidgets('join shows server error, retry connects two members', (
    tester,
  ) async {
    final service = FakeCalendars()..rejectJoin = true;
    await showPage(tester, service);
    await tester.tap(find.text('초대코드로 참여'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'abcd-efgh-2345');
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('만료된 초대코드입니다.'), findsOneWidget);
    service.rejectJoin = false;
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('두 사람이 연결되었어요 · 2/2명'), findsOneWidget);
    expect(find.text('상대방 초대하기'), findsNothing);
  });

  testWidgets('phone width shows connected calendar without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeCalendars();
    await service.acceptInvitation('ABCDEFGH2345');
    await showPage(tester, service);
    expect(find.text('두 사람이 연결되었어요 · 2/2명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
