import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'ds_icons.dart';

export '../theme.dart';
export 'ds_art.dart';
export 'ds_icons.dart';

/// 디자인 시스템 컴포넌트 (DS-Components 보드).
/// 상태 이름(기본·눌림·비활성·로딩·오류)은 WidgetState와 1:1로 대응합니다.

// ---------------------------------------------------------------------------
// 버튼
// ---------------------------------------------------------------------------

enum DsButtonVariant { primary, secondary, danger, text }

/// 높이 52 · 모서리 18 · 좌우 패딩 20 · 16/600. 텍스트 버튼은 48/패딩 12.
/// 비활성은 opacity .45, 로딩은 비활성 + 스피너 18 + 문구로 중복 탭을 막습니다.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.height,
    this.fontSize = 16,
    this.foregroundColor,
    this.padding,
    this.alignment,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final bool loading;
  final String? loadingLabel;

  /// 20px 아이콘 패스 (`DsIcons`). 글자 앞에 gap 8로 놓입니다.
  final String? icon;
  final double? height;
  final double fontSize;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final isText = variant == DsButtonVariant.text;
    final fg =
        foregroundColor ??
        switch (variant) {
          DsButtonVariant.danger => Colors.white,
          DsButtonVariant.text => AppColors.brown700,
          _ => AppColors.brown900,
        };
    final (Color base, Color pressed) = switch (variant) {
      DsButtonVariant.primary => (AppColors.butter, AppColors.butterPressed),
      DsButtonVariant.secondary => (
        AppColors.surface,
        AppColors.secondaryPressed,
      ),
      DsButtonVariant.danger => (AppColors.error, AppColors.errorPressed),
      DsButtonVariant.text => (Colors.transparent, AppColors.secondaryPressed),
    };
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(48, height ?? (isText ? 48 : 52)),
      ),
      maximumSize: const WidgetStatePropertyAll(Size.infinite),
      padding: WidgetStatePropertyAll(
        padding ?? EdgeInsets.symmetric(horizontal: isText ? 12 : 20),
      ),
      alignment: alignment,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      side: variant == DsButtonVariant.secondary
          ? const WidgetStatePropertyAll(
              BorderSide(color: AppColors.outline, width: 1.5),
            )
          : null,
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed) ? pressed : base,
      ),
      foregroundColor: WidgetStatePropertyAll(fg),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(
        ds(fontSize, weight: 600, height: 1.2, color: fg),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final text = loading ? (loadingLabel ?? label) : label;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          DsSpinner(color: fg),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          DsIcon(icon!, size: 20, color: fg, stroke: 2),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ds(fontSize, weight: 600, height: 1.2, color: fg),
          ),
        ),
      ],
    );
    // 비활성은 색을 바꾸지 않고 opacity .45로만 표현합니다.
    final button = TextButton(
      style: style,
      onPressed: enabled ? onPressed : null,
      child: child,
    );
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: IgnorePointer(ignoring: !enabled, child: button),
    );
  }
}

/// 48×48 · 모서리 16 아이콘 버튼. `filled`면 카드 배경 + 1.5px 테두리.
class DsIconButton extends StatelessWidget {
  const DsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.filled = false,
    this.fillColor,
    this.borderColor,
    this.iconSize = 24,
    this.iconColor = AppColors.brown900,
    this.stroke = 2,
  });

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool filled;
  final Color? fillColor;
  final Color? borderColor;
  final double iconSize;
  final Color iconColor;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Material(
          color: filled ? (fillColor ?? AppColors.surface) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            side: filled
                ? BorderSide(
                    color: borderColor ?? AppColors.outline,
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.input),
            highlightColor: AppColors.secondaryPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: DsIcon(
                  icon,
                  size: iconSize,
                  color: iconColor,
                  stroke: stroke,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 스피너 18 · 2.5px · 트랙 22% 알파.
class DsSpinner extends StatelessWidget {
  const DsSpinner({super.key, this.size = 18, this.color = AppColors.brown900});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      color: color,
      backgroundColor: color.withValues(alpha: .22),
    ),
  );
}

// ---------------------------------------------------------------------------
// 텍스트 · 라벨 · 힌트 · 오류
// ---------------------------------------------------------------------------

/// 입력 라벨 13/600 #5C3D2B. 선택 입력은 라벨 옆 “(선택)”.
class DsLabel extends StatelessWidget {
  const DsLabel(
    this.text, {
    super.key,
    this.optional = false,
    this.required = false,
  });
  final String text;
  final bool optional;
  final bool required;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      style: AppText.label,
      children: [
        if (optional)
          TextSpan(
            text: ' (선택)',
            style: ds(13, color: AppColors.brown500, height: 18 / 13),
          ),
        if (required)
          TextSpan(
            text: ' *',
            style: ds(13, weight: 600, color: AppColors.error, height: 18 / 13),
          ),
      ],
    ),
  );
}

/// 힌트 12.5px #7A5A47.
class DsHint extends StatelessWidget {
  const DsHint(
    this.text, {
    super.key,
    this.textAlign,
    this.maxLines,
    this.style,
  });
  final String text;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: style ?? AppText.caption,
  );
}

/// 오류 메시지 — 아이콘 16 + 13px #9A3524.
class DsErrorText extends StatelessWidget {
  const DsErrorText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(padding: EdgeInsets.only(top: 1.5), child: DsErrorIcon()),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: ds(13, color: AppColors.errorText, height: 1.4),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 입력
// ---------------------------------------------------------------------------

/// 높이 52 · 모서리 16 · 테두리 1.5 #E6D6BA · 패딩 16 · 글자 16.
/// 포커스: #D99A1E + 3px 버터 링(38%). 오류: #B8432F + 3px 붉은 링(14%).
/// 비활성: 배경 #F3EADA 글자 #8A7260.
class DsTextField extends StatefulWidget {
  const DsTextField({
    super.key,
    this.controller,
    this.label,
    this.optional = false,
    this.required = false,
    this.hint,
    this.helper,
    this.error,
    this.counter,
    this.enabled = true,
    this.obscure = false,
    this.showObscureToggle = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.suffix,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.focusNode,
    this.autocorrect = true,
    this.minHeight = 52,
    this.onObscureChanged,
  });

  final TextEditingController? controller;
  final String? label;
  final bool optional;
  final bool required;
  final String? hint;
  final String? helper;
  final String? error;

  /// 라벨 줄 오른쪽에 놓이는 글자 수 표시 ("0/30").
  final String? counter;
  final bool enabled;
  final bool obscure;
  final bool showObscureToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool autocorrect;
  final double minHeight;

  /// 비밀번호 보기/숨기기 토글이 바뀔 때 (true = 화면에 보임).
  final ValueChanged<bool>? onObscureChanged;

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late bool _obscured = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final focused = _focus.hasFocus && widget.enabled;
    final border = hasError
        ? AppColors.error
        : focused
        ? AppColors.butterDeep
        : AppColors.outline;
    final ring = hasError
        ? AppColors.errorRing
        : focused
        ? AppColors.focusRing
        : null;
    final multiline = (widget.maxLines ?? 1) != 1;
    final style = (widget.textStyle ?? AppText.body).copyWith(
      color: widget.enabled ? null : AppColors.disabledText,
    );
    final showToggle = widget.showObscureToggle;
    final suffix = showToggle
        ? Semantics(
            button: true,
            label: _obscured ? '비밀번호 보기' : '비밀번호 숨기기',
            child: InkWell(
              onTap: widget.enabled
                  ? () {
                      setState(() => _obscured = !_obscured);
                      widget.onObscureChanged?.call(!_obscured);
                    }
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: DsIcon(
                    _obscured ? DsIcons.eye : DsIcons.eyeOff,
                    size: 22,
                    color: AppColors.brown700,
                    stroke: 1.8,
                  ),
                ),
              ),
            ),
          )
        : widget.suffix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null || widget.counter != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.label != null)
                  Expanded(
                    child: DsLabel(
                      widget.label!,
                      optional: widget.optional,
                      required: widget.required,
                    ),
                  )
                else
                  const Spacer(),
                if (widget.counter != null) DsHint(widget.counter!),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: BoxConstraints(minHeight: widget.minHeight),
          decoration: BoxDecoration(
            color: widget.enabled ? AppColors.surface : AppColors.fillDisabled,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: border, width: 1.5),
            boxShadow: ring == null
                ? null
                : [BoxShadow(color: ring, spreadRadius: 3)],
          ),
          child: Row(
            crossAxisAlignment: multiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: suffix == null ? 16 : 8,
                    top: multiline ? 12 : 0,
                    bottom: multiline ? 12 : 0,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    obscureText: _obscured,
                    autocorrect: widget.autocorrect && !_obscured,
                    enableSuggestions: !_obscured,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    onChanged: widget.onChanged,
                    maxLength: widget.maxLength,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    textAlign: widget.textAlign,
                    textCapitalization: widget.textCapitalization,
                    inputFormatters: widget.inputFormatters,
                    autofocus: widget.autofocus,
                    cursorColor: AppColors.brown900,
                    style: style,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      isDense: true,
                      filled: false,
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: multiline ? 0 : 14,
                      ),
                      hintText: widget.hint,
                      hintStyle: style.copyWith(color: AppColors.placeholder),
                    ),
                  ),
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: EdgeInsets.only(
                    right: showToggle ? 2 : 8,
                    top: multiline ? 2 : 0,
                  ),
                  child: suffix,
                ),
            ],
          ),
        ),
        // error == '' 이면 테두리만 붉게 표시하고 메시지는 생략합니다 (로그인 실패).
        if (hasError && widget.error!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: DsErrorText(widget.error!),
          ),
        ],
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: DsHint(widget.helper!),
          ),
        ],
      ],
    );
  }
}

/// 날짜/시간 선택 필드 — 입력란과 같은 껍데기(52/16/1.5)에 값 + 오른쪽 아이콘 20.
class DsPickerField extends StatelessWidget {
  const DsPickerField({
    super.key,
    required this.value,
    required this.icon,
    required this.onTap,
    this.error = false,
    this.enabled = true,
    this.semanticLabel,
  });
  final String value;
  final String icon;
  final VoidCallback? onTap;
  final bool error;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Semantics(
      button: true,
      label: semanticLabel ?? value,
      child: Material(
        color: active ? AppColors.surface : AppColors.fillDisabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: BorderSide(
            color: error ? AppColors.error : AppColors.outline,
            width: 1.5,
          ),
        ),
        shadowColor: Colors.transparent,
        child: Container(
          decoration: error
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  boxShadow: const [
                    BoxShadow(color: AppColors.errorRing, spreadRadius: 3),
                  ],
                )
              : null,
          child: InkWell(
            onTap: active ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.input),
            highlightColor: AppColors.secondaryPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: active ? null : AppColors.disabledText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DsIcon(
                    icon,
                    size: 20,
                    color: AppColors.brown700,
                    stroke: 1.8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 종일 스위치 52×32 · 노브 26 · 켜짐 #F6C445 + 체크.
class DsSwitch extends StatelessWidget {
  const DsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52,
            height: 32,
            decoration: BoxDecoration(
              color: value ? AppColors.butter : AppColors.outline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.snackShadow,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: value
                    ? const Center(
                        child: DsIcon(DsIcons.check, size: 12, stroke: 3.5),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 22×22 체크박스 — 모서리 6 · 테두리 1.5 #D9C5A3 · 선택 시 버터 채움 + 브라운 체크.
class DsCheckbox extends StatelessWidget {
  const DsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.error = false,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      checked: value,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AppColors.butter : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: error
                    ? AppColors.error
                    : value
                    ? AppColors.butter
                    : AppColors.dashed,
                width: error ? 2 : 1.5,
              ),
            ),
            child: value
                ? const Center(
                    child: DsIcon(DsIcons.check, size: 14, stroke: 3),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// 22×22 라디오 — 선택 시 #D99A1E 채움.
class DsRadio extends StatelessWidget {
  const DsRadio({super.key, required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.butterDeep : AppColors.dashed,
            width: selected ? 7 : 1.5,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 칩 · 카드 · 배너 · 스켈레톤
// ---------------------------------------------------------------------------

enum DsChipVariant { me, partner, wait, dashed, ok }

/// 높이 26 · 패딩 10 · 12.5/600 · 알약. 일정 카드용은 `small`(22px).
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    this.variant = DsChipVariant.wait,
    this.dot = false,
    this.small = false,
    this.maxWidth = 160,
    this.leading,
  });

  final String label;
  final DsChipVariant variant;

  /// 참여자 점(8px, small이면 6px).
  final bool dot;
  final bool small;
  final double? maxWidth;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final (
      Color bg,
      Color fg,
      Color? dotColor,
      Border? border,
    ) = switch (variant) {
      DsChipVariant.me => (
        AppColors.butterContainer,
        AppColors.onButterContainer,
        AppColors.me,
        null,
      ),
      DsChipVariant.partner => (
        AppColors.pinkContainer,
        AppColors.onPinkContainer,
        AppColors.partner,
        null,
      ),
      DsChipVariant.wait => (
        AppColors.fillDisabled,
        const Color(0xFF6B4F3E),
        null,
        null,
      ),
      DsChipVariant.dashed => (
        Colors.transparent,
        AppColors.brown500,
        null,
        Border.all(color: AppColors.dashed, width: 1.5),
      ),
      DsChipVariant.ok => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
        null,
        null,
      ),
    };
    final dotSize = small ? 6.0 : 8.0;
    return Container(
      height: small ? 22 : 26,
      constraints: maxWidth == null
          ? null
          : BoxConstraints(maxWidth: maxWidth!),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          if (dot && dotColor != null) ...[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: ds(
                small ? 12 : 12.5,
                weight: variant == DsChipVariant.dashed ? 500 : 600,
                color: fg,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 참여자 칩 — 나는 버터, 상대는 핑크 (로그인한 사용자 기준). 내 칩에는 “(나)”를 붙입니다.
class DsMemberChip extends StatelessWidget {
  const DsMemberChip({
    super.key,
    required this.name,
    required this.isMe,
    this.small = false,
    this.suffixMe = true,
  });
  final String name;
  final bool isMe;
  final bool small;
  final bool suffixMe;
  @override
  Widget build(BuildContext context) => DsChip(
    label: isMe && suffixMe ? '$name (나)' : name,
    variant: isMe ? DsChipVariant.me : DsChipVariant.partner,
    dot: true,
    small: small,
  );
}

/// 카드 — 배경 #FFFDF8 · 테두리 1px #F1E4CC · 모서리 24 · 그림자 0 6 18 (8%).
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.radius = AppRadius.card,
    this.shadow = true,
    this.color = AppColors.surface,
    this.onTap,
    this.clip = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool shadow;
  final Color color;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.outlineVariant),
    );
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: onTap == null
            ? body
            : InkWell(
                onTap: onTap,
                highlightColor: AppColors.secondaryPressed,
                child: body,
              ),
      ),
    );
  }
}

enum DsBannerKind { error, warn, ok }

/// 배너 — 화면 안 문맥에 머무는 안내. 모서리 16 · 패딩 12/14 · 13.5px.
class DsBanner extends StatelessWidget {
  const DsBanner({
    super.key,
    required this.message,
    this.kind = DsBannerKind.error,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.centered = false,
  });
  final String message;
  final DsBannerKind kind;

  /// 아이콘 위젯 (기본: 종류별 아이콘).
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (kind) {
      DsBannerKind.error => (
        AppColors.errorContainer,
        AppColors.onErrorContainer,
        AppColors.errorBorder,
      ),
      DsBannerKind.warn => (
        AppColors.warnContainer,
        AppColors.onWarnContainer,
        AppColors.warnBorder,
      ),
      DsBannerKind.ok => (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
        AppColors.successBorder,
      ),
    };
    final leading =
        icon ??
        switch (kind) {
          DsBannerKind.error => const DsErrorIcon(size: 18),
          DsBannerKind.warn => const DsIcon(
            DsIcons.warning,
            size: 18,
            color: AppColors.onWarnContainer,
          ),
          DsBannerKind.ok => const DsIcon(
            DsIcons.checkCircle,
            size: 18,
            color: AppColors.onSuccessContainer,
            stroke: 2.4,
          ),
        };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: centered
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: centered ? 0 : 1),
              child: leading,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: actionLabel == null ? 0 : 6,
                ),
                child: Text(message, style: ds(13.5, color: fg, height: 1.45)),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 6),
              DsButton(
                label: actionLabel!,
                variant: DsButtonVariant.text,
                height: 40,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: fg,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 스켈레톤 #F1E6D2.
class DsSkeleton extends StatelessWidget {
  const DsSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.small,
    this.opacity = 1,
  });
  final double? width;
  final double height;
  final double radius;
  final double opacity;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}

/// 스피너 + “~하고 있어요” 한 줄.
class DsLoadingLine extends StatelessWidget {
  const DsLoadingLine(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const DsSpinner(),
      const SizedBox(width: 8),
      Text(text, style: ds(13, color: AppColors.brown500)),
    ],
  );
}

/// 다이얼로그 상단 48 아이콘 타일 (모서리 16).
class DsIconTile extends StatelessWidget {
  const DsIconTile({
    super.key,
    required this.icon,
    this.background = AppColors.errorContainer,
    this.color = AppColors.errorText,
  });
  final String icon;
  final Color background;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.input),
    ),
    alignment: Alignment.center,
    child: DsIcon(icon, color: color),
  );
}

// ---------------------------------------------------------------------------
// 화면 뼈대
// ---------------------------------------------------------------------------

/// 앱바 — 높이 56 · 패딩 0 12 · 뒤로 아이콘 + 제목 20/700 + 오른쪽 액션.
class DsHeader extends StatelessWidget {
  const DsHeader({
    super.key,
    required this.title,
    this.onBack,
    this.backLabel = '뒤로',
    this.backEnabled = true,
    this.trailing,
    this.hideBack = false,
  });
  final String title;
  final VoidCallback? onBack;
  final String backLabel;
  final bool backEnabled;
  final Widget? trailing;
  final bool hideBack;

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return SizedBox(
      height: AppSpace.appBar,
      child: Padding(
        padding: EdgeInsets.only(left: hideBack ? 24 : 12, right: 12),
        child: Row(
          children: [
            if (!hideBack) ...[
              DsIconButton(
                icon: DsIcons.back,
                onPressed: backEnabled ? back : null,
                semanticLabel: backLabel,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// 크림 바탕 화면 뼈대. 390~430 폭 디자인을 넓은 화면에서는 가운데 480px로 제한합니다.
class DsScreen extends StatelessWidget {
  const DsScreen({
    super.key,
    this.header,
    required this.body,
    this.bottom,
    this.bottomPadding = const EdgeInsets.fromLTRB(24, 12, 24, 28),
    this.resizeToAvoidBottomInset = true,
    this.maxWidth = 480,
    this.canPop = true,
    this.onPopInvoked,
  });

  final Widget? header;
  final Widget body;

  /// 하단 고정 액션 영역(버튼 묶음).
  final Widget? bottom;
  final EdgeInsetsGeometry bottomPadding;
  final bool resizeToAvoidBottomInset;
  final double maxWidth;
  final bool canPop;
  final PopInvokedWithResultCallback<Object?>? onPopInvoked;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        Expanded(child: body),
        if (bottom != null) Padding(padding: bottomPadding, child: bottom),
      ],
    );
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvoked,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: column,
            ),
          ),
        ),
      ),
    );
  }
}

/// 본문 스크롤 영역 — 좌우 24, 위 8, 아래 16.
class DsBody extends StatelessWidget {
  const DsBody({
    super.key,
    required this.children,
    this.gap = 18,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 16),
    this.controller,
    this.physics,
  });
  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: controller,
    physics: physics,
    padding: padding,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    ),
  );
}

/// 세로로 쌓인 액션 버튼 묶음 (gap 10).
class DsActions extends StatelessWidget {
  const DsActions({super.key, required this.children, this.gap = 10});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

/// 빈 화면 / 오류 상태 — 같은 자리에서 교체되어 화면 구조가 흔들리지 않습니다.
class DsStateView extends StatelessWidget {
  const DsStateView({
    super.key,
    required this.art,
    required this.title,
    this.description,
    this.action,
    this.titleSize = 15,
  });
  final Widget art;
  final String title;
  final String? description;
  final Widget? action;
  final double titleSize;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      art,
      const SizedBox(height: 10),
      Text(
        title,
        textAlign: TextAlign.center,
        style: ds(titleSize, weight: titleSize > 16 ? 700 : 600, height: 1.35),
      ),
      if (description != null) ...[
        const SizedBox(height: 8),
        DsHint(description!, textAlign: TextAlign.center),
      ],
      if (action != null) ...[const SizedBox(height: 14), action!],
    ],
  );
}

// ---------------------------------------------------------------------------
// 다이얼로그 · 시트 · 스낵바
// ---------------------------------------------------------------------------

/// 확인 다이얼로그. `onConfirm`을 넘기면 다이얼로그 안에서 실행하고, 실패하면
/// 배너로 알린 뒤 그대로 머물러 다시 시도할 수 있습니다. 성공 시 `true`를 돌려줍니다.
Future<bool> showDsConfirm(
  BuildContext context, {
  Widget? icon,
  required String title,
  Widget? body,
  String? message,
  String? hint,
  String cancelLabel = '취소',
  required String confirmLabel,
  String? confirmLoadingLabel,
  bool danger = false,
  Future<void> Function()? onConfirm,
  String Function(Object error)? errorText,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrim,
    barrierDismissible: onConfirm == null,
    builder: (_) => _DsConfirmDialog(
      icon: icon,
      title: title,
      body: body,
      message: message,
      hint: hint,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      confirmLoadingLabel: confirmLoadingLabel,
      danger: danger,
      onConfirm: onConfirm,
      errorText: errorText,
    ),
  );
  return result ?? false;
}

class _DsConfirmDialog extends StatefulWidget {
  const _DsConfirmDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.message,
    required this.hint,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmLoadingLabel,
    required this.danger,
    required this.onConfirm,
    required this.errorText,
  });
  final Widget? icon;
  final String title;
  final Widget? body;
  final String? message;
  final String? hint;
  final String cancelLabel;
  final String confirmLabel;
  final String? confirmLoadingLabel;
  final bool danger;
  final Future<void> Function()? onConfirm;
  final String Function(Object error)? errorText;

  @override
  State<_DsConfirmDialog> createState() => _DsConfirmDialogState();
}

class _DsConfirmDialogState extends State<_DsConfirmDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    final action = widget.onConfirm;
    if (action == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.errorText?.call(e) ?? '처리하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(height: 14),
              ],
              Text(widget.title, style: ds(21, weight: 700, height: 1.3)),
              if (widget.body != null) ...[
                const SizedBox(height: 14),
                widget.body!,
              ],
              if (widget.message != null) ...[
                const SizedBox(height: 14),
                Text(widget.message!, style: AppText.bodySmall),
              ],
              if (widget.hint != null) ...[
                const SizedBox(height: 14),
                DsHint(widget.hint!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                DsBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DsButton(
                      label: widget.cancelLabel,
                      variant: DsButtonVariant.secondary,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DsButton(
                      label: widget.confirmLabel,
                      loadingLabel: widget.confirmLoadingLabel,
                      variant: widget.danger
                          ? DsButtonVariant.danger
                          : DsButtonVariant.primary,
                      loading: _busy,
                      onPressed: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 단일 버튼 안내 다이얼로그 (예: 상대방이 캘린더를 삭제함).
Future<void> showDsNotice(
  BuildContext context, {
  required String title,
  required String message,
  String? hint,
  required String buttonLabel,
  VoidCallback? onPressed,
}) => showDialog<void>(
  context: context,
  barrierColor: AppColors.scrim,
  barrierDismissible: false,
  builder: (dialogContext) => PopScope(
    canPop: false,
    child: Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.title),
              const SizedBox(height: 14),
              Text(message, style: AppText.bodySmall),
              if (hint != null) ...[const SizedBox(height: 14), DsHint(hint)],
              const SizedBox(height: 14),
              DsButton(
                label: buttonLabel,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onPressed?.call();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// 바텀시트 — 윗모서리 28 + 손잡이 40×4.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: AppColors.surface,
  barrierColor: AppColors.scrim,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 480),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
  ),
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: 16),
        builder(sheetContext),
      ],
    ),
  ),
);

/// 스낵바 — 브라운 배경 + 크림 글자 + 버터 액션, 4초.
void showDsSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
