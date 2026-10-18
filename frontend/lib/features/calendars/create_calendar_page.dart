import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../providers/calendars_provider.dart';
import '../../router.dart';
import '../../shared/ds.dart';

/// D. 캘린더 만들기 — 기본 · 입력 오류 · 저장 중.
class CreateCalendarPage extends ConsumerStatefulWidget {
  const CreateCalendarPage({super.key});

  @override
  ConsumerState<CreateCalendarPage> createState() => _CreateCalendarPageState();
}

class _CreateCalendarPageState extends ConsumerState<CreateCalendarPage> {
  static const _maxLength = 30;
  static const _suggestions = ['우리의 하루', '함께하는 주말'];
  final _name = TextEditingController();
  String? _error;
  String? _banner;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '캘린더 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
      _banner = null;
    });
    try {
      final calendar = await ref.read(calendarsServiceProvider).create(name);
      ref.invalidate(calendarsProvider);
      if (!mounted) return;
      context.go(Routes.invite(calendar.id));
    } catch (e) {
      if (mounted) setState(() => _banner = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _name.text.characters.length;
    return DsScreen(
      canPop: !_pending,
      header: DsHeader(
        title: '새 캘린더 만들기',
        backEnabled: !_pending,
        onBack: () => context.go(Routes.home),
      ),
      body: DsBody(
        children: [
          Row(
            children: [
              const DsSmile(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '두 사람이 함께 볼 캘린더의 이름을 지어 주세요.',
                  style: ds(15, height: 1.5),
                ),
              ),
            ],
          ),
          if (_banner != null) DsBanner(message: _banner!),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsTextField(
                controller: _name,
                label: '캘린더 이름',
                hint: '예: 우리의 하루',
                // 오류 메시지는 아래 글자 수와 같은 줄에 직접 그립니다.
                error: _error == null ? null : '',
                enabled: !_pending,
                maxLength: _maxLength,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _error == null
                          ? const SizedBox.shrink()
                          : DsErrorText(_error!),
                    ),
                    const SizedBox(width: 8),
                    DsHint('$count/$_maxLength'),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: DsHint('이런 이름은 어때요?'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in _suggestions)
                    _SuggestionChip(
                      label: suggestion,
                      enabled: !_pending,
                      onTap: () {
                        _name.text = suggestion;
                        _name.selection = TextSelection.collapsed(
                          offset: suggestion.length,
                        );
                        setState(() => _error = null);
                      },
                    ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: DsHint(
              '캘린더에는 나를 포함해 두 사람까지 참여할 수 있어요. 만든 뒤 초대코드로 상대방을 초대해요.',
            ),
          ),
        ],
      ),
      bottom: DsActions(
        children: [
          DsButton(
            label: '만들기',
            loadingLabel: '만드는 중…',
            loading: _pending,
            onPressed: _submit,
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
}

/// 제안 칩 — 36 높이, 패딩 14, 13.5px.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .45,
    child: Material(
      color: AppColors.fillDisabled,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: ds(13.5, weight: 600, color: const Color(0xFF6B4F3E)),
          ),
        ),
      ),
    ),
  );
}
