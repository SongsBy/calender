import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/events/events_page.dart';
import 'package:frontend/models/event.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/events_provider.dart';
import 'events_test.dart' show FakeEvents, calendar, todayEvent;

class PollEvents extends FakeEvents {
  int reads = 0;
  bool forbidden = false;
  @override
  Future<List<CalendarEvent>> readMonth(String id, int year, int month) {
    reads++;
    if (forbidden) {
      throw DioException(
        requestOptions: RequestOptions(path: '/events'),
        response: Response(
          requestOptions: RequestOptions(path: '/events'),
          statusCode: 403,
        ),
      );
    }
    return super.readMonth(id, year, month);
  }
}

void main() {
  testWidgets(
    'poll refresh retains data on failure and stops in background and after dispose',
    (tester) async {
      final service = PollEvents()..items = [todayEvent()];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
            eventsServiceProvider.overrideWithValue(service),
            calendarDetailProvider.overrideWith((ref, id) async => calendar),
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
      expect(service.reads, 1);
      service.failRead = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(service.reads, 2);
      expect(find.text('오늘 약속'), findsOneWidget);
      expect(find.text('갱신 다시 시도'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 45));
      expect(service.reads, 2);
      service.failRead = false;
      service.items = [];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.reads, 3);
      expect(find.text('오늘 약속'), findsNothing);
      expect(find.text('갱신 다시 시도'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(service.reads, 3);
    },
  );

  for (final status in [403, 404]) {
    testWidgets('calendar $status redirects to list with message', (
      tester,
    ) async {
      var missing = false;
      final router = GoRouter(
        initialLocation: '/events',
        routes: [
          GoRoute(
            path: '/events',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: EventsPage(calendarId: 'cal')),
            ),
          ),
          GoRoute(
            path: '/calendars',
            builder: (_, _) => const Scaffold(body: Text('목록 도착')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
            eventsServiceProvider.overrideWithValue(PollEvents()),
            calendarDetailProvider.overrideWith((ref, id) async {
              if (missing) {
                throw DioException(
                  requestOptions: RequestOptions(path: '/cal'),
                  response: Response(
                    requestOptions: RequestOptions(path: '/cal'),
                    statusCode: status,
                  ),
                );
              }
              return calendar;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      missing = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('목록 도착'), findsOneWidget);
      expect(find.text('캘린더가 삭제되었거나 접근 권한이 없습니다.'), findsOneWidget);
    });
  }
}
