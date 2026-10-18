import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/calendars/create_calendar_page.dart';
import 'package:frontend/features/calendars/invite_page.dart';
import 'package:frontend/features/calendars/join_page.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:frontend/models/calendar.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/calendars_provider.dart';
import 'package:frontend/providers/events_provider.dart';
import 'package:frontend/services/calendars_service.dart';
import 'package:frontend/shared/ds.dart';
import 'package:go_router/go_router.dart';

class FakeCalendars extends CalendarsService {
  FakeCalendars() : super(Dio());
  List<SharedCalendar> calendars = [];
  String? rejectJoinCode;
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
    final reject = rejectJoinCode;
    if (reject != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: reject == 'INVALID_INVITATION' ? 400 : 409,
          data: {
            'detail': {'code': reject, 'message': '서버 메시지'},
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

Future<GoRouter> showHome(WidgetTester tester, FakeCalendars service) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/calendars', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/calendars/new',
        builder: (_, _) => const CreateCalendarPage(),
      ),
      GoRoute(path: '/join', builder: (_, _) => const JoinPage()),
      GoRoute(
        path: '/calendars/:id',
        builder: (_, state) =>
            Scaffold(body: Text('달력 ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/calendars/:id/invite',
        builder: (_, state) =>
            InvitePage(calendarId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          const UserPublic(id: 'me', username: 'minji', fullName: '민지'),
        ),
        calendarsServiceProvider.overrideWithValue(service),
        calendarDetailProvider.overrideWith(
          (ref, id) async => service.calendars.firstWhere((c) => c.id == id),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
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
      await showHome(tester, service);
      final label = deleting ? '캘린더 삭제' : '캘린더 나가기';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('휴대폰에 저장된 원본 일정은 변경되지 않아요.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(service.removed, 0);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      service.rejectRemoval = true;
      await tester.tap(find.text(deleting ? '삭제' : '나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(DsBanner), findsOneWidget);
      service.rejectRemoval = false;
      await tester.tap(find.text(deleting ? '삭제' : '나가기'));
      await tester.pumpAndSettle();
      expect(service.removed, 1);
      expect(find.text('함께할 첫 캘린더를\n만들어볼까요?'), findsOneWidget);
    });
  }

  testWidgets('create validates, moves to invite and issues codes', (
    tester,
  ) async {
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
    await showHome(tester, service);
    expect(find.text('함께할 첫 캘린더를\n만들어볼까요?'), findsOneWidget);
    await tester.tap(find.text('새 캘린더 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    expect(find.text('캘린더 이름을 입력해 주세요.'), findsOneWidget);
    await tester.tap(find.text('함께하는 주말'));
    await tester.pumpAndSettle();
    expect(find.text('7/30'), findsOneWidget);
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    // 만든 직후 초대 화면으로 넘어가며 코드가 한 번 발급됩니다.
    expect(find.text('상대방 초대하기'), findsOneWidget);
    expect(service.issued, 1);
    expect(find.text('ABCD'), findsOneWidget);
    expect(find.text('2345'), findsOneWidget);
    await tester.tap(find.text('코드 복사'));
    await tester.pumpAndSettle();
    expect(copied, 'ABCD-EFGH-2345');
    await tester.tap(find.text('새 코드 발급').first);
    await tester.pumpAndSettle();
    expect(find.text('새 코드를 발급할까요?'), findsOneWidget);
    await tester.tap(find.text('새 코드 발급').last);
    await tester.pumpAndSettle();
    expect(service.issued, 2);
    await tester.tap(find.text('달력으로'));
    await tester.pumpAndSettle();
    expect(find.text('함께하는 주말'), findsOneWidget);
    expect(find.text('상대방을 기다리고 있어요'), findsOneWidget);
    expect(find.text('1/2명'), findsOneWidget);
  });

  testWidgets('join maps server codes to copy, then connects two members', (
    tester,
  ) async {
    final service = FakeCalendars()..rejectJoinCode = 'INVALID_INVITATION';
    final router = await showHome(tester, service);
    await tester.tap(find.text('초대코드로 참여하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('초대코드를 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abcd-efgh-2345');
    await tester.pumpAndSettle();
    expect(find.text('ABCD EFGH 2345'), findsOneWidget);
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(
      find.text('만료되었거나 올바르지 않은 코드예요. 상대방에게 새 코드를 요청해 주세요.'),
      findsOneWidget,
    );
    service.rejectJoinCode = 'INVITATION_USED';
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용된 코드예요. 코드는 한 번만 쓸 수 있어요.'), findsOneWidget);
    service.rejectJoinCode = 'ALREADY_MEMBER';
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    expect(find.text('이미 참여 중인 캘린더예요.'), findsOneWidget);
    service.rejectJoinCode = null;
    await tester.tap(find.text('참여하기'));
    await tester.pumpAndSettle();
    // 참여 뒤 홈으로 돌아갑니다 (테스트 라우터에서는 목록 화면).
    expect(find.text('2/2명'), findsOneWidget);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('상대방 초대하기'), findsNothing);
    expect(find.text('캘린더 나가기'), findsOneWidget);
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
    await showHome(tester, service);
    expect(find.text('2/2명'), findsOneWidget);
    expect(find.text('민지님, 좋은 하루예요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
