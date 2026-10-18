import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/api_exception.dart';
import 'package:frontend/core/format.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/core/validators.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await AppStorage.create(persistSession: false);
  return ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const App(),
  );
}

void main() {
  group('validators', () {
    test('email', () {
      expect(Validators.email(''), 'Invalid email address');
      expect(Validators.email('not-an-email'), 'Invalid email address');
      expect(Validators.email('user@example.com'), isNull);
    });

    test('password', () {
      expect(Validators.password(''), 'Password is required');
      expect(
        Validators.password('short'),
        'Password must be at least 8 characters',
      );
      expect(Validators.password('longenough'), isNull);
    });

    test('confirm password', () {
      final v = Validators.confirmPassword(() => 'secret123');
      expect(v(''), 'Password confirmation is required');
      expect(v('other'), "The passwords don't match");
      expect(v('secret123'), isNull);
    });
  });

  group('korean formatting', () {
    test('dates and times follow the design copy', () {
      final day = DateTime(2026, 10, 24, 14, 0);
      expect(monthDayWeekday(day), '10월 24일 (토)');
      expect(monthDayWeekdayLong(day), '10월 24일 토요일');
      expect(yearMonth(day), '2026년 10월');
      expect(fullDate(day), '2026년 10월 24일 (토)');
      expect(timeKo(day), '오후 2:00');
      expect(timeRange(day, DateTime(2026, 10, 24, 16, 30)), '오후 2:00 – 4:30');
      expect(
        timeRange(DateTime(2026, 10, 24, 9), DateTime(2026, 10, 24, 18)),
        '오전 9:00 – 오후 6:00',
      );
      expect(
        timeRange(DateTime(2026, 10, 24, 9), DateTime(2026, 10, 25, 18)),
        '오전 9:00 – 다음날 오후 6:00',
      );
      expect(durationKo(const Duration(hours: 2, minutes: 30)), '2시간 30분');
      expect(durationKo(const Duration(days: 2)), '2일');
      expect(
        allDayRange(DateTime.utc(2026, 10, 24), DateTime.utc(2026, 10, 25)),
        '10월 24일 – 10월 25일 · 2일',
      );
      expect(
        deadlineKo(DateTime(2026, 10, 19, 16, 52)),
        '10월 19일 (월) 오후 4시 52분까지',
      );
      expect(thousands(5000), '5,000');
    });
  });

  group('extractErrorMessage', () {
    test('reads FastAPI detail string', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 400,
          data: {'detail': 'Incorrect email or password'},
        ),
      );
      expect(extractErrorMessage(err), 'Incorrect email or password');
    });

    test('reads first validation error msg', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'email'],
                'msg': 'value is not a valid email',
              },
            ],
          },
        ),
      );
      expect(extractErrorMessage(err), 'value is not a valid email');
    });

    test('reads structured error codes', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 409,
          data: {
            'detail': {'code': 'INVITATION_USED', 'message': '이미 사용된 초대코드입니다.'},
          },
        ),
      );
      expect(errorCode(err), 'INVITATION_USED');
      expect(statusCode(err), 409);
      expect(extractErrorMessage(err), '이미 사용된 초대코드입니다.');
    });

    test('falls back for unknown errors', () {
      expect(extractErrorMessage(Exception('x')), 'Something went wrong.');
    });
  });

  group('routing', () {
    testWidgets('logged out user lands on the login page', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      expect(find.text('calender'), findsOneWidget);
      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('login form validates before submitting', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('로그인'));
      await tester.pumpAndSettle();
      expect(find.text('아이디를 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('sign up link navigates to the sign up page', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      expect(find.text('가입하기'), findsOneWidget);
      expect(find.text('로그인으로 돌아가기'), findsOneWidget);
    });
  });
}
