import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/events/calendar_page.dart';
import 'package:frontend/features/events/solo_invite_card.dart';
import 'package:frontend/features/home/home_gate.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/calendars_provider.dart';
import 'package:frontend/providers/events_provider.dart';

import 'calendars_test.dart' show FakeCalendars;
import 'events_test.dart' show FakeEvents;

Future<void> pumpGate(WidgetTester tester, FakeCalendars service) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const UserPublic(id: 'me')),
        calendarsServiceProvider.overrideWithValue(service),
        calendarDetailProvider.overrideWith(
          (ref, id) async => service.calendars.firstWhere((c) => c.id == id),
        ),
        eventsServiceProvider.overrideWithValue(FakeEvents()),
      ],
      child: const MaterialApp(home: HomeGate()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first login creates a calendar and shows it with invite card', (
    tester,
  ) async {
    final service = FakeCalendars();
    await pumpGate(tester, service);
    expect(service.calendars, hasLength(1));
    expect(service.calendars.single.name, HomeGate.defaultCalendarName);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.byType(SoloInviteCard), findsOneWidget);
    expect(find.text('아직 혼자예요'), findsOneWidget);
    expect(service.issued, 0);
    await tester.tap(find.text('초대코드 만들기'));
    await tester.pumpAndSettle();
    expect(service.issued, 1);
    expect(find.text('ABCD'), findsOneWidget);
    expect(find.text('코드 복사'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected calendar is preferred and hides the invite card', (
    tester,
  ) async {
    final service = FakeCalendars();
    await service.create('혼자 쓰는 달력');
    final solo = service.calendars.single;
    await service.acceptInvitation('code');
    service.calendars = [solo, ...service.calendars];
    await pumpGate(tester, service);
    expect(find.text('함께 쓰는 일정'), findsOneWidget);
    expect(find.byType(SoloInviteCard), findsNothing);
    expect(find.bySemanticsLabel('계정 메뉴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
