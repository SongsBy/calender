import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../providers/calendars_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import '../../shared/navigation.dart';
import '../calendars/join_page.dart';

/// 아직 혼자인 달력 위에 보이는 초대 카드.
/// 초대코드를 만들어 바로 보여 주고, 받은 코드가 있으면 참여 화면으로 보냅니다.
class SoloInviteCard extends ConsumerStatefulWidget {
  const SoloInviteCard({
    super.key,
    required this.calendar,
    required this.userId,
  });
  final SharedCalendar calendar;
  final String userId;

  @override
  ConsumerState<SoloInviteCard> createState() => _SoloInviteCardState();
}

class _SoloInviteCardState extends ConsumerState<SoloInviteCard> {
  CalendarInvitation? _invitation;
  String? _error;
  bool _pending = false;

  bool get _isOwner => widget.calendar.isOwner(widget.userId);

  Future<void> _issue() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final invitation = await ref
          .read(calendarsServiceProvider)
          .issueInvitation(widget.calendar.id);
      if (mounted) setState(() => _invitation = invitation);
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _copy() async {
    final invitation = _invitation;
    if (invitation == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: invitation.displayCode));
      if (mounted) showDsSnack(context, '초대코드를 복사했어요');
    } catch (_) {
      if (mounted) setState(() => _error = '복사하지 못했어요. 코드를 직접 옮겨 적어 주세요.');
    }
  }

  void _join() =>
      pushScreen<void>(context, Routes.join, () => const JoinPage());

  @override
  Widget build(BuildContext context) {
    final invitation = _invitation;
    final expires = invitation?.expiresAt.toLocal();
    return DsCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DsSmile(size: 40, color: AppColors.pink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('아직 혼자예요', style: ds(16, weight: 600, height: 1.35)),
                    const SizedBox(height: 2),
                    const DsHint('상대방을 초대하면 두 사람의 일정이 이 달력에 함께 모여요.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            DsBanner(message: _error!),
            const SizedBox(height: 10),
          ],
          if (invitation != null) ...[
            Semantics(
              label: '초대코드 ${invitation.groups.join(' ')}',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Text(
                        invitation.groups[i],
                        style: ds(
                          26,
                          weight: 700,
                          letterSpacing: 3,
                          height: 1.2,
                          tabular: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            DsHint(
              expires == null
                  ? ''
                  : '만료: ${deadlineKo(expires)} · 한 번만 쓸 수 있어요',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 16,
                  child: DsButton(
                    label: '코드 복사',
                    icon: DsIcons.copy,
                    height: 48,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: _copy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 10,
                  child: DsButton(
                    label: '새 코드',
                    loadingLabel: '발급 중…',
                    variant: DsButtonVariant.secondary,
                    height: 48,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    loading: _pending,
                    onPressed: _issue,
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                if (_isOwner) ...[
                  Expanded(
                    flex: 16,
                    child: DsButton(
                      label: '초대코드 만들기',
                      loadingLabel: '만드는 중…',
                      icon: DsIcons.link,
                      height: 48,
                      fontSize: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      loading: _pending,
                      onPressed: _issue,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 10,
                  child: DsButton(
                    label: '코드 입력',
                    variant: DsButtonVariant.secondary,
                    height: 48,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: _join,
                  ),
                ),
              ],
            ),
          if (invitation != null) ...[
            const SizedBox(height: 4),
            DsButton(
              label: '받은 코드가 있어요 · 코드 입력',
              variant: DsButtonVariant.text,
              height: 40,
              fontSize: 14,
              onPressed: _join,
            ),
          ],
        ],
      ),
    );
  }
}
