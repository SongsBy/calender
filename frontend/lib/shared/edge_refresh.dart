import 'package:flutter/material.dart';

import 'ds.dart';

/// 위에서 당겨 갱신 + 아래에서 당겨 갱신. 두 방향이 같은 갱신 동작을 공유합니다.
/// 당기는 동안에는 “놓으면 일정을 다시 불러와요” 안내가, 갱신 중에는 크림 원 안의
/// 스피너(갱신 인디케이터)가 보입니다.
class EdgeRefresh extends StatefulWidget {
  const EdgeRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.pullUpHint = '놓으면 일정을 다시 불러와요',
    this.pullUpArming = '위로 당겨 새로고침',
  });
  final Widget child;
  final Future<void> Function() onRefresh;
  final String pullUpHint;
  final String pullUpArming;
  @override
  State<EdgeRefresh> createState() => _EdgeRefreshState();
}

class _EdgeRefreshState extends State<EdgeRefresh> {
  double pull = 0;
  Future<void>? pending;
  Future<void> refresh() => pending ??= run();
  Future<void> run() async {
    setState(() {});
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          pending = null;
          pull = 0;
        });
      }
    }
  }

  bool notify(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || pending != null) {
      return false;
    }
    if (n is ScrollStartNotification) pull = 0;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll > 0) {
      setState(() => pull += n.overscroll);
    }
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        (n.scrollDelta ?? 0) < 0) {
      if (pull != 0) setState(() => pull = 0);
    }
    if (n is ScrollEndNotification) {
      final armed = pull >= 72;
      setState(() => pull = 0);
      if (armed) refresh();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    // 스크롤 영역이 좁은 내용에 맞춰 줄어들지 않도록 항상 가득 채웁니다.
    fit: StackFit.expand,
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: notify,
        child: RefreshIndicator(
          onRefresh: refresh,
          color: AppColors.brown900,
          backgroundColor: AppColors.surface,
          child: widget.child,
        ),
      ),
      if (pull > 0 || pending != null)
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: pending != null
                  ? const DsRefreshBubble()
                  : Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const DsIcon(
                            DsIcons.arrowUp,
                            size: 16,
                            color: AppColors.brown500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pull >= 72
                                ? widget.pullUpHint
                                : widget.pullUpArming,
                            style: ds(13, color: AppColors.brown500),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
    ],
  );
}

/// 갱신 인디케이터 — 40px 크림 원 + 스피너 · 그림자 0 4 14 (18%).
class DsRefreshBubble extends StatelessWidget {
  const DsRefreshBubble({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: AppColors.floatShadow,
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: const DsSpinner(),
  );
}
