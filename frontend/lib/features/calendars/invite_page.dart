import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../providers/calendars_provider.dart';
import '../../providers/events_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';

/// E1·E2. 초대하기 — 초대코드 · 재발급 확인.
/// 코드는 서버에 해시로만 남아 다시 읽을 수 없으므로, 화면에 들어올 때 새 코드를 발급합니다.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key, required this.calendarId});
  final String calendarId;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  CalendarInvitation? _invitation;
  String? _error;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _issue());
  }

  Future<void> _issue() async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final invitation = await ref
          .read(calendarsServiceProvider)
          .issueInvitation(widget.calendarId);
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
      if (mounted) {
        setState(() => _error = '복사하지 못했어요. 코드를 직접 옮겨 적어 주세요.');
      }
    }
  }

  Future<void> _reissue() async {
    final current = _invitation;
    final confirmed = await showDsConfirm(
      context,
      title: '새 코드를 발급할까요?',
      body: Text.rich(
        TextSpan(
          style: ds(14.5, height: 1.55),
          children: [
            const TextSpan(text: '지금 코드 '),
            TextSpan(
              text: current?.groups.join(' ') ?? '',
              style: ds(14.5, weight: 600, height: 1.55),
            ),
            const TextSpan(text: '는 바로 무효가 돼요. 상대방에게 아직 보내지 않았다면 그대로 써도 괜찮아요.'),
          ],
        ),
      ),
      confirmLabel: '새 코드 발급',
    );
    if (confirmed && mounted) await _issue();
  }

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(calendarsProvider).value;
    final detail = ref.watch(calendarDetailProvider(widget.calendarId)).value;
    final calendar =
        detail ??
        calendars?.cast<SharedCalendar?>().firstWhere(
          (c) => c!.id == widget.calendarId,
          orElse: () => null,
        );
    final invitation = _invitation;
    final expires = invitation?.expiresAt.toLocal();

    return DsScreen(
      header: DsHeader(
        title: '상대방 초대하기',
        onBack: () => context.go(Routes.home),
      ),
      body: DsBody(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DsChip(label: calendar?.name ?? '공유 캘린더', maxWidth: 260),
              DsHint(
                calendar?.isConnected == true
                    ? '2/2명 · 두 사람이 연결되어 있어요'
                    : '${calendar?.members.length ?? 1}/2명 · 상대방을 기다리고 있어요',
              ),
            ],
          ),
          if (calendar?.isConnected == true)
            const DsBanner(
              kind: DsBannerKind.ok,
              message: '이미 두 사람이 연결된 캘린더예요. 새 초대코드는 필요하지 않아요.',
            )
          else
            Stack(
              children: [
                DsCard(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '초대코드',
                        textAlign: TextAlign.center,
                        style: AppText.label,
                      ),
                      const SizedBox(height: 14),
                      if (_pending || (invitation == null && _error == null))
                        const Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DsSkeleton(width: 84, height: 36),
                                SizedBox(width: 12),
                                DsSkeleton(width: 84, height: 36),
                                SizedBox(width: 12),
                                DsSkeleton(width: 84, height: 36),
                              ],
                            ),
                            SizedBox(height: 14),
                            DsLoadingLine('초대코드를 만들고 있어요'),
                          ],
                        )
                      else if (invitation != null)
                        Semantics(
                          label: '초대코드 ${invitation.groups.join(' ')}',
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Text(
                                    invitation.groups[i],
                                    style: ds(
                                      30,
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
                        )
                      else
                        DsBanner(
                          message: _error!,
                          actionLabel: '다시 시도',
                          onAction: _issue,
                        ),
                      const SizedBox(height: 14),
                      DsButton(
                        label: '코드 복사',
                        icon: DsIcons.copy,
                        variant: DsButtonVariant.secondary,
                        height: 48,
                        onPressed: invitation == null || _pending
                            ? null
                            : _copy,
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.outlineVariant),
                      const SizedBox(height: 14),
                      DsHint(
                        expires == null
                            ? '발급되면 만료 시각이 여기 표시돼요'
                            : '만료: ${deadlineKo(expires)}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const DsHint(
                        '한 사람만 참여할 수 있어요. 코드는 한 번 쓰면 사라져요.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (_error != null && invitation != null) DsBanner(message: _error!),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: DsHint("상대방이 앱에서 '초대코드로 참여하기'에 이 코드를 입력하면 연결돼요."),
          ),
        ],
      ),
      bottom: DsActions(
        gap: 16,
        children: [
          if (calendar?.isConnected != true)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsButton(
                  label: '새 코드 발급',
                  loadingLabel: '발급 중…',
                  variant: DsButtonVariant.secondary,
                  loading: _pending && invitation != null,
                  onPressed: invitation == null ? null : _reissue,
                ),
                const SizedBox(height: 8),
                const DsHint(
                  '새 코드를 발급하면 지금 코드는 더 이상 쓸 수 없어요.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          DsButton(label: '달력으로', onPressed: () => context.go(Routes.home)),
        ],
      ),
    );
  }
}
