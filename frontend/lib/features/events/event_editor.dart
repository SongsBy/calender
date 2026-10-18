import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../models/event.dart';
import '../../providers/events_provider.dart';
import '../../shared/widgets.dart';

Future<bool?> showEventEditor(
  BuildContext context, {
  required SharedCalendar calendar,
  required DateTime day,
  CalendarEvent? event,
  bool readOnly = false,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EventEditor(
    calendar: calendar,
    day: day,
    event: event,
    readOnly: readOnly,
  ),
);

class EventEditor extends ConsumerStatefulWidget {
  const EventEditor({
    super.key,
    required this.calendar,
    required this.day,
    this.event,
    this.readOnly = false,
  });
  final SharedCalendar calendar;
  final DateTime day;
  final CalendarEvent? event;
  final bool readOnly;
  @override
  ConsumerState<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<EventEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description;
  late DateTime _start, _end;
  late TimeOfDay _startTime, _endTime;
  late bool _allDay;
  bool _pending = false;
  String? _error;
  bool get _editable => !widget.readOnly && !_pending;
  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _allDay = event?.allDay ?? false;
    final start = event?.localStart(widget.calendar.timezone) ?? widget.day;
    final end = event?.localEnd(widget.calendar.timezone) ?? widget.day;
    _start = calendarDate(start);
    _end = calendarDate(_allDay ? end.subtract(const Duration(days: 1)) : end);
    _startTime = event == null || _allDay
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(start);
    _endTime = event == null || _allDay
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay.fromDateTime(end);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _date(bool start) async {
    final value = start ? _start : _end;
    final chosen = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(value.year < 1900 ? value.year : 1900),
      lastDate: DateTime(value.year > 2100 ? value.year : 2100, 12, 31),
      helpText: start ? '시작 날짜' : '종료 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (chosen != null && mounted) {
      setState(() {
        if (start) {
          _start = calendarDate(chosen);
        } else {
          _end = calendarDate(chosen);
        }
      });
    }
  }

  Future<void> _time(bool start) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      helpText: start ? '시작 시간' : '종료 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (chosen != null && mounted) {
      setState(() {
        if (start) {
          _startTime = chosen;
        } else {
          _endTime = chosen;
        }
      });
    }
  }

  DateTime _instant(DateTime date, TimeOfDay time, {required bool isStart}) {
    final existing = widget.event;
    if (existing != null && !existing.allDay) {
      final local = isStart
          ? existing.localStart(widget.calendar.timezone)
          : existing.localEnd(widget.calendar.timezone);
      if (calendarDate(local) == date &&
          local.hour == time.hour &&
          local.minute == time.minute) {
        return isStart ? existing.start : existing.end;
      }
    }
    final result = tz.TZDateTime(
      calendarZone(widget.calendar.timezone),
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (result.year != date.year ||
        result.month != date.month ||
        result.day != date.day ||
        result.hour != time.hour ||
        result.minute != time.minute) {
      throw const FormatException('시간대 변경으로 존재하지 않는 시간입니다. 다른 시간을 선택해주세요.');
    }
    return result.toUtc();
  }

  Future<void> _save() async {
    if (!_editable || !_form.currentState!.validate()) return;
    DateTime start, end;
    try {
      start = _allDay ? _start : _instant(_start, _startTime, isStart: true);
      end = _allDay
          ? _end.add(const Duration(days: 1))
          : _instant(_end, _endTime, isStart: false);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _error = '종료는 시작보다 뒤여야 합니다.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref
          .read(eventsServiceProvider)
          .save(
            widget.calendar.id,
            EventDraft(
              title: _title.text,
              description: _description.text,
              allDay: _allDay,
              start: start,
              end: end,
            ),
            eventId: widget.event?.id,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _delete() async {
    if (!_editable || widget.event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정을 삭제할까요?'),
        content: const Text('삭제하면 상대방의 캘린더에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await ref
          .read(eventsServiceProvider)
          .delete(widget.calendar.id, widget.event!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _dateTimeFields(String label, bool start) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _editable ? () => _date(start) : null,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(dateText(start ? _start : _end)),
          ),
          if (!_allDay)
            OutlinedButton.icon(
              onPressed: _editable ? () => _time(start) : null,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(
                '${(start ? _startTime : _endTime).hour.toString().padLeft(2, '0')}:${(start ? _startTime : _endTime).minute.toString().padLeft(2, '0')}',
              ),
            ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: AlertDialog(
      title: Text(
        widget.readOnly
            ? '일정 상세'
            : widget.event == null
            ? '일정 등록'
            : '일정 편집',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${widget.calendar.name} · ${widget.calendar.timezone}'),
                if (widget.readOnly)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('상대방이 등록한 일정입니다. 수정·삭제는 작성자만 할 수 있어요.'),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  readOnly: !_editable,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '일정 제목'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '제목을 입력해주세요.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  readOnly: !_editable,
                  maxLength: 5000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '설명 (선택)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('종일 일정'),
                  value: _allDay,
                  onChanged: _editable
                      ? (value) => setState(() {
                          _allDay = value;
                          _error = null;
                        })
                      : null,
                ),
                _dateTimeFields('시작', true),
                const SizedBox(height: 12),
                _dateTimeFields(_allDay ? '마지막 날짜 (이 날짜까지 포함)' : '종료', false),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!widget.readOnly && widget.event != null)
          TextButton(
            onPressed: _editable ? _delete : null,
            child: Text(
              '일정 삭제',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: _pending ? null : () => Navigator.pop(context, false),
          child: Text(widget.readOnly ? '닫기' : '취소'),
        ),
        if (!widget.readOnly)
          LoadingButton(
            loading: _pending,
            onPressed: _save,
            child: const Text('저장'),
          ),
      ],
    ),
  );
}
