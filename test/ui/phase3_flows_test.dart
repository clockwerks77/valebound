import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// Phase 3 on screen: calendar suggestions, the comeback quest, the Health
// Log, steps, the weekly Delve and the reminder.

/// 2026-11-14 is a Saturday.
final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder completeButton(String questName) => find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete $questName',
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder quiet(String label) => find.byWidgetPredicate(
      (w) => w is QuietButton && w.label == label,
    );

List<CalendarEvent> twoEvents() => <CalendarEvent>[
      CalendarEvent(
        id: '41@1',
        title: 'Dentist',
        begin: DateTime(2026, 11, 14, 10, 30),
        end: DateTime(2026, 11, 14, 11, 15),
        calendarId: '1',
      ),
      CalendarEvent(
        id: '42@1',
        title: 'Team lunch',
        begin: DateTime(2026, 11, 14, 12),
        end: DateTime(2026, 11, 14, 13),
        calendarId: '2',
      ),
    ];

/// Taps a quest's completion ring and lets its fill animation finish.
Future<void> tapComplete(WidgetTester tester, String questName) async {
  await reveal(tester, completeButton(questName));
  await tester.tap(completeButton(questName));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadAppFonts);

  group('Calendar suggestions (DESIGN §9.3)', () {
    testWidgets('asked for on the board, then offered as Accept or Dismiss',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice()..events = twoEvents();
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(device.calendarPermission, isFalse, reason: 'not asked at launch');
      expect(app.game.suggestions, isEmpty);

      await reveal(tester, primary('Connect calendar'));
      expect(find.text('Today’s calendar, as quests?'), findsOneWidget);
      await tester.tap(primary('Connect calendar'));
      await app.settle(tester);
      expect(device.calendarPermission, isTrue);
      expect(app.game.suggestions.map((e) => e.title), <String>[
        'Dentist',
        'Team lunch',
      ]);
      // Offered, never accepted for you.
      expect(app.game.board.any((b) => b.quest.name == 'Dentist'), isFalse);

      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await reveal(tester, primary('Accept'));
      expect(find.text('10:30 – 11:15 · suggested'), findsOneWidget);
      await tester.tap(primary('Accept').first);
      await app.settle(tester);
      final accepted =
          app.game.board.firstWhere((b) => b.quest.name == 'Dentist');
      expect(accepted.quest.completionType, CompletionType.confirm);
      expect(accepted.quest.source, QuestSource.calendar);
      // Accepted, never completed for you.
      expect(accepted.isDone, isFalse);
      expect(app.game.suggestions.single.title, 'Team lunch');

      await reveal(tester, quiet('Dismiss'));
      await tester.tap(quiet('Dismiss'));
      await app.settle(tester);
      expect(app.game.suggestions, isEmpty);
      expect(app.game.board.any((b) => b.quest.name == 'Team lunch'), isFalse);

      // "I did this" completes it like any quest.
      await tapComplete(tester, 'Dentist');
      await app.settle(tester);
      expect(
        app.game.doneQuests.map((b) => b.quest.name),
        contains('Dentist'),
      );
    });

    testWidgets('Not now leaves the board alone and is not asked again',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice()..events = twoEvents();
      final app = await TestApp.start(tester, now: saturday, device: device);
      await reveal(tester, quiet('Not now'));
      await tester.tap(quiet('Not now'));
      await app.settle(tester);
      expect(find.text('Today’s calendar, as quests?'), findsNothing);
      expect(device.calendarPermission, isFalse);
      expect(app.game.settings.calendarAsked, isTrue);
      expect(app.game.suggestions, isEmpty);
    });

    testWidgets('a refused calendar changes nothing', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(grantCalendar: false)..events = twoEvents();
      final app = await TestApp.start(tester, now: saturday, device: device);
      final before = app.game.board.length;
      await reveal(tester, primary('Connect calendar'));
      await tester.tap(primary('Connect calendar'));
      await app.settle(tester);
      expect(app.game.suggestions, isEmpty);
      expect(app.game.board.length, before);
      expect(find.text('Today’s calendar, as quests?'), findsNothing);
    });

    testWidgets('one event in two calendars is offered once', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice()
        ..events = <CalendarEvent>[
          ...twoEvents(),
          // The dentist again, as it shows in a second calendar.
          CalendarEvent(
            id: '77@1',
            title: 'dentist ',
            begin: DateTime(2026, 11, 14, 10, 30),
            end: DateTime(2026, 11, 14, 11, 15),
            calendarId: '2',
          ),
        ];
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectCalendar());
      await app.settle(tester);
      expect(app.game.suggestions.map((e) => e.title), <String>[
        'Dentist',
        'Team lunch',
      ]);

      // A choice about one copy counts for the other.
      await tester.runAsync(
        () => app.game.dismissSuggestion(app.game.suggestions.first),
      );
      await app.settle(tester);
      expect(app.game.suggestions.single.title, 'Team lunch');
    });

    testWidgets('leaving out one calendar still offers the copy in the other',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice()
        ..events = <CalendarEvent>[
          CalendarEvent(
            id: '41@1',
            title: 'Dentist',
            begin: DateTime(2026, 11, 14, 10, 30),
            end: DateTime(2026, 11, 14, 11, 15),
            calendarId: '1',
          ),
          CalendarEvent(
            id: '77@1',
            title: 'Dentist',
            begin: DateTime(2026, 11, 14, 10, 30),
            end: DateTime(2026, 11, 14, 11, 15),
            calendarId: '2',
          ),
        ];
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() async {
        await app.game.connectCalendar();
        await app.game.setCalendarExcluded('1', excluded: true);
      });
      await tester.pumpAndSettle();
      expect(app.game.suggestions.single.id, '77@1');
    });

    testWidgets('an event that repeats a quest on the board says so',
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
        ];
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectCalendar());
      await app.settle(tester);

      // Still offered: nothing is decided for you.
      final event = app.game.suggestions.single;
      expect(event.title, 'Mounjaro');
      expect(app.game.boardQuestMatching(event), 'Weekly Injection (Mounjaro)');
      final hint = find.text(
        'Looks like “Weekly Injection (Mounjaro)”, which is already on '
        'today’s board.',
      );
      await reveal(tester, hint);
      expect(hint, findsOneWidget);

      // Dismiss is the main button here, and Accept is still there.
      expect(quiet('Accept'), findsOneWidget);
      await reveal(tester, primary('Dismiss'));
      await tester.tap(primary('Dismiss'));
      await app.settle(tester);
      expect(app.game.suggestions, isEmpty);
      expect(app.game.board.any((b) => b.quest.name == 'Mounjaro'), isFalse);
      expect(
        app.game.board.any((b) => b.quest.name == 'Weekly Injection (Mounjaro)'),
        isTrue,
      );
    });

    testWidgets('an excluded calendar is left out', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice()..events = twoEvents();
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() async {
        await app.game.connectCalendar();
        await app.game.setCalendarExcluded('2', excluded: true);
      });
      await tester.pumpAndSettle();
      expect(app.game.suggestions.single.title, 'Dentist');
    });
  });

  group('The comeback quest (DESIGN §4.3)', () {
    testWidgets('after days away the board offers one welcome', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      expect(find.text('Return to the Vale'), findsNothing);

      // Away on Sunday, Monday and Tuesday.
      app.now = DateTime(2026, 11, 18, 8);
      await tester.runAsync(() => app.game.refresh());
      await tester.pumpAndSettle();
      expect(find.text('Return to the Vale'), findsOneWidget);
      expect(
        find.text('Welcome back. The Vale waited, just as you left it.'),
        findsOneWidget,
      );
      expect(find.text('+25 XP'), findsWidgets);

      await tapComplete(tester, 'Return to the Vale');
      await app.settle(tester);
      expect(app.game.comebackQuest, isNull);
      expect(app.game.hero!.totalXp, 25);
    });
  });

  group('Health Log (DESIGN §8.7, §9.3)', () {
    testWidgets('stores what is typed, as typed', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(roundButton('Health Log'));
      await tester.pumpAndSettle();
      expect(find.text('Health Log'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Glucose'), '5.8');
      await reveal(tester, primary('Save'));
      await tester.tap(primary('Save'));
      await app.settle(tester);
      expect(find.text('Health Log'), findsNothing);
      expect(app.game.healthToday['glucose']!.value, '5.8');
      expect(app.game.healthToday['glucose']!.unit, 'mmol/L');
      expect(app.game.healthToday.containsKey('weight'), isFalse);
    });

    testWidgets('Morning Health Check opens it and completes when saved',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tapComplete(tester, 'Morning Health Check');
      await tester.pumpAndSettle();
      expect(find.text('Health Log'), findsOneWidget);
      expect(app.game.doneQuests, isEmpty);

      await reveal(tester, primary('Save'));
      await tester.tap(primary('Save'));
      await app.settle(tester);
      expect(app.game.doneQuests.single.quest.name, 'Morning Health Check');
    });

    testWidgets('backing out of it completes nothing', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tapComplete(tester, 'Morning Health Check');
      await tester.pumpAndSettle();
      await tester.tap(roundButton('Close the Health Log'));
      await app.settle(tester);
      expect(app.game.doneQuests, isEmpty);
    });

    testWidgets('the weekly injection takes an optional dose note',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tapComplete(tester, 'Weekly Injection (Mounjaro)');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Dose note (optional)'),
        '5 mg',
      );
      await tester.tap(primary('Mark done'));
      await app.settle(tester);
      expect(app.game.healthToday['injection']!.value, 'Done (5 mg)');
      final done = app.game.doneQuests.single;
      expect(done.quest.name, 'Weekly Injection (Mounjaro)');
      expect(done.completion!.note, '5 mg');
    });
  });

  group('Steps (DESIGN §6.2, §9.3)', () {
    testWidgets('connected, the day’s steps complete the quest by themselves',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(stepCount: 7420);
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(app.game.stepsConnected, isFalse, reason: 'not asked at launch');
      expect(device.stepReads, 0);

      await tester.runAsync(() => app.game.connectSteps());
      await app.settle(tester);
      expect(app.game.stepsConnected, isTrue);
      expect(app.game.stepsToday, 7420);
      expect(app.game.doneQuests.single.quest.name, '7,000 Steps');
      expect(app.game.takeAutoCompletions(), isEmpty, reason: 'marked on screen');
    });

    testWidgets('below the target they show as progress', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(stepCount: 3200);
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectSteps());
      await app.settle(tester);
      expect(app.game.doneQuests, isEmpty);
      await reveal(tester, find.text('3,200 of 7,000 steps so far'));
      expect(find.text('3,200 of 7,000 steps so far'), findsOneWidget);
    });

    testWidgets('refused, the quest still completes with a tap',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(grantSteps: false, stepCount: 9000);
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectSteps());
      await app.settle(tester);
      expect(app.game.stepsConnected, isFalse);
      expect(app.game.stepsToday, isNull);

      await tapComplete(tester, '7,000 Steps');
      await app.settle(tester);
      expect(app.game.doneQuests.single.quest.name, '7,000 Steps');
    });
  });

  group('The weekly Delve (DESIGN §4.2)', () {
    testWidgets('opens at the Campfire once the day is closed',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      // Sunday evening, the default Delve day.
      final app =
          await TestApp.start(tester, now: DateTime(2026, 11, 15, 20, 30));
      final walk = app.game.quests.firstWhere((q) => q.name == 'Walk Babs');
      await tester.runAsync(() async {
        await app.repo.completeQuest(walk.id);
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      expect(app.game.delve, isNotNull);

      await reveal(tester, roundButton('Open the Campfire'));
      await tester.tap(roundButton('Open the Campfire'));
      await tester.pumpAndSettle();
      await reveal(tester, primary('Close the day'));
      expect(primary('Enter the Delve'), findsNothing);
      await tester.tap(primary('Close the day'));
      await app.settle(tester);

      await reveal(tester, primary('Enter the Delve'));
      await tester.tap(primary('Enter the Delve'));
      await tester.pumpAndSettle();
      expect(find.text('WHAT THE WEEK GATHERED'), findsOneWidget);
      await reveal(tester, primary('Enter the Delve'));
      await tester.tap(primary('Enter the Delve'));
      await app.settle(tester);

      expect(find.text('RESTED'), findsOneWidget);
      expect(app.game.delve, isNull);
      // Walk 5 gold, Campfire Review 2, and the Delve's 8.
      expect(app.game.hero!.gold, 15);
      expect((await tester.runAsync(() => app.repo.delves()))!.length, 1);
    });
  });

  group('Settings and the reminder', () {
    testWidgets('the Delve day can be chosen', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      final wednesday = find.widgetWithText(ChoicePill, 'Wed');
      await reveal(tester, wednesday);
      await tester.tap(wednesday);
      await app.settle(tester);
      expect(app.game.settings.delveWeekday, DateTime.wednesday);
      expect(find.text('Opens on Wednesday'), findsOneWidget);
    });

    testWidgets('a Health Log field can be switched off', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      final weight = find.widgetWithText(ToggleRow, 'Weight');
      await reveal(tester, weight);
      await tester.tap(weight);
      await app.settle(tester);
      expect(
        app.game.settings.healthFields.map((f) => f.key),
        isNot(contains('weight')),
      );
      expect(app.game.settings.healthFields.length, 4);
    });

    testWidgets('a reminder is planned for its quest and stops once done',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice();
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(device.reminders, isEmpty, reason: 'off by default');
      expect(app.game.hasReminders, isFalse);

      final walk = app.game.quests.firstWhere((q) => q.name == 'Walk Babs');
      await tester.runAsync(
        () => app.game.saveQuest(QuestDraft.fromRow(walk)..reminderTime = '18:00'),
      );
      await tester.pumpAndSettle();
      expect(device.reminders.length, 7);
      expect(device.reminders.first.title, 'Walk Babs');
      expect(device.reminders.first.body, 'Whenever you are ready.');
      expect(device.reminders.first.at, DateTime(2026, 11, 14, 18));

      await tester.runAsync(() => app.game.complete(walk.id));
      await app.settle(tester);
      expect(device.reminders.first.at, DateTime(2026, 11, 15, 18));
    });

    testWidgets('setting one in the quest editor asks for notifications then',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice();
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(device.notifications, isFalse, reason: 'not asked at launch');

      await tester.tap(primary('Quest'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Water the plants');
      await tester.tap(find.widgetWithText(ChoicePill, 'Care'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(quiet('More options'));
      await tester.pumpAndSettle();
      await tester.tap(quiet('More options'));
      await tester.pumpAndSettle();
      // All five completion types can be chosen.
      for (final label in <String>[
        'Tap',
        'Count',
        'Timer',
        'Auto (steps)',
        'Confirm',
      ]) {
        expect(find.widgetWithText(ChoicePill, label), findsOneWidget);
      }
      final evening = find.widgetWithText(ChoicePill, '18:00');
      await tester.ensureVisible(evening);
      await tester.pumpAndSettle();
      await tester.tap(evening);
      await app.settle(tester);
      expect(device.notifications, isTrue);

      await tester.tap(primary('Add quest'));
      await app.settle(tester);
      expect(
        device.reminders.map((r) => r.title).toSet(),
        <String>{'Water the plants'},
      );
    });
  });
}
