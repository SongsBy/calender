import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import 'package:go_router/go_router.dart';
import '../../shared/ds.dart';

/// K1. 계정 메뉴 — 바텀시트.
Future<void> showAccountSheet(BuildContext context) =>
    showDsSheet<void>(context, builder: (_) => const _AccountSheet());

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();
  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  bool _pending = false;

  Future<void> _logout() async {
    if (_pending) return;
    setState(() => _pending = true);
    final navigator = Navigator.of(context);
    await ref.read(authProvider.notifier).logout();
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final name = user?.displayName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('내 계정', style: AppText.title)),
            DsIconButton(
              icon: DsIcons.close,
              iconSize: 22,
              semanticLabel: '닫기',
              onPressed: _pending ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              const DsAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ds(17, weight: 600),
                    ),
                    const SizedBox(height: 2),
                    DsHint('아이디 ${user?.username ?? ''}', maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const DsChip(label: '나', variant: DsChipVariant.me, dot: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: DsHint('이 기기에서는 로그인 상태가 자동으로 유지돼요. 이름과 아이디는 함께하는 상대방에게 보여요.'),
        ),
        const SizedBox(height: 16),
        DsButton(
          label: '캘린더 목록',
          icon: DsIcons.folder,
          variant: DsButtonVariant.secondary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: _pending
              ? null
              : () {
                  Navigator.of(context).pop();
                  context.go(Routes.calendars);
                },
        ),
        const SizedBox(height: 10),
        DsButton(
          label: '로그아웃',
          loadingLabel: '로그아웃 중…',
          icon: DsIcons.logout,
          variant: DsButtonVariant.secondary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          loading: _pending,
          onPressed: _logout,
        ),
        const SizedBox(height: 16),
        DsHint(
          '${AppConfig.appTitle} · 버전 ${AppConfig.appVersion}',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
