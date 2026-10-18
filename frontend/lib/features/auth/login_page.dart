import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import '../../shared/widgets.dart';
import 'auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending || !_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(username: _username.text.trim(), password: _password.text);
      // Router redirect sends us to the dashboard once isLoggedIn flips.
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
            const AuthTitle('Login to your account'),
            const SizedBox(height: 24),
            const FieldLabel('Username or existing email'),
            TextFormField(
              controller: _username,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: Validators.required,
              decoration: const InputDecoration(hintText: 'user_one'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: FieldLabel('Password')),
                InkWell(
                  onTap: () => context.go(Routes.recoverPassword),
                  child: Text(
                    'Forgot your password?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            PasswordField(
              controller: _password,
              validator: Validators.password,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              loading: _pending,
              expand: true,
              onPressed: _submit,
              child: const Text('Log In'),
            ),
            const SizedBox(height: 24),
            AuthLinkLine(
              text: "Don't have an account yet?",
              linkText: 'Sign up',
              onTap: () => context.go(Routes.signup),
            ),
          ],
        ),
      ),
    );
  }
}
