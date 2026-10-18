import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendars_provider.dart';
import '../../providers/events_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import '../../shared/edge_refresh.dart';
import '../../shared/navigation.dart';
import 'event_detail_page.dart';
import 'event_labels.dart';
import 'import_page.dart';
import 'quick_add_sheet.dart';
import 'solo_invite_card.dart';
import '../home/account_sheet.dart';

bool calendarAccessLost(Object? error) =>
    error is DioException &&
    (error.response?.statusCode == 403 || error.response?.statusCode == 404);

final _noticed = <String>{};

/// F7. 상대방이 캘린더를 삭제함 — 안내 다이얼로그 뒤 목록으로 이동.
void leaveUnavailableCalendar(
  BuildContext context,
  WidgetRef ref,
  String calendarId,
) {
  if (!_noticed.add(calendarId)) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      _noticed.remove(calendarId);
      return;
    }
    ref.invalidate(calendarsProvider);
    await showDsNotice(
      context,
      title: '상대방이 캘린더를 삭제했어요',
      message: '캘린더와 일정이 모두 삭제되어 더는 볼 수 없어요. 캘린더 목록으로 이동할게요.',
      hint: '휴대폰에 저장된 원본 일정은 그대로 남아 있어요.',
      buttonLabel: '목록으로',
      onPressed: () {
        _noticed.remove(calendarId);
        if (context.mounted) goHome(context);
      },
    );
  });
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// F. 공유 달력 — 라우트 진입점. 캘린더 정보를 불러온 뒤 달력을 그립니다.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key, required this.calendarId});
  final String calendarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarDetailProvider(calendarId));
    ref.listen(calendarDetailProvider(calendarId), (_, next) {
      if (calendarAccessLost(next.error)) {
        leaveUnavailableCalendar(context, ref, calendarId);
      }
    });
    return calendar.when(
      skipError: !calendarAccessLost(calendar.error),
      loading: () => DsScreen(
        header: DsHeader(
          title: '',
          backLabel: '캘린더 목록으로',
          onBack: () => goBackOrHome(context),
        ),
        body: const ScheduleSkeleton(),
      ),
      error: (error, _) => DsScreen(
        header: DsHeader(
          title: '공유 달력',
          backLabel: '캘린더 목록으로',
          onBack: () => goBackOrHome(context),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DsCard(
              color: AppColors.cream,
              radius: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: DsStateView(
                art: const DsIconTile(icon: DsIcons.offline),
                title: calendarAccessLost(error)
                    ? '캘린더를 찾을 수 없어요'
                    : '서버에 연결할 수 없어요',
                description: calendarAccessLost(error)
                    ? '삭제되었거나 접근 권한이 없는 캘린더예요.'
                    : extractErrorMessage(error),
                action: Column(
                  children: [
                    DsButton(
                      label: '다시 시도',
                      height: 44,
                      fontSize: 14,
                      onPressed: () =>
                          ref.invalidate(calendarDetailProvider(calendarId)),
                    ),
                    const SizedBox(height: 8),
                    DsButton(
                      label: '캘린더 목록',
                      variant: DsButtonVariant.text,
                      fontSize: 14,
                      onPressed: () => goHome(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      data: (value) => CalendarSchedule(
        key: ValueKey('${value.id}:${ref.watch(currentUserProvider)?.id}'),
        calendar: value,
      ),
    );
  }
}

/// 달력 본체 — 15초마다 자동 갱신, 위/아래로 당겨 갱신, 날짜 선택과 일정 목록.
class CalendarSchedule extends ConsumerStatefulWidget {
  const CalendarSchedule({
    super.key,
    required this.calendar,
    this.isHome = false,
  });
  final SharedCalendar calendar;

  /// 홈으로 쓰일 때: 뒤로 가기 대신 계정 메뉴를 보입니다.
  final bool isHome;
  @override
  ConsumerState<CalendarSchedule> createState() => _CalendarScheduleState();
}

class _CalendarScheduleState extends ConsumerState<CalendarSchedule>
    with WidgetsBindingObserver {
  late DateTime _selected;
  Timer? _poll;
  bool _refreshing = false;
  bool _manualRefreshing = false;
  bool _active = true;
  DateTime? _lastRefreshed;
  final Map<EventMonth, List<CalendarEvent>> _lastEvents = {};

  String get _zone => widget.calendar.timezone;
  DateTime get _today => calendarDate(tz.TZDateTime.now(calendarZone(_zone)));

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
    _selected = _today;
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

  Future<void> _refresh({bool manual = false}) async {
    if (_refreshing || !_active || !mounted) return;
    final query = _query;
    if (ref.read(eventsProvider(query)).isLoading) return;
    _refreshing = true;
    if (manual) setState(() => _manualRefreshing = true);
    try {
      await Future.wait([
        ref.refresh(eventsProvider(query).future),
        ref.refresh(calendarDetailProvider(widget.calendar.id).future),
      ]);
    } catch (_) {
      // Provider errors are rendered below; keep the last successful month.
    } finally {
      _refreshing = false;
      if (mounted && manual) setState(() => _manualRefreshing = false);
    }
  }

  Future<void> _open(Future<bool?> Function() navigate) async {
    final changed = await navigate();
    if (changed == true && mounted) {
      ref.invalidate(eventsProvider);
    }
  }

  Future<void> _create() => _quickAdd(_selected, _selected);

  Future<void> _showDetail(CalendarEvent event) => _open(
    () => pushScreen<bool>(
      context,
      Routes.eventDetail(widget.calendar.id, event.id),
      () => EventDetailPage(
        calendarId: widget.calendar.id,
        eventId: event.id,
        args: EventDetailArgs(calendar: widget.calendar, event: event),
      ),
      extra: EventDetailArgs(calendar: widget.calendar, event: event),
    ),
  );

  Future<void> _import() => _open(
    () => pushScreen<bool>(
      context,
      Routes.import(widget.calendar.id),
      () =>
          ImportPage(calendarId: widget.calendar.id, calendar: widget.calendar),
      extra: widget.calendar,
    ),
  );

  /// 길게 눌러 고른 날짜 범위에 바로 일정 추가.
  Future<void> _quickAdd(DateTime start, DateTime end) {
    setState(() => _selected = start);
    return _open(
      () => showQuickAddSheet(
        context,
        calendar: widget.calendar,
        start: start,
        end: end,
      ),
    );
  }

  double _swipeDx = 0;
  int _slideDir = 0; // 1 = 다음 달(오른쪽에서 들어옴), -1 = 이전 달

  void _shiftMonth(int delta) {
    if (delta > 0 && _selected.year >= 2100 && _selected.month == 12) return;
    if (delta < 0 && _selected.year <= 1900 && _selected.month == 1) return;
    setState(() {
      _slideDir = delta.sign;
      _selected = DateTime.utc(_selected.year, _selected.month + delta);
    });
  }

  /// 좌우 스와이프: 60px 이상 밀거나 빠르게 튕기면 달을 넘깁니다.
  void _onSwipeEnd(DragEndDetails details) {
    final dx = _swipeDx;
    _swipeDx = 0;
    final velocity = details.primaryVelocity ?? 0;
    if (dx < -60 || velocity < -400) {
      _shiftMonth(1);
    } else if (dx > 60 || velocity > 400) {
      _shiftMonth(-1);
    }
  }

  Widget _monthTransition(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: Offset(_slideDir == 0 ? 0 : (_slideDir > 0 ? .18 : -.18), 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider(_query));
    if (state.hasValue && !state.isLoading && !state.hasError) {
      _lastEvents[_query] = state.requireValue;
      _lastRefreshed = DateTime.now();
    }
    ref.listen(eventsProvider(_query), (_, next) {
      if (calendarAccessLost(next.error)) {
        leaveUnavailableCalendar(context, ref, widget.calendar.id);
      }
    });
    final detail = ref.watch(calendarDetailProvider(widget.calendar.id));
    final retained = _lastEvents[_query];
    final user = ref.watch(currentUserProvider);
    final calendar = detail.value ?? widget.calendar;
    final me = user == null ? null : calendar.member(user.id);
    final partner = user == null ? null : calendar.partnerOf(user.id);

    final accessLost =
        calendarAccessLost(state.error) || calendarAccessLost(detail.error);
    final refreshFailed =
        (state.hasError || detail.hasError) && !accessLost && retained != null;
    final initialLoading = retained == null && state.isLoading;
    final loadFailed = retained == null && state.hasError && !accessLost;
    final events = retained ?? (state.hasValue ? state.requireValue : null);

    final status = initialLoading
        ? '불러오는 중…'
        : state.isLoading || _manualRefreshing
        ? '갱신 중…'
        : refreshedLabel(_lastRefreshed, DateTime.now());

    final children = <Widget>[
      if (_manualRefreshing && events != null)
        const SizedBox(height: 48, child: Center(child: DsRefreshBubble())),
      // 참여자 칩 + 갱신 상태
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              if (me != null) DsMemberChip(name: me.name, isMe: true),
              if (me != null && partner != null) const SizedBox(width: 8),
              if (partner != null)
                Flexible(child: DsMemberChip(name: partner.name, isMe: false)),
              const Spacer(),
              const SizedBox(width: 8),
              Text(status, style: AppText.caption, softWrap: false),
            ],
          ),
        ),
      ),
      if (!calendar.isConnected && user != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: SoloInviteCard(calendar: calendar, userId: user.id),
        ),
      if (refreshFailed)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: DsBanner(
            icon: const DsIcon(
              DsIcons.infoCircle,
              size: 20,
              color: AppColors.error,
            ),
            message: '일정을 새로 불러오지 못했어요. 마지막으로 불러온 일정을 보여드리고 있어요.',
            actionLabel: '다시 시도',
            onAction: () => _refresh(manual: true),
          ),
        ),
      // 월 이동 · 요일 · 달력 — 좌우로 밀면 달이 바뀝니다.
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
        onHorizontalDragEnd: _onSwipeEnd,
        onHorizontalDragCancel: () => _swipeDx = 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  DsIconButton(
                    icon: DsIcons.back,
                    iconSize: 22,
                    semanticLabel: '이전 달',
                    onPressed: _selected.year <= 1900 && _selected.month == 1
                        ? null
                        : () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      yearMonth(_selected),
                      textAlign: TextAlign.center,
                      style: AppText.title,
                    ),
                  ),
                  DsIconButton(
                    icon: DsIcons.forward,
                    iconSize: 22,
                    semanticLabel: '다음 달',
                    onPressed: _selected.year >= 2100 && _selected.month == 12
                        ? null
                        : () => _shiftMonth(1),
                  ),
                  const SizedBox(width: 4),
                  _TodayButton(
                    onPressed: () => setState(() => _selected = _today),
                  ),
                ],
              ),
            ),
            // 요일
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  for (final (i, label) in [
                    '일',
                    '월',
                    '화',
                    '수',
                    '목',
                    '금',
                    '토',
                  ].indexed)
                    Expanded(
                      child: SizedBox(
                        height: 22,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: ds(
                            12,
                            weight: 600,
                            color: i == 0
                                ? AppColors.error
                                : AppColors.brown500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: _monthTransition,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: Padding(
                key: ValueKey('${_selected.year}-${_selected.month}'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthGrid(
                  selected: _selected,
                  today: _today,
                  events: events ?? const [],
                  calendar: calendar,
                  userId: user?.id,
                  onSelect: (day) => setState(() => _selected = day),
                  onRangeSelected: user == null ? null : _quickAdd,
                ),
              ),
            ),
          ],
        ),
      ),
      // 선택한 날의 일정
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: initialLoading
            ? const _DayListSkeleton()
            : loadFailed
            ? _LoadFailed(
                error: state.error!,
                onRetry: () => ref.invalidate(eventsProvider(_query)),
              )
            : _DayList(
                day: _selected,
                events: (events ?? const [])
                    .where((e) => e.occursOn(_selected, _zone))
                    .toList(),
                calendar: calendar,
                userId: user?.id,
                onTap: _showDetail,
              ),
      ),
    ];

    return DsScreen(
      header: DsHeader(
        title: calendar.name,
        hideBack: widget.isHome,
        backLabel: '캘린더 목록으로',
        onBack: () => goBackOrHome(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIconButton(
              icon: DsIcons.refresh,
              iconSize: 22,
              semanticLabel: '새로고침',
              onPressed: () => _refresh(manual: true),
            ),
            if (widget.isHome) ...[
              const SizedBox(width: 4),
              DsIconButton(
                icon: DsIcons.person,
                filled: true,
                stroke: 1.9,
                semanticLabel: '계정 메뉴',
                onPressed: () => showAccountSheet(context),
              ),
            ],
          ],
        ),
      ),
      body: EdgeRefresh(
        onRefresh: () => _refresh(manual: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
      bottomPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      bottom: Row(
        children: [
          if (_isAndroid) ...[
            Expanded(
              child: DsButton(
                label: '기기 일정 가져오기',
                icon: DsIcons.import,
                variant: DsButtonVariant.secondary,
                fontSize: 15,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: initialLoading ? null : _import,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: DsButton(
              label: '일정 등록',
              icon: DsIcons.plus,
              fontSize: 15,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: initialLoading || user == null ? null : _create,
            ),
          ),
        ],
      ),
    );
  }
}

/// ‘오늘’ 작은 보조 버튼 — 36 높이 · 모서리 12 · 13px.
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
      side: const BorderSide(color: AppColors.outline, width: 1.5),
    ),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.small),
      highlightColor: AppColors.secondaryPressed,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text('오늘', style: ds(13, weight: 600, height: 1.2)),
      ),
    ),
  );
}

/// 7열 달력 — 숫자 원 30 · 모서리 14.
/// 오늘 = 버터 원, 선택 = 브라운 원 + 크림 숫자, 둘이 겹치면 브라운 원에 버터 2.5px 링.
/// 하루짜리 일정은 숫자 아래 점(5px)으로, 여러 날에 걸친 일정은 형광펜처럼
/// 날짜 위로 길게 이어지는 띠에 제목을 써서 보여 줍니다.
class MonthGrid extends StatefulWidget {
  const MonthGrid({
    super.key,
    required this.selected,
    required this.today,
    required this.events,
    required this.calendar,
    required this.userId,
    required this.onSelect,
    this.onRangeSelected,
  });
  final DateTime selected;
  final DateTime today;
  final List<CalendarEvent> events;
  final SharedCalendar calendar;

  /// 로그인한 사용자. 이 사람이 만든 일정은 ‘나’(버터), 나머지는 ‘상대’(핑크).
  final String? userId;
  final ValueChanged<DateTime> onSelect;

  /// 길게 눌러 옆으로 끌어 날짜 범위를 고른 뒤 손을 떼면 호출됩니다 (시작, 끝 포함).
  final void Function(DateTime start, DateTime end)? onRangeSelected;

  static const int maxLanes = 3;
  static const double numberBlock = 6 + 30; // 위 여백 + 숫자 원
  static const double dotsBlock = 0; // 점 대신 모든 일정을 띠로 보여 줍니다
  static const double laneHeight = 16; // 띠 14 + 간격 2
  static const double overflowHeight = 14;
  static const double rowGap = 4;

  @override
  State<MonthGrid> createState() => _MonthGridState();

  /// 일정이 차지하는 날짜 범위 (포함, UTC 날짜 컨테이너).
  static (DateTime, DateTime) dayRange(CalendarEvent e, String zone) {
    if (e.allDay) return (e.start, e.lastDay);
    final a = e.localStart(zone);
    var b = e.localEnd(zone);
    // 자정 정각에 끝나면 그 날은 포함하지 않습니다.
    if (b.hour == 0 && b.minute == 0 && b.second == 0) {
      b = b.subtract(const Duration(minutes: 1));
    }
    return (calendarDate(a), calendarDate(b));
  }
}

class _WeekLayout {
  _WeekLayout({
    required this.firstDay,
    required this.segments,
    required this.lanes,
    required this.overflow,
    required this.height,
  });
  final int firstDay;
  final List<_BarSegment> segments;
  final int lanes;

  /// 열(요일)별로 띠에 다 못 넣은 일정 수.
  final List<int> overflow;
  final double height;
}

class _MonthGridState extends State<MonthGrid> {
  DateTime? _anchor;
  DateTime? _cursor;
  List<_WeekLayout> _weeks = const [];
  int _offset = 0;
  int _days = 0;

  (DateTime, DateTime)? get _range {
    final a = _anchor, b = _cursor;
    if (a == null || b == null) return null;
    return a.isAfter(b) ? (b, a) : (a, b);
  }

  DateTime _dateOf(int day) =>
      DateTime.utc(widget.selected.year, widget.selected.month, day);

  /// 그리드 안 좌표가 가리키는 날짜 (달 밖은 가장 가까운 날로 보정).
  DateTime? _dateAt(Offset local, double width) {
    if (_weeks.isEmpty) return null;
    final col = (local.dx / (width / 7)).floor().clamp(0, 6);
    var row = _weeks.length - 1;
    var top = 0.0;
    for (var i = 0; i < _weeks.length; i++) {
      final bottom = top + _weeks[i].height;
      if (local.dy < bottom) {
        row = i;
        break;
      }
      top = bottom + MonthGrid.rowGap;
    }
    if (local.dy < 0) row = 0;
    final day = (row * 7 + col - _offset + 1).clamp(1, _days);
    return _dateOf(day);
  }

  void _startDrag(Offset local, double width) {
    final date = _dateAt(local, width);
    if (date == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = date;
      _cursor = date;
    });
  }

  void _updateDrag(Offset local, double width) {
    if (_anchor == null) return;
    final date = _dateAt(local, width);
    if (date == null || date == _cursor) return;
    HapticFeedback.selectionClick();
    setState(() => _cursor = date);
  }

  void _endDrag() {
    final range = _range;
    setState(() {
      _anchor = null;
      _cursor = null;
    });
    if (range != null) widget.onRangeSelected?.call(range.$1, range.$2);
  }

  void _cancelDrag() {
    if (_anchor == null) return;
    setState(() {
      _anchor = null;
      _cursor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final first = DateTime.utc(selected.year, selected.month);
    _offset = first.weekday % 7;
    _days = DateTime.utc(selected.year, selected.month + 1, 0).day;
    final rows = ((_offset + _days) / 7).ceil();
    final zone = widget.calendar.timezone;

    // 하루짜리든 여러 날이든 모든 일정을 제목 띠로 보여 줍니다.
    final spanning = <CalendarEvent, (DateTime, DateTime)>{
      for (final e in widget.events) e: MonthGrid.dayRange(e, zone),
    };
    // 긴 일정이 먼저 윗줄을 차지하도록 정렬합니다.
    final ordered = spanning.keys.toList()
      ..sort((a, b) {
        final ra = spanning[a]!, rb = spanning[b]!;
        final c = ra.$1.compareTo(rb.$1);
        if (c != 0) return c;
        final len = rb.$2.compareTo(ra.$2);
        if (len != 0) return len;
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });
    _weeks = [
      for (var row = 0; row < rows; row++) _layoutWeek(row, ordered, spanning),
    ];
    final range = _range;

    return Semantics(
      label: '${yearMonth(selected)} 달력. 길게 눌러 옆으로 끌면 여러 날을 고를 수 있어요',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: (d) => _startDrag(d.localPosition, width),
            onLongPressMoveUpdate: (d) => _updateDrag(d.localPosition, width),
            onLongPressEnd: (_) => _endDrag(),
            onLongPressCancel: _cancelDrag,
            child: Column(
              children: [
                for (var row = 0; row < rows; row++) ...[
                  if (row > 0) const SizedBox(height: MonthGrid.rowGap),
                  _buildWeek(_weeks[row], range),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  _WeekLayout _layoutWeek(
    int row,
    List<CalendarEvent> ordered,
    Map<CalendarEvent, (DateTime, DateTime)> spanning,
  ) {
    final firstDay = row * 7 - _offset + 1;
    final lastDay = firstDay + 6;
    // 이번 주에 걸치는 띠 조각을 레인에 배치합니다.
    final laneEnds = <int>[]; // 레인별 마지막 열
    final segments = <_BarSegment>[];
    final overflow = List<int>.filled(7, 0);
    final weekStart = _dateOf(firstDay.clamp(1, _days));
    final weekEnd = _dateOf(lastDay.clamp(1, _days));
    for (final e in ordered) {
      final (start, end) = spanning[e]!;
      if (end.isBefore(weekStart) || start.isAfter(weekEnd)) continue;
      final from = start.isBefore(weekStart) ? weekStart : start;
      final to = end.isAfter(weekEnd) ? weekEnd : end;
      final startCol = from.day - firstDay;
      final endCol = to.day - firstDay;
      var lane = laneEnds.indexWhere((last) => last < startCol);
      if (lane == -1) {
        if (laneEnds.length >= MonthGrid.maxLanes) {
          for (var c = startCol; c <= endCol; c++) {
            overflow[c]++;
          }
          continue;
        }
        laneEnds.add(endCol);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = endCol;
      }
      segments.add(
        _BarSegment(
          event: e,
          lane: lane,
          startCol: startCol,
          endCol: endCol,
          continuesBefore: from != start,
          continuesAfter: to != end,
          isMine: e.createdBy == widget.userId,
        ),
      );
    }
    final lanes = laneEnds.length;
    final height =
        MonthGrid.numberBlock +
        MonthGrid.dotsBlock +
        (lanes > 0 ? 3 + lanes * MonthGrid.laneHeight : 0) +
        (overflow.any((n) => n > 0) ? MonthGrid.overflowHeight : 0) +
        4;
    return _WeekLayout(
      firstDay: firstDay,
      segments: segments,
      lanes: lanes,
      overflow: overflow,
      height: height,
    );
  }

  Widget _buildWeek(_WeekLayout week, (DateTime, DateTime)? range) {
    final firstDay = week.firstDay;
    final height = week.height;
    final weekStart = _dateOf(firstDay.clamp(1, _days));
    final weekEnd = _dateOf((firstDay + 6).clamp(1, _days));
    int? hlStart, hlEnd;
    if (range != null &&
        !range.$2.isBefore(weekStart) &&
        !range.$1.isAfter(weekEnd)) {
      final from = range.$1.isBefore(weekStart) ? weekStart : range.$1;
      final to = range.$2.isAfter(weekEnd) ? weekEnd : range.$2;
      hlStart = from.day - firstDay;
      hlEnd = to.day - firstDay;
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colWidth = constraints.maxWidth / 7;
          return Stack(
            children: [
              if (hlStart != null && hlEnd != null)
                Positioned(
                  left: hlStart * colWidth + 2,
                  width: (hlEnd - hlStart + 1) * colWidth - 4,
                  top: 1,
                  height: height - 2,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.butter.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.butterDeep,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = firstDay + col;
                          if (day < 1 || day > _days) {
                            return SizedBox(height: height);
                          }
                          final date = _dateOf(day);
                          var count = 0;
                          for (final s in week.segments) {
                            if (col >= s.startCol && col <= s.endCol) count++;
                          }
                          return _DayCell(
                            date: date,
                            height: height,
                            isToday: date == widget.today,
                            isSelected: date == widget.selected,
                            isSunday: col == 0,
                            eventCount: count + week.overflow[col],
                            onTap: () => widget.onSelect(date),
                          );
                        },
                      ),
                    ),
                ],
              ),
              for (final s in week.segments)
                Positioned(
                  left: s.startCol * colWidth + (s.continuesBefore ? 0 : 2),
                  width:
                      (s.endCol - s.startCol + 1) * colWidth -
                      (s.continuesBefore ? 0 : 2) -
                      (s.continuesAfter ? 0 : 2),
                  top:
                      MonthGrid.numberBlock +
                      MonthGrid.dotsBlock +
                      3 +
                      s.lane * MonthGrid.laneHeight,
                  height: MonthGrid.laneHeight - 2,
                  child: IgnorePointer(child: _EventBar(segment: s)),
                ),
              for (var col = 0; col < 7; col++)
                if (week.overflow[col] > 0)
                  Positioned(
                    left: col * colWidth + 4,
                    width: colWidth - 8,
                    top:
                        MonthGrid.numberBlock +
                        MonthGrid.dotsBlock +
                        3 +
                        week.lanes * MonthGrid.laneHeight,
                    height: MonthGrid.overflowHeight,
                    child: IgnorePointer(
                      child: Text(
                        '+${week.overflow[col]}',
                        style: ds(10.5, weight: 600, color: AppColors.brown500),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _BarSegment {
  const _BarSegment({
    required this.event,
    required this.lane,
    required this.startCol,
    required this.endCol,
    required this.continuesBefore,
    required this.continuesAfter,
    required this.isMine,
  });
  final CalendarEvent event;
  final int lane;
  final int startCol;
  final int endCol;
  final bool continuesBefore;
  final bool continuesAfter;
  final bool isMine;
}

/// 형광펜 띠 — 나는 버터, 상대는 핑크. 시작·끝 쪽만 둥글게.
class _EventBar extends StatelessWidget {
  const _EventBar({required this.segment});
  final _BarSegment segment;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(5);
    return Semantics(
      label: '${segment.event.title}, 여러 날 일정',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: segment.isMine
              ? AppColors.butter.withValues(alpha: .55)
              : AppColors.pink.withValues(alpha: .75),
          borderRadius: BorderRadius.horizontal(
            left: segment.continuesBefore ? Radius.zero : r,
            right: segment.continuesAfter ? Radius.zero : r,
          ),
        ),
        child: Text(
          segment.event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: ds(
            11,
            weight: 600,
            height: 1,
            color: segment.isMine
                ? AppColors.onButterContainer
                : AppColors.onPinkContainer,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.height,
    required this.isToday,
    required this.isSelected,
    required this.isSunday,
    required this.eventCount,
    required this.onTap,
  });
  final DateTime date;
  final double height;
  final bool isToday, isSelected, isSunday;
  final int eventCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final who = eventCount > 0 ? ', 일정 $eventCount개' : '';
    final numberColor = isSelected
        ? AppColors.cream
        : isSunday
        ? AppColors.error
        : AppColors.brown900;
    return Semantics(
      label:
          '${monthDay(date)}${isToday ? ', 오늘' : ''}${isSelected ? ', 선택됨' : ''}$who',
      selected: isSelected,
      button: true,
      child: InkWell(
        key: ValueKey('day-${dateText(date)}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        highlightColor: AppColors.secondaryPressed,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 6),
              Container(
                width: 30,
                height: 30,
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppColors.brown900,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: AppColors.butter, width: 2.5)
                            : null,
                      )
                    : isToday
                    ? const BoxDecoration(
                        color: AppColors.butter,
                        shape: BoxShape.circle,
                      )
                    : null,
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: ds(
                    14,
                    weight: isToday || isSelected ? 700 : 500,
                    color: numberColor,
                    height: 1,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선택한 날의 일정 목록 (헤더 + 카드 또는 빈 안내).
class _DayList extends StatelessWidget {
  const _DayList({
    required this.day,
    required this.events,
    required this.calendar,
    required this.userId,
    required this.onTap,
  });
  final DateTime day;
  final List<CalendarEvent> events;
  final SharedCalendar calendar;
  final String? userId;
  final ValueChanged<CalendarEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final members = {for (final m in calendar.members) m.id: m};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(monthDayWeekdayLong(day), style: ds(15, weight: 700)),
            const SizedBox(width: 8),
            DsHint(events.isEmpty ? '일정 없음' : '일정 ${events.length}개'),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
            child: Column(
              children: [
                const DsSmile(size: 56, color: AppColors.butterContainer),
                const SizedBox(height: 8),
                Text('이 날은 아직 일정이 없어요', style: ds(15, weight: 600)),
                const SizedBox(height: 8),
                const DsHint("아래 '일정 등록'으로 둘의 계획을 남겨 보세요."),
              ],
            ),
          )
        else
          for (final event in events) ...[
            EventCard(
              event: event,
              author: members[event.createdBy],
              isMine: event.createdBy == userId,
              zone: calendar.timezone,
              onTap: () => onTap(event),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// 일정 카드 — 모서리 18 · 패딩 12/14 · gap 6 · 작성자 칩 22 + 시간, 제목 2줄, 설명 1줄.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.author,
    required this.isMine,
    required this.zone,
    required this.onTap,
  });
  final CalendarEvent event;
  final CalendarMember? author;
  final bool isMine;
  final String zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final span = event.allDaySpan();
    final description = event.description?.trim() ?? '';
    return DsCard(
      radius: AppRadius.eventCard,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsMemberChip(
                name: author?.name ?? '사용자',
                isMe: isMine,
                small: true,
                suffixMe: false,
              ),
              Text(
                event.timeLabel(zone),
                style: ds(13, weight: 600, color: AppColors.brown700),
              ),
              if (span != null) DsHint(span),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ds(16, weight: 600, height: 1.35),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            DsHint(description.split('\n').first, maxLines: 1),
          ],
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: DsCard(
      color: AppColors.cream,
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: DsStateView(
        art: const DsIconTile(icon: DsIcons.offline),
        title: '일정을 불러오지 못했어요',
        description: extractErrorMessage(error),
        action: DsButton(
          label: '일정 다시 불러오기',
          height: 44,
          fontSize: 14,
          onPressed: onRetry,
        ),
      ),
    ),
  );
}

/// F3. 최초 로딩 — 목록 자리의 스켈레톤.
class _DayListSkeleton extends StatelessWidget {
  const _DayListSkeleton();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          DsSkeleton(width: 160, height: 18),
          SizedBox(width: 8),
          DsSkeleton(width: 48, height: 14),
        ],
      ),
      SizedBox(height: 10),
      DsSkeleton(height: 96, radius: AppRadius.eventCard),
      SizedBox(height: 10),
      DsSkeleton(height: 96, radius: AppRadius.eventCard),
      SizedBox(height: 10),
      DsLoadingLine('일정을 불러오고 있어요'),
    ],
  );
}

/// 캘린더 정보를 아직 못 받았을 때의 전체 스켈레톤.
class ScheduleSkeleton extends StatelessWidget {
  const ScheduleSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    children: const [
      Row(
        children: [
          DsSkeleton(width: 84, height: 26, radius: AppRadius.pill),
          SizedBox(width: 8),
          DsSkeleton(width: 64, height: 26, radius: AppRadius.pill),
        ],
      ),
      SizedBox(height: 22),
      Center(child: DsSkeleton(width: 120, height: 22)),
      SizedBox(height: 18),
      DsSkeleton(height: 260, radius: AppRadius.card),
      SizedBox(height: 14),
      _DayListSkeleton(),
    ],
  );
}
