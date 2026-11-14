import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// Phase 3 screens at the cover-screen and opened-Fold sizes: calendar
// suggestions, the comeback quest, the Health Log, the weekly Delve, the
// reminder in the quest editor and the new Settings cards. The opened-Fold runs also assert that nothing critical
// sits on the crease.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder quiet(String label) => find.byWidgetPredicate(
      (w) => w is QuietButton && w.label == label,
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

MemoryDevice deviceWithCalendar() => MemoryDevice(stepCount: 4630)
  ..events = <CalendarEvent>[
    CalendarEvent(
      id: '41@1',
      title: 'Dentist',
      begin: DateTime(2026, 11, 14, 10, 30),
      end: DateTime(2026, 11, 14, 11, 15),
      calendarId: '1',
    ),
    CalendarEvent(
      id: '42@1',
      title: 'Lunch with Sam',
      begin: DateTime(2026, 11, 14, 12, 30),
      end: DateTime(2026, 11, 14, 13, 30),
      calendarId: '1',
    ),
  ];

Future<TestApp> startConnected(WidgetTester tester) async {
  final app = await TestApp.start(
    tester,
    now: saturday,
    withHistory: true,
    device: deviceWithCalendar(),
  );
  await tester.runAsync(() async {
    await app.game.connectCalendar();
    await app.game.connectSteps();
  });
  await app.settle(tester);
  return app;
}

Future<void> phase3Screens(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await startConnected(tester);
  await shot(tester, '70_board_calendar_$suffix');
  if (open) expectCreaseClear(tester, device);

  // The Health Log.
  await tester.tap(roundButton('Health Log'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Glucose'), '5.8');
  await tester.pumpAndSettle();
  await shot(tester, '71_health_log_$suffix');
  if (open) expectCreaseClear(tester, device);
  await tester.tap(roundButton('Close the Health Log'));
  await tester.pumpAndSettle();

  // Settings: calendar, health, reminders and the Delve day.
  await tester.tap(roundButton('Settings'));
  await tester.pumpAndSettle();
  if (open) {
    await shot(tester, '72_settings_$suffix');
    expectCreaseClear(tester, device);
  } else {
    await reveal(tester, find.text('Calendar'));
    await shot(tester, '72_settings_calendar_$suffix');
    await reveal(tester, find.text('HEALTH LOG FIELDS'));
    await shot(tester, '73_settings_health_$suffix');
  }
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  // The Campfire with last week's Delve waiting, then the Delve itself.
  await tester.runAsync(() => app.game.closeDay(note: ''));
  await app.settle(tester);
  await tester.runAsync(() => app.game.refresh());
  await tester.pumpAndSettle();
  expect(app.game.delve, isNotNull);
  await reveal(tester, find.text('The campfire is lit'));
  await tester.tap(find.text('The campfire is lit'));
  await tester.pumpAndSettle();
  // The review is the last list on screen: the only one on the cover
  // screen, the right-hand pane when the Fold is open.
  await tester.scrollUntilVisible(
    primary('Enter the Delve'),
    180,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
  await shot(tester, '74_campfire_delve_$suffix');
  await tester.tap(primary('Enter the Delve'));
  await tester.pumpAndSettle();
  // Since 0.7 the Delve is a boss fight: the scout's report, the fight,
  // and how it came out.
  await shot(tester, '75_delve_$suffix');
  await tester.tap(primary('Go in'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Defend'));
  await app.settle(tester);
  await shot(tester, '76_delve_fight_$suffix');
  if (open) expectCreaseClear(tester, device);
  for (var turn = 0; turn < 7 && find.text('Defend').evaluate().isNotEmpty;
      turn++) {
    await tester.tap(find.text('Defend'));
    await app.settle(tester);
  }
  await shot(tester, '76_delve_result_$suffix');
  await tester.tap(primary('Back to the fire'));
  await app.settle(tester);
}

/// The comeback quest on the board after days away, then the quest editor
/// with its completion types and the reminder set.
Future<void> comebackAndReminder(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await TestApp.start(
    tester,
    now: saturday,
    withHistory: true,
    device: MemoryDevice(),
  );
  app.now = DateTime(2026, 11, 18, 8, 5);
  await tester.runAsync(() => app.game.refresh());
  await tester.pumpAndSettle();
  expect(find.text('Return to the Vale'), findsOneWidget);
  await shot(tester, '77_board_comeback_$suffix');
  if (open) expectCreaseClear(tester, device);

  await tester.tap(open ? find.text('Quest') : primary('Quest'));
  await tester.pumpAndSettle();
  expect(find.text('New quest'), findsOneWidget);
  await tester.enterText(find.byType(TextField).first, 'Water the plants');
  await tester.tap(find.widgetWithText(ChoicePill, 'Care'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(quiet('More options'));
  await tester.pumpAndSettle();
  await tester.tap(quiet('More options'));
  await tester.pumpAndSettle();
  final evening = find.widgetWithText(ChoicePill, '18:00');
  await tester.ensureVisible(evening);
  await tester.pumpAndSettle();
  await tester.tap(evening);
  await app.settle(tester);
  await shot(tester, '78_editor_reminder_$suffix');
  if (open) expectCreaseClear(tester, device);
}

void main() {
  setUpAll(loadAppFonts);
  // Screenshots show the paintings.
  setUpAll(() => TestApp.largeArt = true);

  screenTest('Phase 3 on the cover screen', (tester) async {
    await phase3Screens(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('Phase 3 on the opened Fold', (tester) async {
    await phase3Screens(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('Coming back, on the cover screen', (tester) async {
    await comebackAndReminder(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('Coming back, on the opened Fold', (tester) async {
    await comebackAndReminder(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('A calendar event that repeats a quest on the board',
      (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final device = MemoryDevice()
      ..events = <CalendarEvent>[
        CalendarEvent(
          id: '51@1',
          title: 'Mounjaro',
          begin: DateTime(2026, 11, 14, 9),
          end: DateTime(2026, 11, 14, 9, 30),
          calendarId: '1',
        ),
        CalendarEvent(
          id: '52@1',
          title: 'Covid and Flu Shots',
          begin: DateTime(2026, 11, 14, 14),
          end: DateTime(2026, 11, 14, 14, 30),
          calendarId: '1',
        ),
      ];
    final app = await TestApp.start(
      tester,
      now: saturday,
      withHistory: true,
      device: device,
    );
    await tester.runAsync(() => app.game.connectCalendar());
    await app.settle(tester);
    await reveal(tester, find.text('Covid and Flu Shots'));
    await shot(tester, '79_board_calendar_match_cover');
  });
}
