import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/config.dart';
import '../../providers/auth_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';

/// A. 로그인 — 기본 · 키보드 + 입력 누락 · 로그인 실패 · 서버 연결 실패 · 처리 중.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _Failure { none, credentials, offline, other }

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _idError;
  String? _pwError;
  _Failure _failure = _Failure.none;
  String _failureMessage = '';
  bool _pending = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    final id = _username.text.trim();
    final pw = _password.text;
    setState(() {
      _idError = id.isEmpty ? '아이디를 입력해 주세요.' : null;
      _pwError = pw.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    });
    if (id.isEmpty || pw.isEmpty) return;
    setState(() {
      _pending = true;
      _failure = _Failure.none;
    });
    try {
      await ref.read(authProvider.notifier).login(username: id, password: pw);
      // Router redirect sends us to the home once isLoggedIn flips.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isConnectionError(e)) {
          _failure = _Failure.offline;
        } else if (statusCode(e) == 401 || statusCode(e) == 400) {
          _failure = _Failure.credentials;
        } else {
          _failure = _Failure.other;
          _failureMessage = extractErrorMessage(e);
        }
      });
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _clearFailure() {
    if (_failure != _Failure.none) setState(() => _failure = _Failure.none);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final failedCredentials = _failure == _Failure.credentials;

    final banner = switch (_failure) {
      _Failure.none => null,
      _Failure.credentials => const DsBanner(
        message: '아이디 또는 비밀번호가 맞지 않아요. 다시 한 번 확인해 주세요.',
      ),
      _Failure.offline => DsBanner(
        kind: DsBannerKind.warn,
        icon: const DsIcon(
          DsIcons.wifiOff,
          size: 18,
          color: AppColors.onWarnContainer,
        ),
        message: '서버에 연결할 수 없어요. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
        actionLabel: '다시 시도',
        onAction: _submit,
      ),
      _Failure.other => DsBanner(message: _failureMessage),
    };

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTextField(
          controller: _username,
          label: '아이디',
          hint: '아이디를 입력해 주세요',
          error: _idError ?? (failedCredentials ? '' : null),
          enabled: !_pending,
          keyboardType: TextInputType.text,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          onChanged: (_) {
            if (_idError != null) setState(() => _idError = null);
            _clearFailure();
          },
        ),
        const SizedBox(height: 18),
        DsTextField(
          controller: _password,
          label: '비밀번호',
          hint: '비밀번호를 입력해 주세요',
          obscure: true,
          showObscureToggle: true,
          onObscureChanged: (visible) =>
              setState(() => _passwordVisible = visible),
          helper: _passwordVisible && _pwError == null
              ? '비밀번호가 화면에 보이고 있어요.'
              : null,
          error: _pwError ?? (failedCredentials ? '' : null),
          enabled: !_pending,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_pwError != null) setState(() => _pwError = null);
            _clearFailure();
          },
        ),
        const SizedBox(height: 24),
        DsButton(
          label:
              _failure == _Failure.credentials || _failure == _Failure.offline
              ? '다시 로그인'
              : '로그인',
          loadingLabel: '로그인 중…',
          loading: _pending,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        _LinkLine(
          text: '아직 계정이 없나요?',
          link: '회원가입',
          enabled: !_pending,
          onTap: () => context.go(Routes.signup),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  keyboard ? 0 : 28,
                  24,
                  keyboard ? 16 : 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (keyboard ? 16 : 56),
                  ),
                  child: IntrinsicHeight(
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (keyboard)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 22),
                              child: Row(
                                children: [
                                  DsLogoSmall(),
                                  SizedBox(width: 12),
                                  Text(
                                    AppConfig.appTitle,
                                    style: TextStyle(
                                      fontFamily: 'Yellowtail',
                                      fontSize: 30,
                                      height: 1.1,
                                      color: AppColors.wordmark,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: banner == null ? 40 : 28,
                              ),
                              child: Column(
                                children: [
                                  const DsLogo(),
                                  const SizedBox(height: 14),
                                  Text(
                                    AppConfig.appTitle,
                                    style: AppText.wordmark,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '두 사람의 일정을 한 곳에 모아요',
                                    style: ds(14, color: AppColors.brown500),
                                  ),
                                ],
                              ),
                            ),
                          if (banner != null) ...[
                            banner,
                            const SizedBox(height: 18),
                          ],
                          form,
                          if (!keyboard) ...[
                            const Spacer(),
                            const SizedBox(height: 24),
                            const DsWave(),
                            const SizedBox(height: 8),
                            Text(
                              '오늘도 같은 하루를 함께',
                              textAlign: TextAlign.center,
                              style: AppText.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "아직 계정이 없나요? 회원가입" — 밑줄 600 링크, 세로 48 터치 영역.
class _LinkLine extends StatelessWidget {
  const _LinkLine({
    required this.text,
    required this.link,
    required this.onTap,
    this.enabled = true,
  });
  final String text;
  final String link;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(text, style: ds(14, color: AppColors.brown500)),
      const SizedBox(width: 6),
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Text(
            link,
            style:
                ds(
                  14,
                  weight: 600,
                  color: enabled ? AppColors.brown900 : AppColors.brown500,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: enabled
                      ? AppColors.brown900
                      : AppColors.brown500,
                ),
          ),
        ),
      ),
    ],
  );
}

/// 회원가입·비밀번호 화면 하단의 “이미 계정이 있나요? 로그인으로 돌아가기”.
class AuthLinkLine extends StatelessWidget {
  const AuthLinkLine({
    super.key,
    required this.text,
    required this.link,
    required this.onTap,
    this.enabled = true,
  });
  final String text;
  final String link;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      _LinkLine(text: text, link: link, onTap: onTap, enabled: enabled);
}
