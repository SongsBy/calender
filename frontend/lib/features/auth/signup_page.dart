import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import '../../shared/widgets.dart';
import 'auth_layout.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await ref
          .read(authProvider.notifier)
          .signUp(
            UserRegister(
              username: _username.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              password: _password.text,
              fullName: _fullName.text.trim(),
            ),
          );
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
            const AuthTitle('Create an account'),
            const SizedBox(height: 24),
            const FieldLabel('Full Name'),
            TextFormField(
              controller: _fullName,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (v) =>
                  Validators.required(v, message: 'Full Name is required'),
              decoration: const InputDecoration(hintText: 'User'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Username'),
            TextFormField(
              controller: _username,
              autofillHints: const [AutofillHints.newUsername],
              textInputAction: TextInputAction.next,
              validator: Validators.username,
              decoration: const InputDecoration(hintText: 'user_one'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Email (optional, for password recovery)'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? null : Validators.email(v),
              decoration: const InputDecoration(hintText: 'user@example.com'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Password'),
            PasswordField(
              controller: _password,
              validator: Validators.password,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Confirm Password'),
            PasswordField(
              controller: _confirm,
              hintText: 'Confirm Password',
              validator: Validators.confirmPassword(() => _password.text),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              loading: _pending,
              expand: true,
              onPressed: _submit,
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 24),
            AuthLinkLine(
              text: 'Already have an account?',
              linkText: 'Log in',
              onTap: () => context.go(Routes.login),
            ),
          ],
        ),
      ),
    );
  }
}
