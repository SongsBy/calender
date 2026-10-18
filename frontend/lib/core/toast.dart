import 'package:flutter/material.dart';

import '../theme.dart';

/// 전역 스낵바 — 브라운 배경 + 크림 글자. 화면 컨텍스트 없이도 띄울 수 있습니다.
class Toast {
  Toast._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(String description) => _show(description);

  static void error(String description) => _show(description, isError: true);

  static void _show(String description, {bool isError = false}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (isError) ...[
                const _ToastErrorIcon(size: 18),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(description)),
            ],
          ),
        ),
      );
  }
}

/// 오류 아이콘 (ds_icons와 동일하지만 import 순환을 피하기 위해 여기서 그립니다).
class _ToastErrorIcon extends StatelessWidget {
  const _ToastErrorIcon({this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.error,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      '!',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * .7,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}
