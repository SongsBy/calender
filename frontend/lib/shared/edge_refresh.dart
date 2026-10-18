import 'package:flutter/material.dart';

/// Top pull-down and bottom pull-up share the same refresh operation.
class EdgeRefresh extends StatefulWidget {
  const EdgeRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;
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
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: notify,
        child: RefreshIndicator(onRefresh: refresh, child: widget.child),
      ),
      if (pull > 0 || pending != null)
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: pending != null
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(pull >= 72 ? '놓으면 새로고침' : '위로 당겨 새로고침'),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
