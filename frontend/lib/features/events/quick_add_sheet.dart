import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../models/event.dart';
import '../../providers/events_provider.dart';
import '../../shared/ds.dart';

/// 일정 등록·수정 시트. 제목만 받고, ‘시간 설정’과 ‘메모’는 눌러야 펼쳐집니다.
/// 달력에서 길게 눌러 고른 범위, ‘일정 등록’ 버튼, 상세 화면의 ‘수정’이 모두 이 시트를 씁니다.
Future<bool?> showQuickAddSheet(
  BuildContext context, {
  required SharedCalendar calendar,
  DateTime? start,
  DateTime? end,
  CalendarEvent? event,
}) => showDsSheet<bool>(
  context,
  builder: (_) =>
      QuickAddSheet(calendar: calendar, start: start, end: end, event: event),
);

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    required this.calendar,
    this.start,
    this.end,
    this.event,
  }) : assert(event != null || (start != null && end != null));
  final SharedCalendar calendar;

  /// 새 일정의 포함 범위 (UTC 날짜 컨테이너). `event`가 있으면 무시됩니다.
  final DateTime? start;
  final DateTime? end;

  /// 있으면 수정 모드.
  final CalendarEvent? event;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  static const _descriptionMax = 5000;
  final _title = TextEditingController();
  final _description = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = true;
  bool _showTime = false;
  bool _showMemo = false;
  bool _pending = false;
  String? _titleError;
  String? _error;

  bool get _isEdit => widget.event != null;
  String get _zone => widget.calendar.timezone;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) {
      _start = widget.start!;
      _end = widget.end!;
    } else {
      _title.text = event.title;
      _description.text = event.description ?? '';
      _allDay = event.allDay;
      final start = event.localStart(_zone);
      final end = event.localEnd(_zone);
      _start = calendarDate(start);
      _end = calendarDate(_allDay ? event.lastDay : end);
      if (!_allDay) {
        _startTime = TimeOfDay.fromDateTime(start);
        _endTime = TimeOfDay.fromDateTime(end);
      }
      _showMemo = _description.text.trim().isNotEmpty;
    }
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  int get _dayCount => _end.difference(_start).inDays + 1;

  String get _rangeLabel => _dayCount == 1
      ? fullDate(_start)
      : '${monthDayWeekday(_start)} – ${monthDayWeekday(_end)} · $_dayCount일';

  String get _timeSummary =>
      _allDay ? '종일' : '${_fmt(_startTime)} – ${_fmt(_endTime)}';

  static String _fmt(TimeOfDay t) =>
      timeKo(DateTime(2000, 1, 1, t.hour, t.minute));

  Future<void> _pickDate(bool start) async {
    final value = start ? _start : _end;
    final chosen = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: start ? '시작 날짜' : (_allDay ? '마지막 날짜' : '종료 날짜'),
      cancelText: '취소',
      confirmText: '선택',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      final date = calendarDate(chosen);
      if (start) {
        final shift = date.difference(_start);
        _start = date;
        _end = calendarDate(_end.add(shift));
      } else {
        _end = date;
        if (_end.isBefore(_start)) _start = _end;
      }
      _error = null;
    });
  }

  Future<void> _pickTime(bool start) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      helpText: start ? '시작 시간' : '종료 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (start) {
        final before = _startTime.hour * 60 + _startTime.minute;
        _startTime = chosen;
        // 시작을 옮기면 종료도 같은 간격만큼 따라갑니다 (같은 날일 때).
        if (_start == _end) {
          final length = _endTime.hour * 60 + _endTime.minute - before;
          final total = chosen.hour * 60 + chosen.minute + length;
          if (length > 0 && total < 24 * 60) {
            _endTime = TimeOfDay(hour: total ~/ 60, minute: total % 60);
          }
        }
      } else {
        _endTime = chosen;
      }
      _error = null;
    });
  }

  /// 수정 중 날짜·시간을 그대로 두면 원래 시각(초 단위까지)을 유지합니다.
  DateTime _instant(DateTime date, TimeOfDay time, {required bool isStart}) {
    final existing = widget.event;
    if (existing != null && !existing.allDay) {
      final local = isStart
          ? existing.localStart(_zone)
          : existing.localEnd(_zone);
      if (calendarDate(local) == date &&
          local.hour == time.hour &&
          local.minute == time.minute) {
        return isStart ? existing.start : existing.end;
      }
    }
    final local = tz.TZDateTime(
      calendarZone(_zone),
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (local.hour != time.hour || local.minute != time.minute) {
      throw const FormatException('시간대 변경으로 존재하지 않는 시간이에요. 다른 시간을 선택해 주세요.');
    }
    return local.toUtc();
  }

  Future<void> _save() async {
    if (_pending) return;
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty ? '제목을 입력해 주세요.' : null;
      _error = null;
    });
    if (title.isEmpty) return;
    DateTime start, end;
    try {
      start = _allDay ? _start : _instant(_start, _startTime, isStart: true);
      end = _allDay
          ? _end.add(const Duration(days: 1))
          : _instant(_end, _endTime, isStart: false);
    } on FormatException catch (e) {
      setState(() {
        _error = e.message;
        _showTime = true;
      });
      return;
    }
    if (!end.isAfter(start)) {
      setState(() {
        _error = _allDay
            ? '마지막 날짜는 시작 날짜보다 빠를 수 없어요.'
            : '종료는 시작보다 늦어야 해요. 시작 ${_fmt(_startTime)}보다 이른 시간이에요.';
        _showTime = true;
      });
      return;
    }
    setState(() => _pending = true);
    try {
      await ref
          .read(eventsServiceProvider)
          .save(
            widget.calendar.id,
            EventDraft(
              title: title,
              description: _description.text,
              allDay: _allDay,
              start: start,
              end: end,
            ),
            eventId: widget.event?.id,
          );
      if (!mounted) return;
      showDsSnack(context, '일정을 저장했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = isConnectionError(e)
              ? '저장하지 못했어요. 입력한 내용은 그대로 남아 있으니 다시 시도해 주세요.'
              : extractErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final memo = _description.text;
    return PopScope(
      canPop: !_pending,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? '일정 수정' : '일정 추가', style: AppText.title),
                        const SizedBox(height: 2),
                        DsHint(_rangeLabel),
                      ],
                    ),
                  ),
                  DsIconButton(
                    icon: DsIcons.close,
                    iconSize: 22,
                    semanticLabel: '닫기',
                    onPressed: _pending
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DsTextField(
                controller: _title,
                label: '제목',
                required: true,
                hint: '예: 한강 피크닉',
                error: _titleError,
                enabled: !_pending,
                autofocus: !_isEdit,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
              const SizedBox(height: 12),
              _section(
                icon: DsIcons.clock,
                label: '시간 설정',
                summary: _timeSummary,
                expanded: _showTime,
                onToggle: () => setState(() => _showTime = !_showTime),
                child: _timeFields(),
              ),
              const SizedBox(height: 10),
              _section(
                icon: DsIcons.edit,
                label: '메모',
                summary: memo.trim().isEmpty
                    ? '없음'
                    : memo.trim().split('\n').first,
                expanded: _showMemo,
                onToggle: () => setState(() => _showMemo = !_showMemo),
                child: DsTextField(
                  controller: _description,
                  hint: '함께 알아두면 좋은 내용을 적어 주세요',
                  counter:
                      '${memo.characters.length} / ${thousands(_descriptionMax)}',
                  enabled: !_pending,
                  maxLength: _descriptionMax,
                  minLines: 2,
                  maxLines: 5,
                  minHeight: 72,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                DsBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: DsButton(
                      label: '취소',
                      variant: DsButtonVariant.secondary,
                      onPressed: _pending
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 16,
                    child: DsButton(
                      label: '저장',
                      loadingLabel: '저장 중…',
                      loading: _pending,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 접히는 탭 — 누르기 전에는 요약 한 줄만, 누르면 내용이 펼쳐집니다.
  Widget _section({
    required String icon,
    required String label,
    required String summary,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) => DsCard(
    radius: AppRadius.eventCard,
    shadow: false,
    padding: EdgeInsets.zero,
    clip: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pending ? null : onToggle,
          highlightColor: AppColors.secondaryPressed,
          child: Semantics(
            button: true,
            expanded: expanded,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  DsIcon(
                    icon,
                    size: 20,
                    color: AppColors.brown700,
                    stroke: 1.8,
                  ),
                  const SizedBox(width: 10),
                  Text(label, style: ds(15, weight: 600, height: 1.35)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ds(13, weight: 600, color: AppColors.brown700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? .25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const DsIcon(
                      DsIcons.forward,
                      size: 18,
                      color: AppColors.brown700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  child: child,
                ),
        ),
      ],
    ),
  );

  Widget _timeFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('종일 일정', style: ds(15, weight: 600)),
                const SizedBox(height: 2),
                DsHint(_allDay ? '시간 없이 날짜만 공유돼요' : '끄면 시작·종료 시간을 정할 수 있어요'),
              ],
            ),
          ),
          DsSwitch(
            value: _allDay,
            semanticLabel: '종일 일정',
            onChanged: _pending
                ? null
                : (v) => setState(() {
                    _allDay = v;
                    _error = null;
                  }),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _dateTimeRow(start: true),
      const SizedBox(height: 10),
      _dateTimeRow(start: false),
    ],
  );

  Widget _dateTimeRow({required bool start}) {
    final date = start ? _start : _end;
    final time = start ? _startTime : _endTime;
    final label = start
        ? (_allDay ? '시작 날짜' : '시작')
        : (_allDay ? '마지막 날짜' : '종료');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4), child: DsLabel(label)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 140,
              child: DsPickerField(
                value: monthDayWeekday(date),
                icon: DsIcons.calendar,
                enabled: !_pending,
                onTap: () => _pickDate(start),
              ),
            ),
            if (!_allDay) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 100,
                child: DsPickerField(
                  value: _fmt(time),
                  icon: DsIcons.clock,
                  enabled: !_pending,
                  onTap: () => _pickTime(start),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
