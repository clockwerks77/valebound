import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import 'harness.dart';

/// A scripted walk through First Dawn (Amendment v0.4 §3), used by the flow
/// tests and by the screenshots: two domains, a goal and a habit for each,
/// the rhythm, the quiz, the calendar with its mapping pass, and the first
/// week. [at] is called on every screen with a name for it.
class FirstDawnRun {
  FirstDawnRun(this.tester, this.app, {this.at});

  final WidgetTester tester;
  final TestApp app;
  final Future<void> Function(String name)? at;

  static Finder primary(String label) => find.byWidgetPredicate(
        (w) => w is PrimaryButton && w.label == label,
      );

  static Finder quiet(String label) => find.byWidgetPredicate(
        (w) => w is QuietButton && w.label == label,
      );

  static Finder field(String id) => find.byKey(ValueKey<String>('field-$id'));

  /// A calendar with two recurring events in the coming weeks and one
  /// one-off, for the mapping pass.
  static MemoryDevice device() {
    CalendarEvent event(String title, int day, int hour, String id) {
      final begin = DateTime(2026, 11, day, hour);
      return CalendarEvent(
        id: '$id@${begin.millisecondsSinceEpoch}',
        title: title,
        begin: begin,
        end: begin.add(const Duration(hours: 1)),
        calendarId: '1',
      );
    }

    return MemoryDevice()
      ..events = <CalendarEvent>[
        event('Painting night', 17, 19, '5'),
        event('Painting night', 24, 19, '5'),
        event('Gym', 16, 7, '6'),
        event('Gym', 18, 7, '6'),
        event('Gym', 20, 7, '6'),
        event('Dentist', 19, 10, '7'),
      ];
  }

  Future<void> mark(String name) async => at?.call(name);

  Future<void> tap(String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target.first);
    await tester.tap(target.first);
    await app.settle(tester);
  }

  Future<void> next([String label = 'Next']) async {
    await tester.tap(primary(label));
    await app.settle(tester);
  }

  Future<void> type(String id, String text) async {
    await tester.enterText(field(id), text);
    await tester.pumpAndSettle();
  }

  /// Chapters 1 to 3: two domains, their goals, a habit for each.
  Future<void> storyGoalsHabits() async {
    expect(find.text('FIRST DAWN · CHAPTER 1 OF 7'), findsOneWidget);
    await tap('Body & Health');
    await tap('Making & Craft');
    await mark('c1_story_domains');
    await next();
    await type('why.0', 'Stairs without thinking about them');
    await mark('c1_story_why');
    await next();
    await type('why.1', 'A painted army on the table');
    await next();
    expect(find.text('Here’s what I heard'), findsOneWidget);
    await mark('c1_story_mirror');
    await next('That’s right');

    expect(find.text('FIRST DAWN · CHAPTER 2 OF 7'), findsOneWidget);
    await tap('Feel stronger');
    await mark('c2_goals_goal');
    await next();
    await tap('This season');
    await mark('c2_goals_horizon');
    await next();
    await type('check.0', 'I take the stairs');
    await mark('c2_goals_check');
    await next();
    await type('goal.1', 'Finish my army');
    await next();
    await next();
    await next();
    await mark('c2_goals_mirror');
    await next('That’s right');

    expect(find.text('FIRST DAWN · CHAPTER 3 OF 7'), findsOneWidget);
    await tap('Walk for 20 minutes');
    await mark('c3_habit_what');
    await next();
    await tap('At lunch');
    await mark('c3_habit_anchor');
    await next();
    await mark('c3_habit_often');
    await next();
    expect(find.text('Size it'), findsOneWidget);
    await mark('c3_habit_size');
    await next();
    await mark('c3_habit_track');
    await next();
    await mark('c3_habit_dread');
    await next();
    // The second goal's habit: weekly, on Saturday.
    await tap('Paint for 30 minutes');
    await next();
    await tap('After dinner');
    await next();
    await tap('Once a week');
    await tap('Sat');
    await next();
    await next();
    await next();
    await next();
    await mark('c3_habit_mirror');
    await next('That’s right');
  }

  /// Chapters 4 and 5: the rhythm, the quiz, the class, the companion.
  Future<void> rhythmAndClass({required String become}) async {
    expect(find.text('FIRST DAWN · CHAPTER 4 OF 7'), findsOneWidget);
    await tap('6 to 8');
    await mark('c4_rhythm_wake');
    await next();
    await tap('10 to midnight');
    await next();
    await tap('Weekdays');
    await next();
    await tap('Morning');
    await next();
    await tap('Sun');
    await mark('c4_rhythm_rest');
    await next();
    await tap('Steady, most days');
    await mark('c4_rhythm_burst');
    await next();
    await mark('c4_rhythm_mirror');
    await next('That’s right');

    expect(find.text('FIRST DAWN · CHAPTER 5 OF 7'), findsOneWidget);
    for (var q = 0; q < quiz.length; q++) {
      await tap(quiz[q].answers[quizOrder(q).first]);
      if (q == 0) await mark('c5_class_quiz');
      await next();
    }
    expect(find.text('Your class'), findsOneWidget);
    await mark('c5_class_recommended');
    await next(become);
    await tap('Yes');
    await mark('c5_class_companion');
    await next();
    await mark('c5_class_mirror');
    await next('That’s right');
  }

  /// Chapter 6 with the calendar connected and its recurring events mapped.
  Future<void> calendar() async {
    expect(find.text('FIRST DAWN · CHAPTER 6 OF 7'), findsOneWidget);
    await mark('c6_calendar_promise');
    await next('Connect the calendar');
    expect(find.text('Which calendars count?'), findsOneWidget);
    await mark('c6_calendar_which');
    await next();
    expect(find.text('Your recurring events'), findsOneWidget);
    await app.settle(tester);
    // The painting night is the painting habit: one quest, not two.
    await tap('This is my habit');
    await mark('c6_calendar_series');
    await next('Confirm all');
    await mark('c6_calendar_mirror');
    await next('That’s right');
  }

  /// Chapter 7: the week, the calibration, the camp, and out to the board.
  Future<void> firstWeek() async {
    expect(find.text('FIRST DAWN · CHAPTER 7 OF 7'), findsOneWidget);
    expect(find.text('Your first week'), findsOneWidget);
    await mark('c7_week_review');
    await next();
    await tap('About right');
    await mark('c7_week_calibrate');
    await next();
    expect(find.text('The first camp'), findsOneWidget);
    await mark('c7_week_camp');
    await next('Begin');
  }
}
