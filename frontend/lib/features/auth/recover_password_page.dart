import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../providers/app_providers.dart';
import '../../router.dart';
import '../../shared/ds.dart';
import 'login_page.dart';

/// 비밀번호 찾기 — 가입 때 적어 둔 이메일로 재설정 링크를 보냅니다.
class RecoverPasswordPage extends ConsumerStatefulWidget {
  const RecoverPasswordPage({super.key});

  @override
  ConsumerState<RecoverPasswordPage> createState() =>
      _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends ConsumerState<RecoverPasswordPage> {
  final _email = TextEditingController();
  static final _emailRule = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  String? _error;
  String? _bannerError;
  bool _sent = false;
  bool _pending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    final email = _email.text.trim();
    if (!_emailRule.hasMatch(email)) {
      setState(() => _error = '이메일 형식을 확인해 주세요.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
      _bannerError = null;
      _sent = false;
    });
    try {
      await ref.read(loginServiceProvider).recoverPassword(email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _bannerError = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => DsScreen(
    canPop: !_pending,
    header: DsHeader(
      title: '비밀번호 찾기',
      backEnabled: !_pending,
      onBack: () => context.go(Routes.login),
    ),
    body: DsBody(
      children: [
        Row(
          children: [
            const DsSmile(color: AppColors.pink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '가입할 때 적어 둔 이메일을 입력하면 비밀번호를 다시 정할 수 있는 링크를 보내 드려요.',
                style: ds(15, height: 1.5),
              ),
            ),
          ],
        ),
        if (_sent)
          const DsBanner(
            kind: DsBannerKind.ok,
            message: '재설정 링크를 보냈어요. 메일함을 확인해 주세요.',
          ),
        if (_bannerError != null) DsBanner(message: _bannerError!),
        DsTextField(
          controller: _email,
          label: '이메일',
          hint: '예: minji@example.com',
          error: _error,
          enabled: !_pending,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    ),
    bottom: DsActions(
      children: [
        DsButton(
          label: '재설정 링크 보내기',
          loadingLabel: '보내는 중…',
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
