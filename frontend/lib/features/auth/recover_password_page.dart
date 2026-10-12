import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../providers/app_providers.dart';
import '../../router.dart';
import '../../shared/widgets.dart';
import 'auth_layout.dart';

class RecoverPasswordPage extends ConsumerStatefulWidget {
  const RecoverPasswordPage({super.key});

  @override
  ConsumerState<RecoverPasswordPage> createState() =>
      _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends ConsumerState<RecoverPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await ref.read(loginServiceProvider).recoverPassword(_email.text.trim());
      Toast.success('Password recovery email sent successfully');
      _email.clear();
      _formKey.currentState!.reset();
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
            const AuthTitle('Password Recovery'),
            const SizedBox(height: 24),
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'user@example.com'),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              loading: _pending,
              expand: true,
              onPressed: _submit,
              child: const Text('Continue'),
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
