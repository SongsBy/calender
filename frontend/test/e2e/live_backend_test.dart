// Smoke test against a REAL backend. Skipped unless RUN_E2E=true is passed
// and the backend is reachable, so a plain `flutter test` never touches it.
//
//   flutter test test/e2e --dart-define=RUN_E2E=true --dart-define=API_URL=http://localhost:8000
//
// Uses the first superuser from the root .env (admin@example.com / changethis
// by default). Creates and deletes its own data.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/items_service.dart';
import 'package:frontend/services/login_service.dart';
import 'package:frontend/services/users_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runE2e = bool.fromEnvironment('RUN_E2E');
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000',
);
const adminEmail = String.fromEnvironment(
  'ADMIN_EMAIL',
  defaultValue: 'admin@example.com',
);
const adminPassword = String.fromEnvironment(
  'ADMIN_PASSWORD',
  defaultValue: 'changethis',
);

Future<bool> backendUp() async {
  try {
    final r = await Dio().get<dynamic>('$apiUrl/api/v1/utils/health-check/');
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() async {
  final up = runE2e && await backendUp();
  final skipReason = runE2e
      ? 'backend not running'
      : 'pass --dart-define=RUN_E2E=true';

  late AppStorage storage;
  late Dio dio;
  var unauthorized = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await AppStorage.create(persistSession: false);
    dio = createApiClient(storage, () => unauthorized++);
  });

  test('backend reachable', () {
    expect(up, isTrue, reason: 'backend not reachable at $apiUrl');
  }, skip: up ? false : skipReason);

  test('login as superuser, read me', () async {
    final token = await LoginService(
      dio,
    ).loginAccessToken(username: adminEmail, password: adminPassword);
    expect(token.accessToken, isNotEmpty);
    await storage.setTokens(token);

    final me = await UsersService(dio).readUserMe();
    expect(me.email, adminEmail);
    expect(me.isSuperuser, isTrue);
  }, skip: up ? false : skipReason);

  test(
    'wrong password is rejected with a readable message',
    () async {
      try {
        await LoginService(
          dio,
        ).loginAccessToken(username: adminEmail, password: 'wrong-password');
        fail('expected an error');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
        expect((e.response?.data as Map)['detail'], contains('credentials'));
      }
      expect(unauthorized, 0, reason: 'login failure must not trigger logout');
    },
    skip: up ? false : skipReason,
  );

  test('items: create, list, update, delete', () async {
    final items = ItemsService(dio);
    final created = await items.createItem(
      const ItemCreate(title: 'e2e item', description: 'from flutter test'),
    );
    expect(created.id, isNotEmpty);

    final list = await items.readItems();
    expect(list.data.map((i) => i.id), contains(created.id));

    final updated = await items.updateItem(
      created.id,
      const ItemUpdate(title: 'e2e item (edited)', description: null),
    );
    expect(updated.title, 'e2e item (edited)');
    expect(updated.description, isNull);

    final msg = await items.deleteItem(created.id);
    expect(msg.message, isNotEmpty);
    final after = await items.readItems();
    expect(after.data.map((i) => i.id), isNot(contains(created.id)));
  }, skip: up ? false : skipReason);

  test(
    'admin: create user, update, delete; signup + recover password',
    () async {
      final users = UsersService(dio);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final email = 'e2e-$stamp@example.com';

      final created = await users.createUser(
        UserCreate(
          email: email,
          password: 'password123',
          fullName: 'E2E User',
          isActive: true,
          isSuperuser: false,
        ),
      );
      expect(created.email, email);

      final all = await users.readUsers();
      expect(all.data.map((u) => u.email), contains(email));

      final updated = await users.updateUser(
        created.id,
        const UserUpdate(fullName: 'E2E Renamed', isSuperuser: true),
      );
      expect(updated.fullName, 'E2E Renamed');
      expect(updated.isSuperuser, isTrue);

      await users.deleteUser(created.id);

      // Public signup (no auth needed) and password recovery email.
      final signupEmail = 'signup-$stamp@example.com';
      final anon = createApiClient(
        AppStorage(await SharedPreferences.getInstance()),
        () {},
      );
      final registered = await UsersService(anon).registerUser(
        UserRegister(
          username: 'e2e_${DateTime.now().microsecondsSinceEpoch}',
          email: signupEmail,
          password: 'password123',
          fullName: 'Signup User',
        ),
      );
      expect(registered.email, signupEmail);

      final recover = await LoginService(anon).recoverPassword(signupEmail);
      expect(recover.message, isNotEmpty);

      // Clean up the signup user as admin.
      await users.deleteUser(registered.id);
    },
    skip: up ? false : skipReason,
  );

  test('expired/invalid token triggers logout handler', () async {
    await storage.setAccessToken('not-a-real-token');
    final before = unauthorized;
    try {
      await UsersService(dio).readUserMe();
    } catch (_) {}
    expect(unauthorized, before + 1);
  }, skip: up ? false : skipReason);

  tearDownAll(() {
    if (!up) stderr.writeln('e2e skipped ($skipReason)');
  });
}
