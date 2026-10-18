import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import 'login_page.dart';

/// 비밀번호 재설정 — 메일 링크의 `?token=`으로 들어옵니다.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  final _errors = <String, String>{};
  String? _banner;
  bool _pending = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final errors = <String, String>{};
    if (_newPassword.text.isEmpty) {
      errors['pw'] = '새 비밀번호를 입력해 주세요.';
    } else if (_newPassword.text.length < 8) {
      errors['pw'] = '8자 이상 입력해 주세요.';
    }
    if (_confirm.text != _newPassword.text) {
      errors['pw2'] = '비밀번호가 서로 달라요.';
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
    try {
      await ref
          .read(loginServiceProvider)
          .resetPassword(
            NewPassword(token: widget.token, newPassword: _newPassword.text),
          );
      if (!mounted) return;
      showDsSnack(context, '비밀번호를 바꿨어요. 다시 로그인해 주세요.');
      context.go(Routes.login);
    } catch (e) {
      if (mounted) setState(() => _banner = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => DsScreen(
    canPop: !_pending,
    header: DsHeader(
      title: '비밀번호 재설정',
      backEnabled: !_pending,
      onBack: () => context.go(Routes.login),
    ),
    body: DsBody(
      children: [
        if (_banner != null) DsBanner(message: _banner!),
        DsTextField(
          controller: _newPassword,
          label: '새 비밀번호',
          hint: '새 비밀번호를 입력해 주세요',
          obscure: true,
          showObscureToggle: true,
          helper: _errors['pw'] == null ? '8자 이상 입력해 주세요' : null,
          error: _errors['pw'],
          enabled: !_pending,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _errors.remove('pw')),
        ),
        DsTextField(
          controller: _confirm,
          label: '비밀번호 확인',
          hint: '비밀번호를 한 번 더 입력해 주세요',
          obscure: true,
          error: _errors['pw2'],
          enabled: !_pending,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() => _errors.remove('pw2')),
        ),
      ],
    ),
    bottom: DsActions(
      children: [
        DsButton(
          label: '비밀번호 바꾸기',
          loadingLabel: '바꾸는 중…',
          loading: _pending,
          onPressed: _submit,
        ),
        AuthLinkLine(
          text: '비밀번호가 기억났나요?',
          link: '로그인으로 돌아가기',
          enabled: !_pending,
          onTap: () => context.go(Routes.login),
        ),
      ],
    ),
  );
}
