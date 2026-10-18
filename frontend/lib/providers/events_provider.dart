import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar.dart';
import '../models/event.dart';
import '../services/events_service.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import '../core/config.dart';

final eventsServiceProvider = Provider<EventsService>(
  (ref) => EventsService(ref.watch(dioProvider)),
);
typedef EventMonth = ({String calendarId, int year, int month});
final eventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, EventMonth>((ref, query) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return [];
      return ref
          .watch(eventsServiceProvider)
          .readMonth(query.calendarId, query.year, query.month);
    }, retry: (count, error) => null);
final calendarDetailProvider = FutureProvider.autoDispose
    .family<SharedCalendar, String>((ref, id) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) throw StateError('로그인이 필요합니다.');
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>('${AppConfig.apiPrefix}/calendars/$id');
      return SharedCalendar.fromJson(response.data!);
    }, retry: (count, error) => null);
