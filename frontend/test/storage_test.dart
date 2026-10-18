import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage.dart';
import 'package:frontend/models/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'legacy-token'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'mobile pair restores from secure storage and logout removes it',
    () async {
      final first = await AppStorage.create();
      expect(first.isLoggedIn, isFalse);
      expect(
        (await SharedPreferences.getInstance()).containsKey('access_token'),
        isFalse,
      );
      await first.setTokens(
        const Token(accessToken: 'access', refreshToken: 'refresh'),
      );
      final restored = await AppStorage.create();
      expect(restored.accessToken, 'access');
      expect(restored.refreshToken, 'refresh');
      await restored.clearAccessToken();
      expect((await AppStorage.create()).isLoggedIn, isFalse);
    },
  );

  test('late storage writes cannot restore a cleared session', () async {
    final storage = await AppStorage.create();
    final write = storage.setTokens(
      const Token(accessToken: 'access', refreshToken: 'refresh'),
    );
    final clear = storage.clearAccessToken();
    await Future.wait([write, clear]);
    expect((await AppStorage.create()).isLoggedIn, isFalse);
  });

  test('memory-only sessions do not survive recreation', () async {
    final storage = await AppStorage.create(persistSession: false);
    await storage.setTokens(
      const Token(accessToken: 'access', refreshToken: 'refresh'),
    );
    expect(
      (await AppStorage.create(persistSession: false)).isLoggedIn,
      isFalse,
    );
  });
}
