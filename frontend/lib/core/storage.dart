import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences for the few values we persist.
class AppStorage {
  AppStorage(this._prefs);

  static const _tokenKey = 'access_token';
  static const _themeKey = 'ui-theme';

  final SharedPreferences _prefs;

  static Future<AppStorage> create() async {
    return AppStorage(await SharedPreferences.getInstance());
  }

  String? get accessToken => _prefs.getString(_tokenKey);

  bool get isLoggedIn => accessToken != null;

  Future<void> setAccessToken(String token) =>
      _prefs.setString(_tokenKey, token);

  Future<void> clearAccessToken() => _prefs.remove(_tokenKey);

  String? get themeMode => _prefs.getString(_themeKey);

  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);
}
