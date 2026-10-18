import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/edge_refresh.dart';

Widget _page(Future<void> Function() onRefresh, Widget child) => MaterialApp(
  home: Scaffold(
    body: EdgeRefresh(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: child,
      ),
    ),
  ),
);

void main() {
  for (final up in [true, false]) {
    testWidgets(
      'pull ${up ? "up at bottom" : "down at top"} refreshes once and shows progress',
      (tester) async {
        var calls = 0;
        final done = Completer<void>();
        await tester.pumpWidget(
          _page(() {
            calls++;
            return done.future;
          }, const SizedBox(height: 1200, child: Text('일정'))),
        );
        if (up) {
          final scroll = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
        }
        await tester.drag(
          find.byType(SingleChildScrollView),
          Offset(0, up ? -250 : 300),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 1);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        await tester.drag(
          find.byType(SingleChildScrollView),
          Offset(0, up ? -250 : 300),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(calls, 1);
        done.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  }
  testWidgets(
    'short content still supports pull up; ordinary scroll does not refresh',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _page(() async {
          calls++;
        }, const Text('빈 일정')),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
