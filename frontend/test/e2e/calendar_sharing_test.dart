// Run only against an isolated, disposable backend: joined users cannot yet leave.
// flutter test test/e2e/calendar_sharing_test.dart --dart-define=RUN_CALENDAR_E2E=true --dart-define=API_URL=http://127.0.0.1:58000
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/calendars_service.dart';
import 'package:frontend/services/events_service.dart';
import 'package:frontend/models/event.dart';

void main() {
  test(
    'two HTTP clients share membership; third user is denied',
    () async {
      const url = String.fromEnvironment('API_URL');
      expect(url, isNotEmpty);
      final clients = <Dio>[];
      for (var i = 0; i < 3; i++) {
        final dio = Dio(BaseOptions(baseUrl: url));
        clients.add(dio);
        final username = 'share_${DateTime.now().microsecondsSinceEpoch}_$i';
        await dio.post<dynamic>(
          '/api/v1/users/signup',
          data: {
            'username': username,
            'password': 'test-password-123',
            'full_name': '공유 검증 $i',
          },
        );
        final login = await dio.post<Map<String, dynamic>>(
          '/api/v1/login/access-token',
          data: {'username': username, 'password': 'test-password-123'},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        dio.options.headers['Authorization'] =
            'Bearer ${login.data!['access_token']}';
      }
      addTearDown(() {
        for (final client in clients) {
          client.close();
        }
      });
      final a = CalendarsService(clients[0]);
      final b = CalendarsService(clients[1]);
      final c = CalendarsService(clients[2]);
      final created = await a.create('두 사람의 일정');
      final invitation = await a.issueInvitation(created.id);
      final joined = await b.acceptInvitation(
        invitation.displayCode.toLowerCase(),
      );
      expect(joined.id, created.id);
      expect(joined.members.length, 2);
      expect((await a.readAll()).single.isConnected, isTrue);
      expect((await b.readAll()).single.id, created.id);
      expect(await c.readAll(), isEmpty);
      final eventsA = EventsService(clients[0]);
      final eventsB = EventsService(clients[1]);
      final draft = EventDraft(
        title: '저녁 약속',
        allDay: false,
        start: DateTime.utc(2026, 10, 18, 10),
        end: DateTime.utc(2026, 10, 18, 11),
      );
      await eventsA.save(created.id, draft);
      final shared = (await eventsB.readMonth(created.id, 2026, 10)).single;
      expect(shared.title, '저녁 약속');
      await expectLater(
        eventsB.save(created.id, draft, eventId: shared.id),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      await expectLater(
        eventsB.delete(created.id, shared.id),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      await expectLater(
        EventsService(clients[2]).readMonth(created.id, 2026, 10),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      final holiday = EventDraft(
        title: '휴가',
        allDay: true,
        start: DateTime.utc(2026, 10, 18),
        end: DateTime.utc(2026, 10, 20),
      );
      await eventsA.save(created.id, holiday, eventId: shared.id);
      final changed = (await eventsB.readMonth(created.id, 2026, 10)).single;
      expect(changed.allDay, isTrue);
      expect(
        changed.occursOn(DateTime.utc(2026, 10, 19), 'Asia/Seoul'),
        isTrue,
      );
      expect(
        changed.occursOn(DateTime.utc(2026, 10, 20), 'Asia/Seoul'),
        isFalse,
      );
      await eventsA.delete(created.id, shared.id);
      expect(await eventsB.readMonth(created.id, 2026, 10), isEmpty);

      await expectLater(
        clients[2].get<dynamic>('/api/v1/calendars/${created.id}'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );
      await expectLater(
        c.acceptInvitation(invitation.code),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
    },
    skip: !const bool.fromEnvironment('RUN_CALENDAR_E2E'),
  );
}
