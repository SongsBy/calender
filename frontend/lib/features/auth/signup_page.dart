import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/toast.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import 'login_page.dart';

/// B. 회원가입 — 기본 · 아이디 중복 + 비밀번호 불일치 · 가입 중.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _errors = <String, String>{};
  String? _banner;
  bool _pending = false;

  static final _usernameRule = RegExp(r'^[a-z0-9_]{3,30}$');
  static final _emailRule = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  bool _validate() {
    final errors = <String, String>{};
    final id = _username.text.trim().toLowerCase();
    if (id.isEmpty) {
      errors['id'] = '아이디를 입력해 주세요.';
    } else if (!_usernameRule.hasMatch(id) || id.startsWith('legacy_')) {
      errors['id'] = '영문 소문자·숫자·밑줄로 3~30자를 입력해 주세요.';
    }
    if (_password.text.isEmpty) {
      errors['pw'] = '비밀번호를 입력해 주세요.';
    } else if (_password.text.length < 8) {
      errors['pw'] = '8자 이상 입력해 주세요.';
    } else if (_password.text.length > 128) {
      errors['pw'] = '비밀번호는 128자까지만 쓸 수 있어요.';
    }
    if (_confirm.text.isEmpty) {
      errors['pw2'] = '비밀번호를 한 번 더 입력해 주세요.';
    } else if (_confirm.text != _password.text) {
      errors['pw2'] = '비밀번호가 서로 달라요.';
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !_emailRule.hasMatch(email)) {
      errors['email'] = '이메일 형식을 확인해 주세요. 비워 두어도 괜찮아요.';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    if (_pending || !_validate()) return;
    setState(() {
      _pending = true;
      _banner = null;
    });
    final username = _username.text.trim().toLowerCase();
    final email = _email.text.trim();
    try {
      final auth = ref.read(authProvider.notifier);
      await auth.signUp(
        UserRegister(
          username: username,
          email: email.isEmpty ? null : email,
          password: _password.text,
          fullName: _fullName.text.trim().isEmpty
              ? null
              : _fullName.text.trim(),
        ),
      );
      // 가입 직후 바로 로그인해 홈으로 보냅니다. 로그인이 실패해도 가입은
      // 끝난 상태이므로, 다시 가입하지 않도록 알리고 로그인 화면으로 보냅니다.
      try {
        await auth.login(username: username, password: _password.text);
      } catch (_) {
        if (!mounted) return;
        Toast.success('가입이 완료됐어요. 만든 아이디로 로그인해 주세요.');
        context.go(Routes.login);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = extractErrorMessage(e);
        if (statusCode(e) == 409 && message.toLowerCase().contains('email')) {
          // 서버는 이메일 중복도 409로 알립니다.
          _errors['email'] = '이미 사용 중인 이메일이에요. 다른 주소를 쓰거나 비워 두세요.';
        } else if (statusCode(e) == 409) {
          _errors['id'] = '이미 사용 중인 아이디예요. 다른 아이디를 골라 주세요.';
        } else {
          _banner = message;
        }
      });
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _clear(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  @override
  Widget build(BuildContext context) => DsScreen(
    canPop: !_pending,
    header: DsHeader(
      title: '회원가입',
      backEnabled: !_pending,
      onBack: () => context.go(Routes.login),
    ),
    body: AutofillGroup(
      child: DsBody(
        gap: 14,
        children: [
          if (_banner != null) DsBanner(message: _banner!),
          DsTextField(
            controller: _username,
            label: '아이디',
            hint: '아이디를 입력해 주세요',
            helper: _errors['id'] == null ? '영문 소문자·숫자·밑줄 3~30자' : null,
            error: _errors['id'],
            enabled: !_pending,
            autocorrect: false,
            autofillHints: const [AutofillHints.newUsername],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clear('id'),
          ),
          DsTextField(
            controller: _password,
            label: '비밀번호',
            hint: '비밀번호를 입력해 주세요',
            obscure: true,
            showObscureToggle: true,
            helper: _errors['pw'] == null ? '8자 이상 입력해 주세요' : null,
            error: _errors['pw'],
            enabled: !_pending,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clear('pw'),
          ),
          DsTextField(
            controller: _confirm,
            label: '비밀번호 확인',
            hint: '비밀번호를 한 번 더 입력해 주세요',
            obscure: true,
            helper: _errors['pw2'] == null ? '같은 비밀번호를 한 번 더 입력해 주세요' : null,
            error: _errors['pw2'],
            enabled: !_pending,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clear('pw2'),
          ),
          DsTextField(
            controller: _fullName,
            label: '이름',
            optional: true,
            hint: '예: 민지',
            helper: '상대방에게 보이는 이름이에요. 비우면 아이디가 보여요',
            enabled: !_pending,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
          ),
          DsTextField(
            controller: _email,
            label: '이메일',
            optional: true,
            hint: '예: minji@example.com',
            helper: _errors['email'] == null
                ? '비밀번호를 잊었을 때 연락받을 주소예요. 지금은 선택이에요'
                : null,
            error: _errors['email'],
            enabled: !_pending,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => _clear('email'),
          ),
        ],
      ),
    ),
    bottom: DsActions(
      children: [
        DsButton(
          label: '가입하기',
          loadingLabel: '가입 중…',
          loading: _pending,
          onPressed: _submit,
        ),
        AuthLinkLine(
          text: '이미 계정이 있나요?',
          link: '로그인으로 돌아가기',
          enabled: !_pending,
          onTap: () => context.go(Routes.login),
        ),
      ],
    ),
  );
}
