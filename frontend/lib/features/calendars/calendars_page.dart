import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendars_provider.dart';
import '../../shared/widgets.dart';
import 'calendar_dialogs.dart';
import 'calendar_remove_dialog.dart';

class CalendarsPage extends ConsumerStatefulWidget {
  const CalendarsPage({super.key});
  @override
  ConsumerState<CalendarsPage> createState() => _CalendarsPageState();
}

class _CalendarsPageState extends ConsumerState<CalendarsPage>
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final calendars = ref.watch(calendarsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: '공유 캘린더', subtitle: '초대코드로 두 사람의 캘린더를 연결하세요.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: user == null
                  ? null
                  : () => showCalendarInput(context, joining: false),
              icon: const Icon(Icons.add),
              label: const Text('새 캘린더'),
            ),
            OutlinedButton.icon(
              onPressed: user == null
                  ? null
                  : () => showCalendarInput(context, joining: true),
              icon: const Icon(Icons.link),
              label: const Text('초대코드로 참여'),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(calendarsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (user == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('계정 정보를 불러오는 중입니다.')),
          )
        else
          calendars.when(
            skipLoadingOnRefresh: false,
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(extractErrorMessage(error)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(calendarsProvider),
                      child: const Text('다시 불러오기'),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) => data.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 48),
                          SizedBox(height: 16),
                          Text('아직 연결된 캘린더가 없어요.'),
                          SizedBox(height: 8),
                          Text(
                            '새 캘린더를 만들거나 받은 초대코드를 입력해주세요.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final calendar in data)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _CalendarCard(
                            calendar: calendar,
                            userId: user.id,
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.calendar, required this.userId});
  final SharedCalendar calendar;
  final String userId;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(calendar.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            calendar.isConnected
                ? '두 사람이 연결되었어요 · 2/2명'
                : '상대방의 참여를 기다리고 있어요 · 1/2명',
          ),
          const SizedBox(height: 20),
          for (final member in calendar.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(member.slot == 1 ? Icons.person_outline : Icons.person),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${member.name}${member.id == userId ? ' (나)' : ''}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(member.role == 'owner' ? '만든 사람' : '참여자'),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => context.go('/calendars/${calendar.id}'),
              icon: const Icon(Icons.calendar_month),
              label: const Text('일정 보기'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showCalendarRemoval(
                context,
                calendar,
                deleting: calendar.isOwner(userId),
              ),
              icon: Icon(
                calendar.isOwner(userId) ? Icons.delete_outline : Icons.logout,
              ),
              label: Text(calendar.isOwner(userId) ? '캘린더 삭제' : '캘린더 나가기'),
            ),
          ),
          if (!calendar.isConnected && calendar.isOwner(userId)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => showCalendarInvitation(context, calendar),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('상대방 초대하기'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
