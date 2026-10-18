import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/admin_page.dart';
import 'features/events/events_page.dart';
import 'features/calendars/calendars_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/recover_password_page.dart';
import 'features/auth/reset_password_page.dart';
import 'features/auth/signup_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/items/items_page.dart';
import 'features/settings/settings_page.dart';
import 'providers/auth_provider.dart';
import 'shared/app_shell.dart';
import 'shared/not_found_page.dart';

/// Route paths. They match the links the backend puts in emails
/// (e.g. `/reset-password?token=...`), so keep them in sync with the backend.
class Routes {
  Routes._();

  static const dashboard = '/';
  static const items = '/items';
  static const calendars = '/calendars';
  static const admin = '/admin';
  static const settings = '/settings';
  static const login = '/login';
  static const signup = '/signup';
  static const recoverPassword = '/recover-password';
  static const resetPassword = '/reset-password';

  static const publicOnly = {login, signup, recoverPassword, resetPassword};
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<bool>(ref.read(authProvider).isLoggedIn);
  ref.listen(
    authProvider.select((s) => s.isLoggedIn),
    (_, next) => refresh.value = next,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    errorBuilder: (context, state) => const NotFoundPage(),
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final path = state.uri.path;
      final isPublicOnly = Routes.publicOnly.contains(path);

      if (!isLoggedIn && !isPublicOnly) {
        return Routes.login;
      }
      if (isLoggedIn && isPublicOnly) {
        return Routes.dashboard;
      }
      if (path == Routes.resetPassword &&
          (state.uri.queryParameters['token'] ?? '').isEmpty) {
        return Routes.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.recoverPassword,
        builder: (context, state) => const RecoverPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const AppPage(child: DashboardPage()),
          ),
          GoRoute(
            path: Routes.calendars,
            builder: (context, state) => const AppPage(child: CalendarsPage()),
          ),
          GoRoute(
            path: '/calendars/:calendarId',
            builder: (context, state) => EventsPage(
              scrollable: true,
              calendarId: state.pathParameters['calendarId']!,
            ),
          ),
          GoRoute(
            path: Routes.items,
            builder: (context, state) => const AppPage(child: ItemsPage()),
          ),
          GoRoute(
            path: Routes.admin,
            builder: (context, state) => const AppPage(child: AdminPage()),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const AppPage(child: SettingsPage()),
          ),
        ],
      ),
    ],
  );
});
