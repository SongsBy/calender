import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../providers/calendars_provider.dart';
import '../../providers/events_provider.dart';

Future<void> showCalendarRemoval(
  BuildContext context,
  SharedCalendar calendar, {
  required bool deleting,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RemovalDialog(calendar: calendar, deleting: deleting),
);

class _RemovalDialog extends ConsumerStatefulWidget {
  const _RemovalDialog({required this.calendar, required this.deleting});
  final SharedCalendar calendar;
  final bool deleting;
  @override
  ConsumerState<_RemovalDialog> createState() => _RemovalDialogState();
}

class _RemovalDialogState extends ConsumerState<_RemovalDialog> {
  bool busy = false;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = ref.read(calendarsServiceProvider);
      if (widget.deleting) {
        await service.delete(widget.calendar.id);
      } else {
        await service.leave(widget.calendar.id);
      }
      ref.invalidate(calendarsProvider);
      ref.invalidate(calendarDetailProvider(widget.calendar.id));
      ref.invalidate(eventsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = extractErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.deleting ? '캘린더를 삭제할까요?' : '캘린더에서 나갈까요?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.calendar.name),
            const SizedBox(height: 12),
            Text(
              widget.deleting
                  ? '두 사람의 모든 일정과 초대코드가 삭제됩니다. 상대방도 이 캘린더에 접근할 수 없으며 복구할 수 없습니다.'
                  : '내가 등록하거나 가져온 일정이 이 공유 캘린더에서 삭제됩니다. 상대방 일정은 유지됩니다. 다시 참여하려면 새로운 초대코드가 필요합니다.',
            ),
            const SizedBox(height: 8),
            const Text('휴대폰의 원본 일정은 변경되지 않습니다.'),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(widget.deleting ? '삭제하기' : '나가기'),
        ),
      ],
    ),
  );
}
