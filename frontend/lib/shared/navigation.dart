import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

/// GoRouter가 있으면 URL 경로로, 없으면(위젯 테스트 등) 일반 Navigator로 화면을 띄웁니다.
Future<T?> pushScreen<T extends Object?>(
  BuildContext context,
  String location,
  Widget Function() builder, {
  Object? extra,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<T>(location, extra: extra);
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute<T>(builder: (_) => builder()));
}

/// 캘린더 목록(홈)으로 이동. GoRouter가 없으면 한 단계 뒤로.
void goHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go(Routes.home);
  } else {
    Navigator.of(context).maybePop();
  }
}

/// 뒤로 가기 — 스택이 비어 있으면 홈으로.
void goBackOrHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.home);
    }
  } else {
    Navigator.of(context).maybePop();
  }
}
