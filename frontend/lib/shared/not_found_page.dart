import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'ds.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => DsScreen(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: DsStateView(
          art: const DsSmile(color: AppColors.butterContainer, flat: true),
          title: '찾을 수 없는 페이지예요',
          titleSize: 20,
          description: '주소가 바뀌었거나 삭제된 화면이에요. 캘린더 목록으로 돌아가 볼까요?',
          action: DsButton(
            label: '캘린더 목록으로',
            onPressed: () => context.go(Routes.home),
          ),
        ),
      ),
    ),
  );
}
