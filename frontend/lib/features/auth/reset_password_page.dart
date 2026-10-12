import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../router.dart';
import '../../shared/widgets.dart';
import 'auth_layout.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  /// Token from the `?token=` query parameter of the recovery email link.
  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await ref.read(loginServiceProvider).resetPassword(
            NewPassword(token: widget.token, newPassword: _newPassword.text),
          );
      Toast.success('Password updated successfully');
      if (mounted) context.go(Routes.login);
    } catch (e) {
      Toast.error(extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthTitle('Reset Password'),
            const SizedBox(height: 24),
            const FieldLabel('New Password'),
            PasswordField(
              controller: _newPassword,
              hintText: 'New Password',
              validator: Validators.password,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Confirm Password'),
            PasswordField(
              controller: _confirm,
              hintText: 'Confirm Password',
              validator: Validators.confirmPassword(() => _newPassword.text),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              loading: _pending,
              expand: true,
              onPressed: _submit,
              child: const Text('Reset Password'),
            ),
            const SizedBox(height: 24),
            AuthLinkLine(
              text: 'Remember your password?',
              linkText: 'Log in',
              onTap: () => context.go(Routes.login),
            ),
          ],
        ),
      ),
    );
  }
}
