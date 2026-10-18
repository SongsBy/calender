import '../../shared/app_shell.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../../providers/calendars_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'event_import_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../shared/widgets.dart';
import 'event_editor.dart';

bool calendarAccessLost(Object? error) =>
    error is DioException &&
    (error.response?.statusCode == 403 || error.response?.statusCode == 404);

void leaveUnavailableCalendar(BuildContext context, WidgetRef ref) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    ref.invalidate(calendarsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캘린더가 삭제되었거나 접근 권한이 없습니다.')));
    context.go('/calendars');
  });
}

Color memberColor(BuildContext context, int slot) =>
    slot == 1 ? Colors.blue.shade700 : Colors.deepOrange.shade700;

class EventsPage extends ConsumerWidget {
  const EventsPage({
    super.key,
    required this.calendarId,
    this.scrollable = false,
  });
  final bool scrollable;
  final String calendarId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarDetailProvider(calendarId));
    ref.listen(calendarDetailProvider(calendarId), (_, next) {
      if (calendarAccessLost(next.error)) {
        leaveUnavailableCalendar(context, ref);
      }
    });
    return calendar.when(
      skipError: !calendarAccessLost(calendar.error),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Column(
        children: [
          Text(extractErrorMessage(error)),
          TextButton(
            onPressed: () => ref.invalidate(calendarDetailProvider(calendarId)),
            child: const Text('다시 불러오기'),
          ),
          TextButton(
            onPressed: () => context.go('/calendars'),
            child: const Text('캘린더 목록'),
          ),
        ],
      ),
      data: (value) => CalendarSchedule(
        scrollable: scrollable,
        key: ValueKey('${value.id}:${ref.watch(currentUserProvider)?.id}'),
        calendar: value,
      ),
    );
  }
}

class CalendarSchedule extends ConsumerStatefulWidget {
  const CalendarSchedule({
    super.key,
    required this.calendar,
    this.scrollable = false,
  });
  final bool scrollable;
  final SharedCalendar calendar;
  @override
  ConsumerState<CalendarSchedule> createState() => _CalendarScheduleState();
}

class _CalendarScheduleState extends ConsumerState<CalendarSchedule>
    with WidgetsBindingObserver {
  late DateTime _selected;
  Timer? _poll;
  bool _refreshing = false;
  bool _active = true;
  final Map<EventMonth, List<CalendarEvent>> _lastEvents = {};
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_active && ModalRoute.of(context)?.isCurrent == true) _refresh();
    });
  }

  EventMonth get _query => (
    calendarId: widget.calendar.id,
    year: _selected.year,
    month: _selected.month,
  );
  @override
  void initState() {
    super.initState();
    _selected = calendarDate(
      tz.TZDateTime.now(calendarZone(widget.calendar.timezone)),
    );
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _active = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_active) _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _poll?.cancel();
    if (_active) {
      _startPolling();
      if (ModalRoute.of(context)?.isCurrent == true) _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || !_active || !mounted) return;
    final query = _query;
    if (ref.read(eventsProvider(query)).isLoading) return;
    _refreshing = true;
    try {
      await Future.wait([
        ref.refresh(eventsProvider(query).future),
        ref.refresh(calendarDetailProvider(widget.calendar.id).future),
      ]);
    } catch (_) {
      // Provider errors are rendered below; keep the last successful month.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _edit([CalendarEvent? event]) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final changed = await showEventEditor(
      context,
      calendar: widget.calendar,
      day: _selected,
      event: event,
      readOnly: event != null && event.createdBy != user.id,
    );
    if (changed == true && mounted) {
      ref.invalidate(eventsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 반영했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider(_query));
    if (state.hasValue && !state.isLoading && !state.hasError) {
      _lastEvents[_query] = state.requireValue;
    }
    ref.listen(eventsProvider(_query), (_, next) {
      if (calendarAccessLost(next.error)) {
        leaveUnavailableCalendar(context, ref);
      }
    });
    final detail = ref.watch(calendarDetailProvider(widget.calendar.id));
    final retained = _lastEvents[_query];
    final user = ref.watch(currentUserProvider);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/calendars'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('캘린더 목록'),
          ),
        ),
        PageHeader(
          title: widget.calendar.name,
          subtitle: '${widget.calendar.timezone} 기준 · 15초마다 자동 갱신됩니다.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: user == null ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('일정 등록'),
            ),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventImportPage(
                      calendarId: widget.calendar.id,
                      zone: widget.calendar.timezone,
                    ),
                  ),
                ),
                icon: const Icon(Icons.download),
                label: const Text('기기 일정 가져오기'),
              ),
            TextButton(
              onPressed: () => setState(
                () => _selected = calendarDate(
                  tz.TZDateTime.now(calendarZone(widget.calendar.timezone)),
                ),
              ),
              child: const Text('오늘'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final member in widget.calendar.members)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: memberColor(context, member.slot),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${member.name}${member.id == user?.id ? ' (나)' : ''}',
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: _selected.year <= 1900 && _selected.month == 1
                  ? null
                  : () => setState(
                      () => _selected = DateTime.utc(
                        _selected.year,
                        _selected.month - 1,
                      ),
                    ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_selected.year}년 ${_selected.month}월',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: _selected.year >= 2100 && _selected.month == 12
                  ? null
                  : () => setState(
                      () => _selected = DateTime.utc(
                        _selected.year,
                        _selected.month + 1,
                      ),
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if ((state.hasError || detail.hasError) &&
            !calendarAccessLost(state.error) &&
            !calendarAccessLost(detail.error))
          Column(
            children: [
              const Text('자동 갱신에 실패했습니다. 마지막으로 불러온 내용을 표시합니다.'),
              TextButton(onPressed: _refresh, child: const Text('갱신 다시 시도')),
            ],
          ),
        if (retained != null && !calendarAccessLost(state.error))
          _calendarContent(retained)
        else
          state.when(
            skipLoadingOnRefresh: false,
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(extractErrorMessage(error)),
                  TextButton(
                    onPressed: () => ref.invalidate(eventsProvider(_query)),
                    child: const Text('일정 다시 불러오기'),
                  ),
                ],
              ),
            ),
            data: (events) => _calendarContent(events),
          ),
      ],
    );
    return widget.scrollable
        ? AppPage(onRefresh: _refresh, child: content)
        : content;
  }

  Widget _calendarContent(List<CalendarEvent> events) {
    final selectedEvents = events
        .where((e) => e.occursOn(_selected, widget.calendar.timezone))
        .toList();
    final members = {for (final m in widget.calendar.members) m.id: m};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthGrid(
          selected: _selected,
          events: events,
          calendar: widget.calendar,
          onSelect: (day) => setState(() => _selected = day),
        ),
        const SizedBox(height: 24),
        Text(
          '${_selected.month}월 ${_selected.day}일 · 일정 ${selectedEvents.length}개',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (selectedEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '등록된 일정이 없어요. 위의 ‘일정 등록’을 눌러 추가해보세요.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final event in selectedEvents)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Icon(
                event.allDay ? Icons.wb_sunny_outlined : Icons.schedule,
                color: memberColor(
                  context,
                  members[event.createdBy]?.slot ?? 1,
                ),
              ),
              title: Text(event.title),
              subtitle: Text(
                '${members[event.createdBy]?.name ?? '사용자'} · ${event.periodLabel(widget.calendar.timezone)}${event.description?.isNotEmpty == true ? '\n${event.description}' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _edit(event),
            ),
          ),
      ],
    );
  }
}

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.selected,
    required this.events,
    required this.calendar,
    required this.onSelect,
  });
  final DateTime selected;
  final List<CalendarEvent> events;
  final SharedCalendar calendar;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime.utc(selected.year, selected.month);
    final offset = first.weekday % 7;
    final days = DateTime.utc(selected.year, selected.month + 1, 0).day;
    final rows = ((offset + days) / 7).ceil();
    final today = calendarDate(
      tz.TZDateTime.now(calendarZone(calendar.timezone)),
    );
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = row * 7 + col - offset + 1;
                      if (day < 1 || day > days) {
                        return const SizedBox(height: 60);
                      }
                      final date = DateTime.utc(
                        selected.year,
                        selected.month,
                        day,
                      );
                      final matches = events
                          .where((e) => e.occursOn(date, calendar.timezone))
                          .toList();
                      final authors = matches.map((e) => e.createdBy).toSet();
                      final active = date == selected;
                      return Semantics(
                        label: '${dateText(date)}, 일정 ${matches.length}개',
                        selected: active,
                        button: true,
                        child: InkWell(
                          key: ValueKey('day-${dateText(date)}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(date),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: active ? scheme.primaryContainer : null,
                              borderRadius: BorderRadius.circular(10),
                              border: date == today
                                  ? Border.all(color: scheme.primary)
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    fontWeight: active ? FontWeight.bold : null,
                                    color: active
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 8,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final member
                                          in calendar.members.where(
                                            (m) => authors.contains(m.id),
                                          ))
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: memberColor(
                                              context,
                                              member.slot,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
