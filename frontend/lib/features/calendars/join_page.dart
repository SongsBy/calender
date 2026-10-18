import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../providers/calendars_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';

/// E3~E8. 초대코드로 참여하기 — 기본 · 만료/잘못된 코드 · 사용된 코드 · 정원 초과 ·
/// 이미 참여 중 · 요청 횟수 제한.
class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key});

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

enum _Notice { none, alreadyMember, rateLimited }

class _JoinPageState extends ConsumerState<JoinPage> {
  final _code = TextEditingController();
  String? _error;
  String? _banner;
  _Notice _notice = _Notice.none;
  int _retryIn = 0;
  Timer? _retryTimer;
  bool _pending = false;

  static final _codeRule = RegExp(r'^[A-HJ-NP-Z2-9]{12}$');

  @override
  void dispose() {
    _retryTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  String get _normalized =>
      _code.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    final formatted = _InviteCodeFormatter.format(text);
    _code.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _reset();
  }

  void _reset() {
    if (_error != null || _banner != null || _notice == _Notice.alreadyMember) {
      setState(() {
        _error = null;
        _banner = null;
        if (_notice == _Notice.alreadyMember) _notice = _Notice.none;
      });
    }
  }

  void _startRetryCountdown() {
    _retryTimer?.cancel();
    _retryIn = 60;
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _retryIn--;
        if (_retryIn <= 0) {
          timer.cancel();
          _notice = _Notice.none;
          _banner = null;
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_pending || _notice == _Notice.rateLimited) return;
    final code = _normalized;
    if (!_codeRule.hasMatch(code)) {
      setState(() {
        _error = code.isEmpty ? '초대코드를 입력해 주세요.' : '12자리 초대코드를 확인해 주세요.';
        _banner = null;
        _notice = _Notice.none;
      });
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
      _banner = null;
      _notice = _Notice.none;
    });
    try {
      final calendar = await ref
          .read(calendarsServiceProvider)
          .acceptInvitation(code);
      ref.invalidate(calendarsProvider);
      if (!mounted) return;
      showDsSnack(context, "'${calendar.name}'에 참여했어요");
      // 홈은 연결된 캘린더를 우선 보여 주므로 홈으로 돌아갑니다.
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        switch (errorCode(e)) {
          case 'INVALID_INVITATION':
            _error = '만료되었거나 올바르지 않은 코드예요. 상대방에게 새 코드를 요청해 주세요.';
          case 'INVITATION_USED':
            _error = '이미 사용된 코드예요. 코드는 한 번만 쓸 수 있어요.';
          case 'CALENDAR_FULL':
            _error = '이 캘린더에는 이미 두 사람이 참여하고 있어요. 더는 참여할 수 없어요.';
          case 'ALREADY_MEMBER':
            _notice = _Notice.alreadyMember;
          default:
            if (statusCode(e) == 429) {
              _notice = _Notice.rateLimited;
              _banner = '요청이 너무 많았어요. 잠시 후(약 1분 뒤) 다시 시도해 주세요.';
              _startRetryCountdown();
            } else {
              _banner = extractErrorMessage(e);
            }
        }
      });
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => DsScreen(
    canPop: !_pending,
    header: DsHeader(
      title: '초대코드로 참여하기',
      backEnabled: !_pending,
      onBack: () => context.go(Routes.home),
    ),
    body: DsBody(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              const DsSmile(color: AppColors.pink),
              const SizedBox(height: 12),
              Text(
                '상대방이 보낸 12자리 초대코드를 입력해 주세요.',
                textAlign: TextAlign.center,
                style: ds(15, color: AppColors.brown700, height: 1.5),
              ),
            ],
          ),
        ),
        DsTextField(
          controller: _code,
          label: '초대코드',
          hint: '7K4M Q2XR 9ZTB',
          helper: '띄어쓰기나 하이픈은 자동으로 정리해요.',
          error: _error,
          enabled: !_pending,
          minHeight: 60,
          textAlign: TextAlign.center,
          textStyle: ds(20, letterSpacing: 2, height: 1.3, tabular: true),
          textCapitalization: TextCapitalization.characters,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          inputFormatters: [_InviteCodeFormatter()],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => _reset(),
          suffix: DsButton(
            label: '붙여넣기',
            variant: DsButtonVariant.text,
            height: 44,
            fontSize: 14,
            onPressed: _pending ? null : _paste,
          ),
        ),
        if (_notice == _Notice.alreadyMember)
          DsBanner(
            kind: DsBannerKind.warn,
            icon: const DsInfoIcon(),
            centered: true,
            message: '이미 참여 중인 캘린더예요.',
            actionLabel: '캘린더 목록',
            onAction: () => context.go(Routes.home),
          ),
        if (_banner != null) DsBanner(message: _banner!),
      ],
    ),
    bottom: DsActions(
      children: [
        DsButton(
          label: _notice == _Notice.rateLimited
              ? '잠시 후 다시 시도${_retryIn > 0 ? ' ($_retryIn초)' : ''}'
              : '참여하기',
          loadingLabel: '참여 중…',
          loading: _pending,
          onPressed: _notice == _Notice.rateLimited ? null : _submit,
        ),
        DsButton(
          label: '취소',
          variant: DsButtonVariant.text,
          onPressed: _pending ? null : () => context.go(Routes.home),
        ),
      ],
    ),
  );
}

/// 대문자로 바꾸고 영숫자만 남겨 4자리씩 띄어 씁니다 (최대 12자).
class _InviteCodeFormatter extends TextInputFormatter {
  static String format(String raw) {
    final chars = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped = chars.length > 12 ? chars.substring(0, 12) : chars;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clipped[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
