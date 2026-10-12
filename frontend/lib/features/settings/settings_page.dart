import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'User Settings',
            subtitle: 'Manage your account settings and preferences',
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'My profile'),
                Tab(text: 'Password'),
                Tab(text: 'Danger zone'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tabs inside a scrolling page: size to content rather than
          // using an Expanded TabBarView.
          _TabContent(user: user),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.user});

  final UserPublic user;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => switch (controller.index) {
        0 => _UserInformation(user: user),
        1 => const _ChangePassword(),
        _ => const _DeleteAccount(),
      },
    );
  }
}

/// "My profile" tab.
class _UserInformation extends ConsumerStatefulWidget {
  const _UserInformation({required this.user});

  final UserPublic user;

  @override
  ConsumerState<_UserInformation> createState() => _UserInformationState();
}

class _UserInformationState extends ConsumerState<_UserInformation> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName =
      TextEditingController(text: widget.user.fullName ?? '');
  late final _email = TextEditingController(text: widget.user.email);
  bool _editMode = false;
  bool _pending = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  void _cancel() {
    _fullName.text = widget.user.fullName ?? '';
    _email.text = widget.user.email;
    setState(() => _editMode = false);
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      final updated = await ref.read(usersServiceProvider).updateUserMe(
            UserUpdateMe(
              fullName: _fullName.text.trim(),
              email: _email.text.trim(),
            ),
          );
      ref.read(authProvider.notifier).setUser(updated);
      Toast.success('User updated successfully');
      setState(() => _editMode = false);
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Full name'),
            if (_editMode)
              TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.maxLength(v, 30),
                decoration: const InputDecoration(hintText: 'Full name'),
              )
            else
              Text(
                widget.user.fullName?.isNotEmpty == true
                    ? widget.user.fullName!
                    : 'N/A',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: widget.user.fullName?.isNotEmpty == true
                      ? null
                      : muted,
                ),
              ),
            const SizedBox(height: 16),
            const FieldLabel('Email'),
            if (_editMode)
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
                decoration:
                    const InputDecoration(hintText: 'user@example.com'),
              )
            else
              Text(widget.user.email, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (_editMode)
              Row(
                children: [
                  LoadingButton(
                    loading: _pending,
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _pending ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: () => setState(() => _editMode = true),
                child: const Text('Edit'),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Password" tab.
class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();

  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await ref.read(usersServiceProvider).updatePasswordMe(
            UpdatePassword(
              currentPassword: _current.text,
              newPassword: _newPassword.text,
            ),
          );
      Toast.success('Password updated successfully');
      _current.clear();
      _newPassword.clear();
      _confirm.clear();
      _formKey.currentState!.reset();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Current Password'),
            PasswordField(
              controller: _current,
              hintText: '••••••••',
              validator: Validators.password,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const FieldLabel('New Password'),
            PasswordField(
              controller: _newPassword,
              hintText: '••••••••',
              validator: Validators.password,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Confirm Password'),
            PasswordField(
              controller: _confirm,
              hintText: '••••••••',
              validator: Validators.confirmPassword(() => _newPassword.text),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              loading: _pending,
              onPressed: _submit,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Danger zone" tab.
class _DeleteAccount extends ConsumerWidget {
  const _DeleteAccount();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delete Account',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Permanently delete your data and everything associated with your '
          'account.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const _DeleteConfirmationDialog(),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteConfirmationDialog extends ConsumerStatefulWidget {
  const _DeleteConfirmationDialog();

  @override
  ConsumerState<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState
    extends ConsumerState<_DeleteConfirmationDialog> {
  bool _pending = false;

  Future<void> _delete() async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await ref.read(usersServiceProvider).deleteUserMe();
      Toast.success('Your account has been successfully deleted');
      if (mounted) Navigator.of(context).pop();
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmation Required'),
      content: const SizedBox(
        width: 420,
        child: Text(
          'All your account data will be permanently deleted. If you are '
          'sure, please click Confirm to proceed. This action cannot be '
          'undone.',
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          loading: _pending,
          destructive: true,
          onPressed: _delete,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
