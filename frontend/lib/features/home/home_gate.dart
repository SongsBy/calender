import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendars_provider.dart';
import '../../shared/ds.dart';
import '../events/calendar_page.dart';
import 'account_sheet.dart';

/// 로그인 직후 홈 — 곧바로 달력을 보여 줍니다.
/// 연결된 캘린더가 있으면 그것을, 없으면 첫 캘린더를 띄우고,
/// 캘린더가 하나도 없으면 첫 캘린더를 자동으로 만들어 바로 보여 줍니다.
class HomeGate extends ConsumerStatefulWidget {
  const HomeGate({super.key});
  static const defaultCalendarName = '우리 캘린더';

  @override
  ConsumerState<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends ConsumerState<HomeGate>
    with WidgetsBindingObserver {
  bool _creating = false;
  Object? _createError;

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

  Future<void> _createFirstCalendar() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      await ref
          .read(calendarsServiceProvider)
          .create(HomeGate.defaultCalendarName);
      ref.invalidate(calendarsProvider);
    } catch (e) {
      if (mounted) setState(() => _createError = e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  static SharedCalendar primaryOf(List<SharedCalendar> calendars) {
    for (final c in calendars) {
      if (c.isConnected) return c;
    }
    return calendars.first;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final calendars = ref.watch(calendarsProvider);

    if (user == null || (calendars.isLoading && !calendars.hasValue)) {
      return _shell(context, const ScheduleSkeleton());
    }
    final error = _createError ?? (calendars.hasValue ? null : calendars.error);
    if (error != null) {
      return _shell(
        context,
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DsCard(
              color: AppColors.cream,
              radius: 20,
              shadow: false,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: DsStateView(
                art: const DsIconTile(icon: DsIcons.offline),
                title: '서버에 연결할 수 없어요',
                description: extractErrorMessage(error),
                action: DsButton(
                  label: '다시 시도',
                  height: 44,
                  fontSize: 14,
                  onPressed: () {
                    setState(() => _createError = null);
                    ref.invalidate(calendarsProvider);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }
    final list = calendars.requireValue;
    if (list.isEmpty) {
      if (!_creating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _createFirstCalendar();
        });
      }
      return _shell(context, const ScheduleSkeleton());
    }
    final primary = primaryOf(list);
    return CalendarSchedule(
      key: ValueKey('home:${primary.id}:${user.id}'),
      calendar: primary,
      isHome: true,
    );
  }

  Widget _shell(BuildContext context, Widget body) => DsScreen(
    header: DsHeader(
      title: '',
      hideBack: true,
      trailing: DsIconButton(
        icon: DsIcons.person,
        filled: true,
        stroke: 1.9,
        semanticLabel: '계정 메뉴',
        onPressed: () => showAccountSheet(context),
      ),
    ),
    body: body,
  );
}
