import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/auth/recover_password_page.dart';
import 'features/auth/reset_password_page.dart';
import 'features/auth/signup_page.dart';
import 'features/calendars/create_calendar_page.dart';
import 'features/calendars/invite_page.dart';
import 'features/calendars/join_page.dart';
import 'features/events/calendar_page.dart';
import 'features/events/event_detail_page.dart';
import 'features/events/import_page.dart';
import 'features/home/home_gate.dart';
import 'features/home/home_page.dart';
import 'models/calendar.dart';
import 'providers/auth_provider.dart';
import 'shared/not_found_page.dart';

/// Route paths. They match the links the backend puts in emails
/// (e.g. `/reset-password?token=...`), so keep them in sync with the backend.
class Routes {
  Routes._();

  static const home = '/';
  static const calendars = '/calendars';
  static const createCalendar = '/calendars/new';
  static const join = '/join';
  static const login = '/login';
  static const signup = '/signup';
  static const recoverPassword = '/recover-password';
  static const resetPassword = '/reset-password';

  static String calendar(String id) => '/calendars/$id';
  static String invite(String id) => '/calendars/$id/invite';
  static String import(String id) => '/calendars/$id/import';
  static String eventDetail(String id, String eventId) =>
      '/calendars/$id/events/$eventId';

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
    initialLocation: Routes.home,
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
        return Routes.home;
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
      GoRoute(path: Routes.home, builder: (context, state) => const HomeGate()),
      GoRoute(
        path: Routes.calendars,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.createCalendar,
        builder: (context, state) => const CreateCalendarPage(),
      ),
      GoRoute(path: Routes.join, builder: (context, state) => const JoinPage()),
      GoRoute(
        path: '/calendars/:calendarId',
        builder: (context, state) =>
            CalendarPage(calendarId: state.pathParameters['calendarId']!),
      ),
      GoRoute(
        path: '/calendars/:calendarId/invite',
        builder: (context, state) =>
            InvitePage(calendarId: state.pathParameters['calendarId']!),
      ),
      GoRoute(
        path: '/calendars/:calendarId/import',
        builder: (context, state) => ImportPage(
          calendarId: state.pathParameters['calendarId']!,
          calendar: state.extra is SharedCalendar
              ? state.extra! as SharedCalendar
              : null,
        ),
      ),
      GoRoute(
        path: '/calendars/:calendarId/events/:eventId',
        builder: (context, state) => EventDetailPage(
          calendarId: state.pathParameters['calendarId']!,
          eventId: state.pathParameters['eventId']!,
          args: state.extra is EventDetailArgs
              ? state.extra! as EventDetailArgs
              : null,
        ),
      ),
    ],
  );
});
