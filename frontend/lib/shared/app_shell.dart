import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../router.dart';
import 'appearance_menu.dart';
import 'widgets.dart';

const _sidebarWidth = 256.0;
const _desktopBreakpoint = 1024.0;

class _NavItem {
  const _NavItem(this.icon, this.title, this.path);
  final IconData icon;
  final String title;
  final String path;
}

const _baseItems = [
  _NavItem(Icons.home_outlined, 'Dashboard', Routes.dashboard),
  _NavItem(Icons.work_outline, 'Items', Routes.items),
];
const _adminItem = _NavItem(Icons.people_outline, 'Admin', Routes.admin);

/// Authenticated layout: sidebar on desktop, drawer on smaller screens.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    final content = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: child,
              ),
            ),
          ),
        ),
        const AppFooter(),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            const _Sidebar(inDrawer: false),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AppLogo(height: 20),
        centerTitle: false,
      ),
      drawer: const Drawer(
        width: _sidebarWidth,
        child: _Sidebar(inDrawer: true),
      ),
      body: content,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.inDrawer});

  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).uri.path;
    final items = [
      ..._baseItems,
      if (user?.isSuperuser ?? false) _adminItem,
    ];
    final theme = Theme.of(context);

    return Container(
      width: _sidebarWidth,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: AppLogo(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final item in items)
                    ListTile(
                      dense: true,
                      selected: location == item.path,
                      selectedTileColor: theme.colorScheme.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(item.icon, size: 18),
                      title: Text(item.title),
                      onTap: () {
                        if (inDrawer) Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const SidebarAppearanceTile(),
                  if (user != null) _UserMenu(user: user, inDrawer: inDrawer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserInfo extends StatelessWidget {
  const _UserInfo({required this.user});

  final UserPublic user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF52525B),
          child: Text(
            getInitials(user.fullName?.isNotEmpty == true
                ? user.fullName!
                : 'User'),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _UserAction { settings, logout }

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.user, required this.inDrawer});

  final UserPublic user;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_UserAction>(
      tooltip: 'User menu',
      position: PopupMenuPosition.over,
      onSelected: (action) {
        if (inDrawer) Navigator.of(context).pop();
        switch (action) {
          case _UserAction.settings:
            context.go(Routes.settings);
          case _UserAction.logout:
            ref.read(authProvider.notifier).logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(width: 220, child: _UserInfo(user: user)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _UserAction.settings,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined, size: 18),
            title: Text('User Settings'),
          ),
        ),
        const PopupMenuItem(
          value: _UserAction.logout,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout, size: 18),
            title: Text('Log Out'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(child: _UserInfo(user: user)),
            Icon(
              Icons.unfold_more,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
