import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendars_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import '../calendars/calendar_remove_dialog.dart';
import 'account_sheet.dart';

/// C. 캘린더 목록 · 메인 — 기본 · 빈 화면 · 로딩.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(calendarsProvider);
  }

  Future<void> _refresh() =>
      ref.refresh(calendarsProvider.future).then((_) {}, onError: (_) {});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final calendars = ref.watch(calendarsProvider);
    final name = user?.displayName ?? '';
    final now = DateTime.now();
    final loading = user == null || calendars.isLoading && !calendars.hasValue;
    final list = calendars.hasValue ? calendars.requireValue : null;
    final isEmpty = list != null && list.isEmpty && !calendars.hasError;

    final greeting = isEmpty ? '$name님, 반가워요' : '$name님, 좋은 하루예요';
    final subtitle = loading
        ? '캘린더를 불러오고 있어요…'
        : isEmpty || list == null
        ? monthDayWeekdayLong(now)
        : '${monthDayWeekdayLong(now)} · 참여 중인 캘린더 ${list.length}개';

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          greeting,
                          style: AppText.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: ds(14, color: AppColors.brown500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          DsIconButton(
            icon: DsIcons.person,
            filled: true,
            stroke: 1.9,
            semanticLabel: '계정 메뉴',
            onPressed: user == null ? null : () => showAccountSheet(context),
          ),
        ],
      ),
    );

    Widget body;
    if (loading) {
      body = const _HomeSkeleton();
    } else if (isEmpty) {
      body = const _EmptyHome();
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.brown900,
        backgroundColor: AppColors.surface,
        strokeWidth: 2.5,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _ActionTiles(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 12),
              child: Text(
                '참여 중인 캘린더',
                style: ds(14, weight: 600, color: AppColors.brown700),
              ),
            ),
            if (calendars.hasError && list == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: DsCard(
                  color: AppColors.cream,
                  radius: 20,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: DsStateView(
                    art: const DsIconTile(icon: DsIcons.offline),
                    title: '서버에 연결할 수 없어요',
                    description: isConnectionError(calendars.error!)
                        ? '인터넷 연결을 확인한 뒤 다시 시도해 주세요.'
                        : extractErrorMessage(calendars.error!),
                    action: DsButton(
                      label: '다시 시도',
                      height: 44,
                      fontSize: 14,
                      onPressed: () => ref.invalidate(calendarsProvider),
                    ),
                  ),
                ),
              )
            else
              for (final calendar in list!)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: _CalendarCard(calendar: calendar, userId: user.id),
                ),
          ],
        ),
      );
    }

    return DsScreen(header: header, body: body, bottom: null);
  }
}

/// 새 캘린더 만들기 · 초대코드로 참여하기 타일 (22 모서리, 최소 92).
class _ActionTiles extends StatelessWidget {
  const _ActionTiles();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
    child: Row(
      children: [
        Expanded(
          child: _ActionTile(
            color: AppColors.butter,
            icon: DsIcons.plus,
            iconColor: AppColors.brown900,
            iconStroke: 2.2,
            label: '새 캘린더\n만들기',
            onTap: () => context.push(Routes.createCalendar),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            color: AppColors.pinkContainer,
            icon: DsIcons.link,
            iconColor: AppColors.onPinkContainer,
            label: '초대코드로\n참여하기',
            onTap: () => context.push(Routes.join),
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.iconStroke = 2,
  });
  final Color color;
  final String icon;
  final Color iconColor;
  final double iconStroke;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(AppRadius.tile),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      highlightColor: AppColors.scrim.withValues(alpha: .08),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              alignment: Alignment.center,
              child: DsIcon(
                icon,
                size: 20,
                color: iconColor,
                stroke: iconStroke,
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: ds(14.5, weight: 600, height: 1.3)),
          ],
        ),
      ),
    ),
  );
}

/// 캘린더 카드 — 이름 + 역할 칩 · 참여자 칩 + n/2명 · 일정 보기 · 권한별 보조 행.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.calendar, required this.userId});
  final SharedCalendar calendar;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = calendar.member(userId);
    final partner = calendar.partnerOf(userId);
    final owner = calendar.isOwner(userId);
    final connected = calendar.isConnected;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  calendar.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ds(20, weight: 700, letterSpacing: -0.4, height: 1.3),
                ),
              ),
              const SizedBox(width: 10),
              if (connected)
                const DsChip(
                  label: '연결됨',
                  variant: DsChipVariant.ok,
                  leading: DsIcon(
                    DsIcons.check,
                    size: 12,
                    color: AppColors.onSuccessContainer,
                    stroke: 3,
                  ),
                )
              else if (owner)
                const DsChip(label: '내가 만들었어요'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (me != null) DsMemberChip(name: me.name, isMe: true),
                    if (partner != null)
                      DsMemberChip(name: partner.name, isMe: false)
                    else
                      const DsChip(
                        label: '상대방을 기다리고 있어요',
                        variant: DsChipVariant.dashed,
                        maxWidth: null,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${calendar.members.length}/2명',
                style: ds(13, weight: 600, color: AppColors.brown500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DsButton(
            label: '일정 보기',
            onPressed: () => context.push(Routes.calendar(calendar.id)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (owner && !connected) ...[
                Expanded(
                  child: DsButton(
                    label: '상대방 초대하기',
                    variant: DsButtonVariant.secondary,
                    height: 48,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () => context.push(Routes.invite(calendar.id)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: DsButton(
                  label: owner ? '캘린더 삭제' : '캘린더 나가기',
                  variant: DsButtonVariant.text,
                  fontSize: 15,
                  foregroundColor: owner
                      ? AppColors.errorText
                      : AppColors.brown700,
                  onPressed: () => showCalendarRemoval(
                    context,
                    ref,
                    calendar,
                    deleting: owner,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// C2. 빈 화면 — 일러스트 + 제목 + 두 버튼.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DsEmptyCalendarArt(),
          const SizedBox(height: 20),
          Text(
            '함께할 첫 캘린더를\n만들어볼까요?',
            textAlign: TextAlign.center,
            style: ds(22, weight: 700, letterSpacing: -0.4, height: 1.35),
          ),
          const SizedBox(height: 14),
          Text(
            '캘린더를 만들어 상대방을 초대하거나,\n받은 초대코드로 참여할 수 있어요.',
            textAlign: TextAlign.center,
            style: ds(14, color: AppColors.brown500, height: 1.55),
          ),
          const SizedBox(height: 28),
          DsButton(
            label: '새 캘린더 만들기',
            icon: DsIcons.plus,
            onPressed: () => context.push(Routes.createCalendar),
          ),
          const SizedBox(height: 10),
          DsButton(
            label: '초대코드로 참여하기',
            variant: DsButtonVariant.secondary,
            onPressed: () => context.push(Routes.join),
          ),
        ],
      ),
    ),
  );
}

/// C3. 로딩 — 레이아웃을 본뜬 스켈레톤.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: '캘린더를 불러오고 있어요',
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        const Row(
          children: [
            Expanded(child: DsSkeleton(height: 92, radius: AppRadius.tile)),
            SizedBox(width: 12),
            Expanded(child: DsSkeleton(height: 92, radius: AppRadius.tile)),
          ],
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DsSkeleton(width: 120, height: 16),
          ),
        ),
        const SizedBox(height: 12),
        _cardSkeleton(withActions: true),
        const SizedBox(height: 12),
        Opacity(opacity: .7, child: _cardSkeleton(withActions: false)),
        const SizedBox(height: 20),
        const DsLoadingLine('잠시만 기다려 주세요'),
      ],
    ),
  );

  static Widget _cardSkeleton({required bool withActions}) => DsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: DsSkeleton(height: 22)),
            SizedBox(width: 10),
            DsSkeleton(width: 88, height: 26, radius: AppRadius.pill),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            DsSkeleton(width: 84, height: 26, radius: AppRadius.pill),
            SizedBox(width: 8),
            Flexible(
              child: DsSkeleton(width: 150, height: 26, radius: AppRadius.pill),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const DsSkeleton(height: 52, radius: AppRadius.button),
        if (withActions) ...[
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: DsSkeleton(height: 44, radius: AppRadius.input)),
              SizedBox(width: 8),
              Expanded(child: DsSkeleton(height: 44, radius: AppRadius.input)),
            ],
          ),
        ],
      ],
    ),
  );
}
