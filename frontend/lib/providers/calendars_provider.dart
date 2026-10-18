import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar.dart';
import '../services/calendars_service.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

final calendarsServiceProvider = Provider<CalendarsService>(
  (ref) => CalendarsService(ref.watch(dioProvider)),
);

// Scope cache to the signed-in user and drop it when the screen is left.
final calendarsProvider = FutureProvider.autoDispose<List<SharedCalendar>>((
  ref,
) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return [];
  return ref.watch(calendarsServiceProvider).readAll();
});
