import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

IconData _iconFor(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.desktop_windows_outlined,
    };

List<PopupMenuEntry<ThemeMode>> _entries() => const [
      PopupMenuItem(
        value: ThemeMode.light,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.light_mode_outlined, size: 18),
          title: Text('Light'),
        ),
      ),
      PopupMenuItem(
        value: ThemeMode.dark,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.dark_mode_outlined, size: 18),
          title: Text('Dark'),
        ),
      ),
      PopupMenuItem(
        value: ThemeMode.system,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.desktop_windows_outlined, size: 18),
          title: Text('System'),
        ),
      ),
    ];

/// Icon-only theme switcher used on the auth pages.
class AppearanceButton extends ConsumerWidget {
  const AppearanceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Toggle theme',
      onSelected: (m) => ref.read(themeModeProvider.notifier).setMode(m),
      itemBuilder: (_) => _entries(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_iconFor(mode), size: 18),
      ),
    );
  }
}

/// Sidebar row theme switcher.
class SidebarAppearanceTile extends ConsumerWidget {
  const SidebarAppearanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Appearance',
      position: PopupMenuPosition.over,
      onSelected: (m) => ref.read(themeModeProvider.notifier).setMode(m),
      itemBuilder: (_) => _entries(),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(_iconFor(mode), size: 18),
        title: const Text('Appearance'),
      ),
    );
  }
}
