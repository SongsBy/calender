import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';

/// Preferences hold appearance only. Mobile sessions use OS secure storage;
/// web sessions stay in memory and require login after a page reload.
class AppStorage {
  AppStorage(this._prefs, {FlutterSecureStorage? secure}) : _secure = secure;

  static const _sessionKey = 'auth_session_v1';
  static const _themeKey = 'ui-theme';
  final SharedPreferences _prefs;
  final FlutterSecureStorage? _secure;
  String? _accessToken;
  String? _refreshToken;
  int sessionEpoch = 0;
  Future<void> _writes = Future.value();

  static Future<AppStorage> create({bool persistSession = true}) async {
    final storage = AppStorage(
      await SharedPreferences.getInstance(),
      secure: persistSession && !kIsWeb
          ? const FlutterSecureStorage(
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            )
          : null,
    );
    await storage._prefs.remove(
      'access_token',
    ); // Legacy tokens have no session.
    final raw = await storage._secure?.read(key: _sessionKey);
    if (raw != null) {
      try {
        final pair = jsonDecode(raw) as Map<String, dynamic>;
        storage._accessToken = pair['access_token'] as String;
        storage._refreshToken = pair['refresh_token'] as String;
      } catch (_) {
        await storage._secure?.delete(key: _sessionKey);
      }
    }
    return storage;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoggedIn => accessToken != null;

  Future<void> _persist(String? value) {
    final operation = _writes.then((_) async {
      if (value == null) {
        await _secure?.delete(key: _sessionKey);
      } else {
        await _secure?.write(key: _sessionKey, value: value);
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setTokens(Token token, {bool newSession = true}) {
    if (newSession) sessionEpoch++;
    _accessToken = token.accessToken;
    _refreshToken = token.refreshToken;
    return _persist(
      jsonEncode({
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
      }),
    );
  }

  // Retained for existing API test helpers; production login uses setTokens.
  Future<void> setAccessToken(String token) async {
    sessionEpoch++;
    _accessToken = token;
    _refreshToken = null;
  }

  Future<void> clearAccessToken() {
    sessionEpoch++;
    _accessToken = null;
    _refreshToken = null;
    return _persist(null);
  }

  String? get themeMode => _prefs.getString(_themeKey);
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);
}
