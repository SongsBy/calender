import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../shared/widgets.dart';

/// Add / Edit user dialog for admins. Pass `user` to edit.
class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, this.user});

  final UserPublic? user;

  static Future<void> show(BuildContext context, {UserPublic? user}) {
    return showDialog(
      context: context,
      builder: (_) => UserFormDialog(user: user),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _fullName =
      TextEditingController(text: widget.user?.fullName ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _isSuperuser = widget.user?.isSuperuser ?? false;
  late bool _isActive = widget.user?.isActive ?? false;
  bool _pending = false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    // On edit the password is optional; validate only when provided.
    if (_isEdit && (v == null || v.isEmpty)) return null;
    return Validators.password(v);
  }

  String? _validateConfirm(String? v) {
    if (_isEdit && _password.text.isEmpty && (v == null || v.isEmpty)) {
      return null;
    }
    return Validators.confirmPassword(
      () => _password.text,
      requiredMessage: 'Please confirm your password',
    )(v);
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    final email = _email.text.trim();
    final fullName = _fullName.text.trim();
    try {
      final notifier = ref.read(usersProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          widget.user!.id,
          UserUpdate(
            email: email,
            fullName: fullName,
            password: _password.text.isEmpty ? null : _password.text,
            isSuperuser: _isSuperuser,
            isActive: _isActive,
          ),
        );
        // Keep the sidebar/user menu in sync if the admin edited themselves.
        final me = ref.read(currentUserProvider);
        if (me != null && me.id == widget.user!.id) {
          await ref.read(authProvider.notifier).refreshUser();
        }
        Toast.success('User updated successfully');
      } else {
        await notifier.create(
          UserCreate(
            email: email,
            fullName: fullName.isEmpty ? null : fullName,
            password: _password.text,
            isSuperuser: _isSuperuser,
            isActive: _isActive,
          ),
        );
        Toast.success('User created successfully');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isEdit ? 'Edit User' : 'Add User'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit
                      ? 'Update the user details below.'
                      : 'Fill in the form below to add a new user to the system.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Email', required: true),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                  decoration:
                      const InputDecoration(hintText: 'user@example.com'),
                ),
                const SizedBox(height: 16),
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Full name'),
                ),
                const SizedBox(height: 16),
                FieldLabel(_isEdit ? 'Set Password' : 'Password',
                    required: !_isEdit),
                PasswordField(
                  controller: _password,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                FieldLabel('Confirm Password', required: !_isEdit),
                PasswordField(
                  controller: _confirm,
                  hintText: 'Confirm Password',
                  validator: _validateConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Is superuser?'),
                  value: _isSuperuser,
                  onChanged: (v) => setState(() => _isSuperuser = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Is active?'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _pending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          loading: _pending,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Delete confirmation dialog for a user (admin).
class DeleteUserDialog extends ConsumerStatefulWidget {
  const DeleteUserDialog({super.key, required this.id});

  final String id;

  static Future<void> show(BuildContext context, String id) {
    return showDialog(
      context: context,
      builder: (_) => DeleteUserDialog(id: id),
    );
  }

  @override
  ConsumerState<DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends ConsumerState<DeleteUserDialog> {
  bool _pending = false;

  Future<void> _delete() async {
    if (_pending) return;
    setState(() => _pending = true);
    try {
      await ref.read(usersProvider.notifier).delete(widget.id);
      Toast.success('The user was deleted successfully');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete User'),
      content: const SizedBox(
        width: 420,
        child: Text(
          'All items associated with this user will also be permanently '
          'deleted. Are you sure? You will not be able to undo this action.',
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
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
