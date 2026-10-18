import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/items_service.dart';
import 'package:frontend/services/login_service.dart';
import 'package:frontend/services/users_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal stand-in for the FastAPI backend covering the endpoints the app
/// uses, so the Dio client, form encoding and auth interceptor get exercised
/// over a real socket.
class FakeBackend {
  late HttpServer _server;
  final List<HttpRequest> requests = [];
  int refreshCalls = 0;
  bool rejectRefresh = false;
  bool rejectRetried = false;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    requests.add(req);
    final body = await utf8.decoder.bind(req).join();
    final path = req.uri.path;
    final auth = req.headers.value('authorization');

    void json(int status, Object data) {
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(data));
      req.response.close();
    }

    if (path == '/api/v1/login/access-token') {
      final form = Uri.splitQueryString(body);
      if (form['username'] == 'admin@example.com' &&
          form['password'] == 'changethis') {
        return json(200, {'access_token': 'tok123', 'token_type': 'bearer'});
      }
      return json(400, {'detail': 'Incorrect email or password'});
    }

    if (path == '/api/v1/login/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (rejectRefresh) return json(401, {'detail': 'Expired refresh'});
      return json(200, {
        'access_token': 'tok123',
        'refresh_token': 'rotated',
        'expires_in': 900,
      });
    }
    if (path == '/api/v1/forbidden') return json(403, {'detail': 'Forbidden'});
    if (auth != 'Bearer tok123' || rejectRetried) {
      return json(401, {'detail': 'Not authenticated'});
    }

    if (path == '/api/v1/users/me') {
      return json(200, {
        'id': 'u1',
        'email': 'admin@example.com',
        'full_name': 'Admin',
        'is_active': true,
        'is_superuser': true,
      });
    }
    if (path == '/api/v1/items/' && req.method == 'GET') {
      return json(200, {
        'data': [
          {'id': 'i1', 'title': 'First', 'description': null, 'owner_id': 'u1'},
        ],
        'count': 1,
      });
    }
    if (path == '/api/v1/items/' && req.method == 'POST') {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return json(200, {
        'id': 'i2',
        'title': data['title'],
        'description': data['description'],
        'owner_id': 'u1',
      });
    }
    return json(404, {'detail': 'Not Found'});
  }
}

void main() {
  late FakeBackend backend;
  late AppStorage storage;
  var unauthorizedCalls = 0;

  setUp(() async {
    backend = FakeBackend();
    await backend.start();
    SharedPreferences.setMockInitialValues({});
    storage = await AppStorage.create(persistSession: false);
    unauthorizedCalls = 0;
  });

  tearDown(() => backend.stop());

  test('login posts form data and stores the token', () async {
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;
    final login = LoginService(dio);

    final token = await login.loginAccessToken(
      username: 'admin@example.com',
      password: 'changethis',
    );
    expect(token.accessToken, 'tok123');
    expect(
      backend.requests.single.headers.contentType?.mimeType,
      'application/x-www-form-urlencoded',
    );
    expect(unauthorizedCalls, 0);
  });

  test(
    'wrong password surfaces the FastAPI detail and does not log out',
    () async {
      final dio = createApiClient(storage, () => unauthorizedCalls++)
        ..options.baseUrl = backend.baseUrl;
      await expectLater(
        LoginService(dio).loginAccessToken(username: 'x@y.z', password: 'bad'),
        throwsA(isA<Exception>()),
      );
      expect(unauthorizedCalls, 0);
    },
  );

  test('authenticated calls send the Bearer header', () async {
    await storage.setAccessToken('tok123');
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;

    final me = await UsersService(dio).readUserMe();
    expect(me.email, 'admin@example.com');
    expect(me.isSuperuser, isTrue);

    final items = await ItemsService(dio).readItems();
    expect(items.count, 1);
    expect(items.data.single.title, 'First');

    final created = await ItemsService(
      dio,
    ).createItem(const ItemCreate(title: 'New', description: 'desc'));
    expect(created.id, 'i2');
    expect(created.description, 'desc');
  });

  test('401 triggers the unauthorized handler', () async {
    await storage.setAccessToken('expired');
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;

    await expectLater(UsersService(dio).readUserMe(), throwsA(anything));
    expect(unauthorizedCalls, 1);
  });
  test(
    'concurrent 401s share one refresh and retry with rotated tokens',
    () async {
      await storage.setTokens(
        const Token(accessToken: 'expired', refreshToken: 'original'),
      );
      final dio = createApiClient(storage, () => unauthorizedCalls++)
        ..options.baseUrl = backend.baseUrl;
      final results = await Future.wait(
        List.generate(5, (_) => UsersService(dio).readUserMe()),
      );
      expect(results.length, 5);
      expect(backend.refreshCalls, 1);
      expect(storage.refreshToken, 'rotated');
      expect(unauthorizedCalls, 0);
    },
  );

  test('403 neither refreshes nor clears the session', () async {
    await storage.setTokens(
      const Token(accessToken: 'tok123', refreshToken: 'original'),
    );
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;
    await expectLater(dio.get('/api/v1/forbidden'), throwsA(anything));
    expect(backend.refreshCalls, 0);
    expect(storage.isLoggedIn, isTrue);
    expect(unauthorizedCalls, 0);
  });

  test(
    'failed refresh clears the session once for concurrent errors',
    () async {
      backend.rejectRefresh = true;
      await storage.setTokens(
        const Token(accessToken: 'expired', refreshToken: 'original'),
      );
      final dio = createApiClient(storage, () => unauthorizedCalls++)
        ..options.baseUrl = backend.baseUrl;
      await Future.wait(
        List.generate(3, (_) async {
          await expectLater(UsersService(dio).readUserMe(), throwsA(anything));
        }),
      );
      expect(backend.refreshCalls, 1);
      expect(storage.isLoggedIn, isFalse);
      expect(unauthorizedCalls, 1);
    },
  );

  test('retried 401 stops without a refresh loop', () async {
    backend.rejectRetried = true;
    await storage.setTokens(
      const Token(accessToken: 'expired', refreshToken: 'original'),
    );
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;
    await expectLater(UsersService(dio).readUserMe(), throwsA(anything));
    expect(backend.refreshCalls, 1);
    expect(storage.isLoggedIn, isFalse);
  });

  test('logout during refresh cannot restore the previous session', () async {
    await storage.setTokens(
      const Token(accessToken: 'expired', refreshToken: 'original'),
    );
    final dio = createApiClient(storage, () => unauthorizedCalls++)
      ..options.baseUrl = backend.baseUrl;
    final request = expectLater(
      UsersService(dio).readUserMe(),
      throwsA(anything),
    );
    while (backend.refreshCalls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await storage.clearAccessToken();
    await request;
    expect(storage.isLoggedIn, isFalse);
    expect(storage.refreshToken, isNull);
  });
}
