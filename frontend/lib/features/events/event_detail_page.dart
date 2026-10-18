import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../shared/ds.dart';
import 'quick_add_sheet.dart';
import 'event_labels.dart';

/// 상세 화면으로 넘기는 값. 딥링크로 들어오면 없을 수 있어 서버에서 다시 읽습니다.
class EventDetailArgs {
  const EventDetailArgs({required this.calendar, required this.event});
  final SharedCalendar calendar;
  final CalendarEvent event;
}

/// G1·G2. 일정 상세 — 내 일정(수정·삭제) · 상대방 일정(조회 전용).
class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({
    super.key,
    required this.calendarId,
    required this.eventId,
    this.args,
  });
  final String calendarId;
  final String eventId;
  final EventDetailArgs? args;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  CalendarEvent? _event;
  Object? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _event = widget.args?.event;
    if (_event == null) _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _error = null);
    try {
      final event = await ref
          .read(eventsServiceProvider)
          .read(widget.calendarId, widget.eventId);
      if (mounted) setState(() => _event = event);
    } catch (e) {
      // 수정 뒤 다시 읽기에 실패하면 이미 보고 있던 내용을 그대로 둡니다.
      if (mounted && !silent) setState(() => _error = e);
    }
  }

  Future<void> _edit(SharedCalendar calendar, CalendarEvent event) async {
    final saved = await showQuickAddSheet(
      context,
      calendar: calendar,
      event: event,
    );
    if (saved == true && mounted) {
      _changed = true;
      ref.invalidate(eventsProvider);
      await _load(silent: true);
    }
  }

  Future<void> _delete(CalendarEvent event) async {
    final deleted = await showDsConfirm(
      context,
      icon: const DsIconTile(icon: DsIcons.trash),
      title: '이 일정을 삭제할까요?',
      message: '‘${event.title}’을 삭제하면 상대방의 캘린더에서도 사라집니다.',
      hint: '휴대폰에 저장된 원본 일정은 변경되지 않아요.',
      confirmLabel: '삭제',
      confirmLoadingLabel: '삭제 중…',
      danger: true,
      errorText: extractErrorMessage,
      onConfirm: () =>
          ref.read(eventsServiceProvider).delete(widget.calendarId, event.id),
    );
    if (deleted && mounted) {
      ref.invalidate(eventsProvider);
      showDsSnack(context, '일정을 삭제했어요');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final calendar =
        widget.args?.calendar ??
        ref.watch(calendarDetailProvider(widget.calendarId)).value;
    final event = _event;
    final isMine = event != null && user != null && event.createdBy == user.id;
    final author = event == null ? null : calendar?.member(event.createdBy);
    final zone = calendar?.timezone ?? 'Asia/Seoul';

    return DsScreen(
      onPopInvoked: (didPop, result) {},
      header: DsHeader(
        title: '일정 상세',
        backLabel: '달력으로',
        onBack: () => Navigator.of(context).pop(_changed),
      ),
      body: event == null
          ? _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: DsStateView(
                        art: const DsIconTile(icon: DsIcons.offline),
                        title: '일정을 불러오지 못했어요',
                        description: extractErrorMessage(_error!),
                        action: DsButton(
                          label: '다시 시도',
                          height: 44,
                          fontSize: 14,
                          onPressed: _load,
                        ),
                      ),
                    ),
                  )
                : const DsBody(
                    children: [
                      DsSkeleton(
                        width: 120,
                        height: 26,
                        radius: AppRadius.pill,
                      ),
                      DsSkeleton(height: 36),
                      DsSkeleton(height: 160, radius: 20),
                      DsLoadingLine('일정을 불러오고 있어요'),
                    ],
                  )
          : DsBody(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DsMemberChip(name: author?.name ?? '사용자', isMe: isMine),
                        DsHint(
                          isMine
                              ? '내가 등록한 일정이에요'
                              : '${author?.name ?? '상대방'}가 등록한 일정이에요 · 보기만 할 수 있어요',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      event.title,
                      style: ds(
                        28,
                        weight: 700,
                        letterSpacing: -0.4,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                _InfoCard(event: event, calendar: calendar, zone: zone),
                if ((event.description ?? '').trim().isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: DsLabel('설명'),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.eventCard,
                          ),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: SelectableText(
                          event.description!.trim(),
                          style: ds(15, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                if (event.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DsHint(_historyLabel(event)),
                  ),
              ],
            ),
      bottom: event == null
          ? null
          : isMine
          ? Row(
              children: [
                Expanded(
                  flex: 10,
                  child: DsButton(
                    label: '삭제',
                    icon: DsIcons.trash,
                    variant: DsButtonVariant.secondary,
                    foregroundColor: AppColors.errorText,
                    onPressed: () => _delete(event),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 16,
                  child: DsButton(
                    label: '수정',
                    icon: DsIcons.edit,
                    onPressed: calendar == null
                        ? null
                        : () => _edit(calendar, event),
                  ),
                ),
              ],
            )
          : const DsHint(
              '상대방이 등록한 일정은 수정·삭제할 수 없어요.',
              textAlign: TextAlign.center,
            ),
    );
  }

  static String _historyLabel(CalendarEvent event) {
    final created = event.createdAt!.toLocal();
    final updated = event.updatedAt?.toLocal();
    final edited =
        updated != null && updated.difference(created).inMinutes.abs() >= 1;
    return edited
        ? '${monthDay(created)}에 등록 · ${monthDay(updated)}에 수정'
        : '${monthDay(created)}에 등록';
  }
}

/// 날짜 · 시간 · 캘린더 정보 카드 (행 52, 구분선 1px).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.event,
    required this.calendar,
    required this.zone,
  });
  final CalendarEvent event;
  final SharedCalendar? calendar;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final start = event.localStart(zone);
    final end = event.localEnd(zone);
    final sameDay = event.allDay
        ? event.start == event.lastDay
        : calendarDate(start) == calendarDate(end);
    final Widget dateValue;
    if (sameDay) {
      dateValue = Text(
        fullDate(event.allDay ? event.start : start),
        style: _value,
      );
    } else {
      final a = event.allDay ? event.start : start;
      final b = event.allDay ? event.lastDay : end;
      final days = event.allDay
          ? event.lastDay.difference(event.start).inDays + 1
          : calendarDate(end).difference(calendarDate(start)).inDays + 1;
      dateValue = Text.rich(
        TextSpan(
          style: _value,
          children: [
            TextSpan(text: '${monthDayWeekday(a)} –\n${monthDayWeekday(b)}'),
            TextSpan(
              text: ' · $days일',
              style: ds(15, color: AppColors.brown500, height: 1.4),
            ),
          ],
        ),
      );
    }
    final duration = event.durationLabel(zone);
    return DsCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _row(DsIcons.calendar, '날짜', dateValue, divider: true),
          _row(
            DsIcons.clock,
            '시간',
            Text.rich(
              TextSpan(
                style: _value,
                children: [
                  TextSpan(text: event.timeLabel(zone)),
                  if (duration != null)
                    TextSpan(
                      text: ' · $duration',
                      style: ds(15, color: AppColors.brown500, height: 1.4),
                    ),
                ],
              ),
            ),
            divider: true,
          ),
          _row(
            DsIcons.folder,
            '캘린더',
            Text(
              calendar?.name ?? '공유 캘린더',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _value,
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle get _value => ds(15, weight: 600, height: 1.4);

  static Widget _row(
    String icon,
    String label,
    Widget value, {
    bool divider = false,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    decoration: divider
        ? const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
          )
        : null,
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        DsIcon(icon, size: 20, color: AppColors.brown700, stroke: 1.8),
        const SizedBox(width: 12),
        SizedBox(width: 48, child: DsHint(label)),
        Expanded(child: value),
      ],
    ),
  );
}
