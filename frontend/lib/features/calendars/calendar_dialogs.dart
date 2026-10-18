import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../providers/calendars_provider.dart';
import '../../shared/widgets.dart';

Future<void> showCalendarInput(BuildContext context, {required bool joining}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CalendarInputDialog(joining: joining),
    );

class _CalendarInputDialog extends ConsumerStatefulWidget {
  const _CalendarInputDialog({required this.joining});
  final bool joining;
  @override
  ConsumerState<_CalendarInputDialog> createState() =>
      _CalendarInputDialogState();
}

class _CalendarInputDialogState extends ConsumerState<_CalendarInputDialog> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  bool _pending = false;
  String? _error;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_form.currentState!.validate()) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final service = ref.read(calendarsServiceProvider);
      final calendar = widget.joining
          ? await service.acceptInvitation(_input.text)
          : await service.create(_input.text.trim());
      if (!mounted) return;
      ref.invalidate(calendarsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.joining
                ? '${calendar.name}에 참여했습니다.'
                : '${calendar.name}을 만들었습니다.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_pending,
    child: AlertDialog(
      title: Text(widget.joining ? '초대코드로 참여' : '새 캘린더 만들기'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.joining
                      ? '상대방이 보낸 12자리 코드를 입력해주세요.'
                      : '두 사람이 함께 사용할 캘린더의 이름을 정해주세요.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _input,
                  enabled: !_pending,
                  autofocus: true,
                  maxLength: widget.joining ? 64 : 100,
                  textCapitalization: widget.joining
                      ? TextCapitalization.characters
                      : TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.joining ? '초대코드' : '캘린더 이름',
                    hintText: widget.joining ? 'ABCD-EFGH-2345' : '우리 일정',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return widget.joining ? '초대코드를 입력해주세요.' : '이름을 입력해주세요.';
                    }
                    if (widget.joining &&
                        !RegExp(r'^[A-HJ-NP-Z2-9]{12}$').hasMatch(
                          value!.toUpperCase().replaceAll(RegExp(r'[\s-]'), ''),
                        )) {
                      return '12자리 초대코드를 확인해주세요.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        LoadingButton(
          loading: _pending,
          onPressed: _submit,
          child: Text(widget.joining ? '참여하기' : '만들기'),
        ),
      ],
    ),
  );
}

Future<void> showCalendarInvitation(
  BuildContext context,
  SharedCalendar calendar,
) => showDialog<void>(
  context: context,
  builder: (_) => _InvitationDialog(calendar: calendar),
);

class _InvitationDialog extends ConsumerStatefulWidget {
  const _InvitationDialog({required this.calendar});
  final SharedCalendar calendar;
  @override
  ConsumerState<_InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends ConsumerState<_InvitationDialog> {
  CalendarInvitation? _invitation;
  String? _error;
  bool _pending = false;
  bool _copied = false;

  Future<void> _issue() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
      _invitation = null;
      _copied = false;
    });
    try {
      final invitation = await ref
          .read(calendarsServiceProvider)
          .issueInvitation(widget.calendar.id);
      if (mounted) setState(() => _invitation = invitation);
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        ref.invalidate(calendarsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = _invitation;
    final local = invitation?.expiresAt.toLocal();
    final deadline = local == null
        ? ''
        : '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: const Text('상대방 초대하기'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.calendar.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  '코드를 복사해 상대방에게 보내주세요. 로그인 후 ‘초대코드로 참여’에서 입력하면 연결됩니다.',
                ),
                const SizedBox(height: 20),
                if (invitation != null) ...[
                  SelectableText(
                    invitation.displayCode,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('$deadline까지 · 한 번만 사용 가능', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: invitation.displayCode),
                        );
                        if (mounted) setState(() => _copied = true);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error = '복사하지 못했습니다. 코드를 선택해 복사해주세요.',
                          );
                        }
                      }
                    },
                    icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                    label: Text(_copied ? '복사했어요' : '코드 복사'),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('새 코드를 발급하면 이전 코드는 사용할 수 없습니다.'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          LoadingButton(
            loading: _pending,
            onPressed: _issue,
            child: Text(invitation == null ? '초대코드 발급' : '새 코드 발급'),
          ),
        ],
      ),
    );
  }
}
