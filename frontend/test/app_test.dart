import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/api_exception.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/core/validators.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await AppStorage.create();
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
      expect(Validators.password('short'),
          'Password must be at least 8 characters');
      expect(Validators.password('longenough'), isNull);
    });

    test('confirm password', () {
      final v = Validators.confirmPassword(() => 'secret123');
      expect(v(''), 'Password confirmation is required');
      expect(v('other'), "The passwords don't match");
      expect(v('secret123'), isNull);
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
              {'loc': ['body', 'email'], 'msg': 'value is not a valid email'}
            ]
          },
        ),
      );
      expect(extractErrorMessage(err), 'value is not a valid email');
    });

    test('falls back for unknown errors', () {
      expect(extractErrorMessage(Exception('x')), 'Something went wrong.');
    });
  });

  group('routing', () {
    testWidgets('logged out user lands on the login page', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Login to your account'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('login form validates before submitting', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email address'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('sign up link navigates to the sign up page', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Create an account'), findsOneWidget);
    });
  });
}
