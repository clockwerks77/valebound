import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// Phase 3 screens at the cover-screen and opened-Fold sizes: calendar
// suggestions, the comeback quest, the Health Log, the weekly Delve and the
// new Settings cards. The opened-Fold runs also assert that nothing critical
// sits on the crease.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
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
  await shot(tester, '75_delve_$suffix');
  if (open) expectCreaseClear(tester, device);
  await tester.ensureVisible(primary('Enter the Delve'));
  await tester.pumpAndSettle();
  await tester.tap(primary('Enter the Delve'));
  await app.settle(tester);
  await shot(tester, '76_delve_result_$suffix');
  if (open) expectCreaseClear(tester, device);
}

void main() {
  setUpAll(loadAppFonts);

  screenTest('Phase 3 on the cover screen', (tester) async {
    await phase3Screens(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('Phase 3 on the opened Fold', (tester) async {
    await phase3Screens(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('The comeback quest', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(tester, now: saturday, withHistory: true);
    app.now = DateTime(2026, 11, 18, 8, 5);
    await tester.runAsync(() => app.game.refresh());
    await tester.pumpAndSettle();
    expect(find.text('Return to the Vale'), findsOneWidget);
    await shot(tester, '77_board_comeback_cover');
  });
}
