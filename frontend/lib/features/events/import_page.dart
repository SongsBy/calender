import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../services/device_calendar_service.dart';
import '../../shared/ds.dart';
import 'event_labels.dart';

final deviceCalendarProvider = Provider((ref) => DeviceCalendarService());

enum ImportStep { permission, calendars, range, select, confirm, done }

/// I. Android 기기 일정 가져오기 — 권한 → 캘린더 선택 → 기간 → 일정 선택 → 확인 → 완료.
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, required this.calendarId, this.calendar});
  final String calendarId;
  final SharedCalendar? calendar;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  static const _maxDays = 93;
  static const _maxSelection = 100;

  ImportStep _step = ImportStep.permission;
  bool _busy = false;
  bool _denied = false;
  String? _error;
  List<Map<String, dynamic>> _calendars = const [];
  String? _deviceCalendarId;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  List<DeviceEvent> _events = const [];
  final _selected = <String>{};
  bool _consent = false;
  int _created = 0;
  int _skipped = 0;

  DeviceCalendarService get _service => ref.read(deviceCalendarProvider);
  SharedCalendar? get _calendar =>
      widget.calendar ??
      ref.read(calendarDetailProvider(widget.calendarId)).value;
  String get _zone => _calendar?.timezone ?? 'Asia/Seoul';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, 1);
    _rangeEnd = DateTime(now.year, now.month + 1, 0);
  }

  int get _rangeDays => _rangeEnd.difference(_rangeStart).inDays + 1;

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PlatformException
              ? (e.message ?? '처리하지 못했어요.')
              : extractErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermission() => _perform(() async {
    final allowed = await _service.requestPermission();
    if (!mounted) return;
    setState(() => _denied = !allowed);
    if (!allowed) return;
    final values = await _service.calendars();
    if (!mounted) return;
    setState(() {
      _calendars = values;
      _deviceCalendarId = values.isEmpty ? null : values.first['id'] as String;
      _events = const [];
      _selected.clear();
      _step = ImportStep.calendars;
    });
  });

  Future<void> _reloadCalendars() => _perform(() async {
    final values = await _service.calendars();
    if (!mounted) return;
    setState(() {
      _calendars = values;
      _deviceCalendarId = values.isEmpty ? null : values.first['id'] as String;
    });
  });

  Future<void> _query() => _perform(() async {
    final values = await _service.events(
      _deviceCalendarId!,
      _rangeStart,
      DateTime(_rangeEnd.year, _rangeEnd.month, _rangeEnd.day + 1),
    );
    if (!mounted) return;
    setState(() {
      _events = values;
      _selected.clear();
      _consent = false;
      _step = ImportStep.select;
    });
  });

  Future<void> _upload() => _perform(() async {
    final id = await _service.installationId();
    final response = await ref
        .read(dioProvider)
        .post<Map<String, dynamic>>(
          '${AppConfig.apiPrefix}/calendars/${widget.calendarId}/events/import',
          data: {
            'installation_id': id,
            'events': _events
                .where((e) => _selected.contains(e.key))
                .map((e) => e.toJson())
                .toList(),
          },
        );
    ref.invalidate(eventsProvider);
    if (!mounted) return;
    setState(() {
      _created = (response.data!['created_count'] as num?)?.toInt() ?? 0;
      _skipped = (response.data!['skipped_count'] as num?)?.toInt() ?? 0;
      _step = ImportStep.done;
    });
  });

  Future<void> _pickRangeDate(bool start) async {
    final value = start ? _rangeStart : _rangeEnd;
    final chosen = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: start ? '시작 날짜' : '마지막 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      final date = DateTime(chosen.year, chosen.month, chosen.day);
      if (start) {
        _rangeStart = date;
        if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = _rangeStart;
      } else {
        _rangeEnd = date;
        if (_rangeEnd.isBefore(_rangeStart)) _rangeStart = _rangeEnd;
      }
      _error = null;
    });
  }

  void _setRange(DateTime start, DateTime end) => setState(() {
    _rangeStart = start;
    _rangeEnd = end;
    _error = null;
  });

  void _back() {
    switch (_step) {
      case ImportStep.permission:
        Navigator.of(context).pop(false);
      case ImportStep.calendars:
        setState(() => _step = ImportStep.permission);
      case ImportStep.range:
        setState(() => _step = ImportStep.calendars);
      case ImportStep.select:
        setState(() => _step = ImportStep.range);
      case ImportStep.confirm:
        setState(() => _step = ImportStep.select);
      case ImportStep.done:
        Navigator.of(context).pop(true);
    }
  }

  void _close() => Navigator.of(context).pop(_step == ImportStep.done);

  @override
  Widget build(BuildContext context) {
    final stepLabel = switch (_step) {
      ImportStep.permission => '1/5 단계 · 권한',
      ImportStep.calendars => '2/5 단계 · 캘린더 선택',
      ImportStep.range => '3/5 단계 · 기간 선택',
      ImportStep.select => '4/5 단계 · 일정 선택',
      ImportStep.confirm => '5/5 단계 · 확인',
      ImportStep.done => null,
    };
    final (body, bottom) = switch (_step) {
      ImportStep.permission => _permission(),
      ImportStep.calendars =>
        _calendars.isEmpty ? _noCalendars() : _pickCalendar(),
      ImportStep.range => _range(),
      ImportStep.select => _events.isEmpty ? _noResults() : _select(),
      ImportStep.confirm => _confirm(),
      ImportStep.done => _done(),
    };
    return DsScreen(
      canPop: !_busy,
      onPopInvoked: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      header: DsHeader(
        title: '기기 일정 가져오기',
        hideBack: _step == ImportStep.done,
        backEnabled: !_busy,
        onBack: _back,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stepLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DsHint(stepLabel),
            ),
          Expanded(child: body),
        ],
      ),
      bottom: bottom,
    );
  }

  // --- I1 · I2 -------------------------------------------------------------
  (Widget, Widget) _permission() => (
    DsBody(
      children: [
        const Center(child: DsImportArt()),
        Text(
          '휴대폰 캘린더를 읽을 수 있게 허용해 주세요',
          style: ds(22, weight: 700, letterSpacing: -0.4, height: 1.35),
        ),
        Text(
          '기기에 저장된 일정을 불러와 직접 고를 수 있어요. 허용해도 자동으로 공유되지는 않아요.',
          style: ds(14.5, height: 1.55),
        ),
        if (_denied)
          const DsBanner(
            kind: DsBannerKind.warn,
            message: '캘린더 읽기 권한이 꺼져 있어요. 허용해야 기기 일정을 볼 수 있어요.',
          ),
        if (_error != null) DsBanner(message: _error!),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in const [
              '읽기만 해요. 휴대폰 일정을 바꾸거나 지우지 않아요',
              '내가 고른 일정만 공유 캘린더에 복사돼요',
              '원본이 바뀌어도 자동으로 따라가지 않아요',
            ]) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: DsIcon(
                      DsIcons.checkCircle,
                      size: 20,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: ds(14, height: 1.5))),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    ),
    DsActions(
      children: [
        DsButton(
          label: _denied ? '다시 요청' : '권한 허용하고 계속',
          loadingLabel: '확인 중…',
          loading: _busy,
          onPressed: _requestPermission,
        ),
        if (_denied)
          DsButton(
            label: '앱 설정에서 허용하기',
            icon: DsIcons.externalLink,
            variant: DsButtonVariant.secondary,
            onPressed: _busy ? null : () => _perform(_service.settings),
          ),
        DsButton(
          label: '취소',
          variant: DsButtonVariant.text,
          onPressed: _busy ? null : _close,
        ),
      ],
    ),
  );

  // --- I3 · I4 -------------------------------------------------------------
  (Widget, Widget) _pickCalendar() => (
    DsBody(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: DsHint('일정을 불러올 기기 캘린더를 골라 주세요. 하나만 선택할 수 있어요.'),
        ),
        if (_error != null) DsBanner(message: _error!),
        DsCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            children: [
              for (final (i, c) in _calendars.indexed)
                _radioRow(
                  selected: _deviceCalendarId == c['id'],
                  divider: i > 0,
                  title: (c['name'] as String?)?.trim().isNotEmpty == true
                      ? c['name'] as String
                      : '이름 없는 캘린더',
                  subtitle: [
                    if (c['account'] != null) '${c['account']}',
                    if (c['count'] != null) '일정 ${c['count']}개',
                  ].join(' · '),
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _deviceCalendarId = c['id'] as String;
                        }),
                ),
            ],
          ),
        ),
      ],
    ),
    DsActions(
      children: [
        DsButton(
          label: '다음',
          onPressed: _busy || _deviceCalendarId == null
              ? null
              : () => setState(() => _step = ImportStep.range),
        ),
        DsButton(
          label: '취소',
          variant: DsButtonVariant.text,
          onPressed: _busy ? null : _close,
        ),
      ],
    ),
  );

  Widget _radioRow({
    required bool selected,
    required bool divider,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    highlightColor: AppColors.secondaryPressed,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: divider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outlineVariant)),
            )
          : null,
      child: Row(
        children: [
          DsRadio(selected: selected, onTap: onTap),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ds(15, weight: 600, height: 1.35)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  DsHint(subtitle),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  (Widget, Widget) _noCalendars() => (
    Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DsEmptyCalendarArt(width: 126, sad: true),
            const SizedBox(height: 18),
            Text(
              '기기에서 캘린더를 찾지 못했어요',
              textAlign: TextAlign.center,
              style: ds(20, weight: 700, letterSpacing: -0.4, height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              '휴대폰 캘린더 앱에 계정이 추가되어 있는지 확인한 뒤 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: ds(14, color: AppColors.brown500, height: 1.55),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              DsBanner(message: _error!),
            ],
          ],
        ),
      ),
    ),
    DsActions(
      children: [
        DsButton(
          label: '다시 확인',
          loadingLabel: '확인 중…',
          variant: DsButtonVariant.secondary,
          loading: _busy,
          onPressed: _reloadCalendars,
        ),
        DsButton(
          label: '닫기',
          variant: DsButtonVariant.text,
          onPressed: _busy ? null : _close,
        ),
      ],
    ),
  );

  // --- I5 ------------------------------------------------------------------
  (Widget, Widget) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tooLong = _rangeDays > _maxDays;
    final selectedCalendar = _calendars
        .cast<Map<String, dynamic>?>()
        .firstWhere((c) => c!['id'] == _deviceCalendarId, orElse: () => null);
    return (
      DsBody(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const DsHint('불러올 캘린더'),
                DsChip(
                  label: (selectedCalendar?['name'] as String?) ?? '기기 캘린더',
                ),
              ],
            ),
          ),
          if (_error != null) DsBanner(message: _error!),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: DsLabel('시작 날짜'),
              ),
              const SizedBox(height: 6),
              DsPickerField(
                value: fullDate(_rangeStart),
                icon: DsIcons.calendar,
                enabled: !_busy,
                error: tooLong,
                onTap: () => _pickRangeDate(true),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: DsLabel('마지막 날짜'),
              ),
              const SizedBox(height: 6),
              DsPickerField(
                value: fullDate(_rangeEnd),
                icon: DsIcons.calendar,
                enabled: !_busy,
                error: tooLong,
                onTap: () => _pickRangeDate(false),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: DsHint('빠른 선택'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickChip(
                    label: '이번 달',
                    onTap: () => _setRange(
                      DateTime(today.year, today.month, 1),
                      DateTime(today.year, today.month + 1, 0),
                    ),
                  ),
                  _QuickChip(
                    label: '다음 달',
                    onTap: () => _setRange(
                      DateTime(today.year, today.month + 1, 1),
                      DateTime(today.year, today.month + 2, 0),
                    ),
                  ),
                  _QuickChip(
                    label: '앞으로 30일',
                    onTap: () =>
                        _setRange(today, today.add(const Duration(days: 29))),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${monthDay(_rangeStart)} – ${monthDay(_rangeEnd)} · $_rangeDays일',
                  style: ds(
                    13.5,
                    weight: 600,
                    color: tooLong ? AppColors.errorText : AppColors.brown700,
                  ),
                ),
                const SizedBox(height: 4),
                tooLong
                    ? const DsErrorText('한 번에 최대 93일까지 조회할 수 있어요. 기간을 줄여 주세요.')
                    : const DsHint('한 번에 최대 93일까지 조회할 수 있어요.'),
              ],
            ),
          ),
        ],
      ),
      DsActions(
        children: [
          DsButton(
            label: '일정 조회',
            loadingLabel: '조회 중…',
            loading: _busy,
            onPressed: tooLong ? null : _query,
          ),
          DsButton(
            label: '취소',
            variant: DsButtonVariant.text,
            onPressed: _busy ? null : _close,
          ),
        ],
      ),
    );
  }

  // --- I6 · I7 -------------------------------------------------------------
  String get _summary {
    final name =
        _calendars.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c!['id'] == _deviceCalendarId,
              orElse: () => null,
            )?['name']
            as String?;
    return '${name ?? '기기 캘린더'} · ${monthDay(_rangeStart)} – ${monthDay(_rangeEnd)} · 일정 ${_events.length}개';
  }

  (Widget, Widget) _select() {
    final allSelected =
        _selected.length == _events.length || _selected.length >= _maxSelection;
    return (
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: DsHint(_summary),
                  ),
                ),
                const SizedBox(width: 8),
                DsChip(
                  label: '${_selected.length} / $_maxSelection 선택',
                  variant: DsChipVariant.me,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DsButton(
                label: allSelected ? '전체 해제' : '전체 선택',
                variant: DsButtonVariant.text,
                height: 40,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(
                              _events.take(_maxSelection).map((e) => e.key),
                            );
                        }
                      }),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: DsBanner(message: _error!),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              children: [
                DsCard(
                  padding: EdgeInsets.zero,
                  clip: true,
                  child: Column(
                    children: [
                      for (final (i, e) in _events.indexed)
                        _eventRow(e, divider: i > 0),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: DsHint('한 번에 최대 100개까지 가져올 수 있어요.'),
                ),
              ],
            ),
          ),
        ],
      ),
      DsActions(
        children: [
          DsButton(
            label: '선택한 ${_selected.length}개 가져오기',
            onPressed: _busy || _selected.isEmpty
                ? null
                : () => setState(() {
                    _consent = false;
                    _step = ImportStep.confirm;
                  }),
          ),
        ],
      ),
    );
  }

  Widget _eventRow(DeviceEvent e, {required bool divider}) {
    final event = e.event;
    final checked = _selected.contains(e.key);
    final full = !checked && _selected.length >= _maxSelection;
    final description = event.description?.trim() ?? '';
    void toggle() => setState(() {
      if (checked) {
        _selected.remove(e.key);
      } else if (!full) {
        _selected.add(e.key);
      }
    });
    return InkWell(
      onTap: _busy ? null : toggle,
      highlightColor: AppColors.secondaryPressed,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: divider
            ? const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: DsCheckbox(
                value: checked,
                onChanged: _busy || full ? null : (_) => toggle(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ds(15, weight: 600, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.whenLabel(_zone),
                    style: ds(13, color: AppColors.brown700, height: 1.4),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    DsHint(description.split('\n').first, maxLines: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Widget, Widget) _noResults() => (
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: DsHint(_summary),
                ),
              ),
              const SizedBox(width: 8),
              const DsChip(label: '0 / 100 선택', variant: DsChipVariant.me),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DsEmptyCalendarArt(width: 126, sad: true),
                  const SizedBox(height: 18),
                  Text(
                    '이 기간에는 일정이 없어요',
                    textAlign: TextAlign.center,
                    style: ds(
                      20,
                      weight: 700,
                      letterSpacing: -0.4,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${monthDay(_rangeStart)} – ${monthDay(_rangeEnd)} 사이에 저장된 일정을 찾지 못했어요. 기간을 바꿔 다시 조회해 보세요.',
                    textAlign: TextAlign.center,
                    style: ds(14, color: AppColors.brown500, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    DsActions(
      children: [
        DsButton(
          label: '기간 다시 선택',
          variant: DsButtonVariant.secondary,
          onPressed: () => setState(() => _step = ImportStep.range),
        ),
        DsButton(label: '닫기', variant: DsButtonVariant.text, onPressed: _close),
      ],
    ),
  );

  // --- I8 ------------------------------------------------------------------
  (Widget, Widget) _confirm() {
    final chosen = _events.where((e) => _selected.contains(e.key)).toList();
    final user = ref.read(currentUserProvider);
    final partner = user == null ? null : _calendar?.partnerOf(user.id);
    final partnerLabel = partner == null ? '상대방' : '상대방(${partner.name})';
    return (
      DsBody(
        children: [
          Text(
            "이 일정 ${chosen.length}개를 '${_calendar?.name ?? '공유 캘린더'}'에 복사할까요?",
            style: ds(22, weight: 700, letterSpacing: -0.4, height: 1.35),
          ),
          if (_error != null) DsBanner(message: _error!),
          DsCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              children: [
                for (final (i, e) in chosen.indexed)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: i > 0
                        ? const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.outlineVariant),
                            ),
                          )
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DsIcon(
                          DsIcons.checkCircle,
                          size: 20,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.event.title,
                                style: ds(15, weight: 600, height: 1.35),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.event.whenLabel(_zone),
                                style: ds(
                                  13,
                                  color: AppColors.brown700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          DsBanner(
            kind: DsBannerKind.warn,
            message: '선택한 일정의 제목·시간·설명이 $partnerLabel에게 공개됩니다.',
          ),
          InkWell(
            onTap: _busy ? null : () => setState(() => _consent = !_consent),
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DsCheckbox(
                      value: _consent,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _consent = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '확인했어요. 공유 캘린더에 복사합니다.',
                      style: ds(14.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: DsHint(
              '복사된 일정은 이 앱 안에서만 바뀌어요. 휴대폰 원본 일정이 바뀌거나 지워져도 자동으로 반영되지 않아요.',
            ),
          ),
        ],
      ),
      DsActions(
        children: [
          DsButton(
            label: '공유 캘린더에 추가',
            loadingLabel: '추가하는 중…',
            loading: _busy,
            onPressed: _consent ? _upload : null,
          ),
          DsButton(
            label: '돌아가기',
            variant: DsButtonVariant.text,
            onPressed: _busy
                ? null
                : () => setState(() => _step = ImportStep.select),
          ),
        ],
      ),
    );
  }

  // --- I9 ------------------------------------------------------------------
  (Widget, Widget) _done() => (
    Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: DsEmptyCalendarArt(width: 120)),
            const SizedBox(height: 20),
            Text(
              '일정을 가져왔어요',
              textAlign: TextAlign.center,
              style: ds(24, weight: 700, letterSpacing: -0.4, height: 1.35),
            ),
            const SizedBox(height: 14),
            DsCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('가져온 일정', style: ds(14, height: 1.4)),
                        ),
                        Text('$_created개', style: ds(15, weight: 600)),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('중복으로 건너뛴 일정', style: ds(14, height: 1.4)),
                              const SizedBox(height: 2),
                              const DsHint('이미 같은 제목·시간의 일정이 있었어요'),
                            ],
                          ),
                        ),
                        Text(
                          '$_skipped개',
                          style: ds(13, color: AppColors.brown500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: DsHint(
                '휴대폰 원본 일정은 그대로 남아 있어요. 가져온 일정은 공유 달력에서 수정·삭제할 수 있어요.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
    DsActions(
      children: [
        DsButton(
          label: '달력으로 돌아가기',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

/// 빠른 선택 칩 — 36 높이.
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.fillDisabled,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: ds(13.5, weight: 600, color: const Color(0xFF6B4F3E)),
        ),
      ),
    ),
  );
}
