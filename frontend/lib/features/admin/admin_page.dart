import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../router.dart';
import '../../shared/widgets.dart';
import 'user_dialogs.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final me = auth.user;

    // Only superusers may open this page.
    if (me == null) {
      return const PendingTable(columns: 4);
    }
    if (!me.isSuperuser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.dashboard);
      });
      return const SizedBox.shrink();
    }

    final users = ref.watch(usersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Users',
          subtitle: 'Manage user accounts and permissions',
          action: FilledButton.icon(
            onPressed: () => UserFormDialog.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add User'),
          ),
        ),
        const SizedBox(height: 24),
        switch (users) {
          AsyncData(:final value) => _UsersTable(users: value, me: me),
          AsyncError(:final error) => Column(
              children: [
                Text(extractErrorMessage(error)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(usersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          _ => const PendingTable(columns: 4),
        },
      ],
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({required this.users, required this.me});

  final List<UserPublic> users;
  final UserPublic me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 64,
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Full Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(
                              user.fullName?.isNotEmpty == true
                                  ? user.fullName!
                                  : 'N/A',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: user.fullName?.isNotEmpty == true
                                    ? null
                                    : muted,
                              ),
                            ),
                            if (user.id == me.id) ...[
                              const SizedBox(width: 8),
                              const StatusBadge('You',
                                  variant: BadgeVariant.outline),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text(user.email)),
                      DataCell(
                        StatusBadge(
                          user.isSuperuser ? 'Superuser' : 'User',
                          variant: user.isSuperuser
                              ? BadgeVariant.primary
                              : BadgeVariant.secondary,
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: user.isActive
                                    ? Colors.green
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(user.isActive ? 'Active' : 'Inactive'),
                          ],
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: _UserActionsMenu(
                            user: user,
                            isCurrentUser: user.id == me.id,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _UserAction { edit, delete }

class _UserActionsMenu extends StatelessWidget {
  const _UserActionsMenu({required this.user, required this.isCurrentUser});

  final UserPublic user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<_UserAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) {
        switch (action) {
          case _UserAction.edit:
            UserFormDialog.show(context, user: user);
          case _UserAction.delete:
            DeleteUserDialog.show(context, user.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _UserAction.edit,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Edit User'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.delete,
          // Admins cannot delete themselves (backend rejects it too).
          enabled: !isCurrentUser,
          child: ListTile(
            dense: true,
            enabled: !isCurrentUser,
            leading: Icon(Icons.delete_outline, size: 18, color: error),
            title: Text('Delete User', style: TextStyle(color: error)),
          ),
        ),
      ],
    );
  }
}
