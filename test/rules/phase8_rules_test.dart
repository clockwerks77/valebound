import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/checkin.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/combat.dart' show EnemyType;
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/rules/generation.dart';
import 'package:habit_adventure/rules/goals.dart';

// Amendment v0.4: goals, habit plans, sizes, the board Dawn composes, the
// calendar mapping and the Sunday Check-In, as pure rules.

const Goal stronger = Goal(
  id: 'g1',
  domain: LifeDomain.body,
  text: 'Feel stronger',
  why: 'Stairs without thinking about them',
);
const Goal army = Goal(id: 'g2', domain: LifeDomain.making, text: 'Finish my army');

HabitPlan plan(
  String id,
  String target, {
  Goal goal = stronger,
  Dread dread = Dread.fine,
  PlanFrequency frequency = PlanFrequency.daily,
  Set<int> weekdays = const <int>{},
  String anchor = '',
  String? tinyUntil,
}) {
  final sizes = proposeSizes(target);
  return HabitPlan(
    id: id,
    goalId: goal.id,
    target: target,
    tiny: sizes.tiny,
    stretch: sizes.stretch,
    attribute: goal.domain.attribute,
    dread: dread,
    frequency: frequency,
    weekdays: weekdays,
    anchor: anchor,
    window: windowOfAnchor(anchor),
    minutes: sizes.minutes,
    tinyUntil: tinyUntil,
    questId: 'q-$id',
  );
}

QuestFact questOf(HabitPlan p, {bool done = false}) => QuestFact(
      id: p.questId!,
      name: p.target,
      source: QuestSource.habit,
      attribute: p.attribute,
      track: p.track,
      difficulty: Difficulty.standard,
      goalId: p.goalId,
      planId: p.id,
      done: done,
    );

const QuestFact campfire = QuestFact(
  id: 'q-campfire',
  name: 'Campfire Review',
  source: QuestSource.system,
  attribute: Attribute.mind,
  track: Track.hero,
  difficulty: Difficulty.minor,
  systemKey: 'campfire',
);

EventFact event(
  String title, {
  String calendar = 'cal1',
  int day = 16,
  int hour = 14,
}) {
  final begin = DateTime(2026, 11, day, hour);
  return EventFact(
    key: '$title|$day|$hour',
    calendarId: calendar,
    title: title,
    begin: begin,
    end: begin.add(const Duration(hours: 1)),
    timeLabel: '$hour:00',
  );
}

void main() {
  group('sizes (Amendment v0.4 §4)', () {
    test('a timed habit is proposed in three lengths', () {
      final s = proposeSizes('Paint for 30 minutes');
      expect(s.minutes, 30);
      expect(s.tiny, 'Paint for 5 minutes');
      expect(s.target, 'Paint for 30 minutes');
      expect(s.stretch, 'Paint for 45 minutes');
      expect(proposeSizes('Stretch for 10 min').tiny, 'Stretch for 2 min');
    });

    test('a habit with no minutes is proposed in words', () {
      final s = proposeSizes('Walk the dog');
      expect(s.minutes, isNull);
      expect(s.tiny, contains('walk the dog'));
      expect(s.target, 'Walk the dog');
      expect(s.stretch, startsWith('Walk the dog'));
    });

    test('Tiny is Minor, Target is Standard, Stretch is Heroic; a heavy '
        'habit carries Heroic weight at its Target', () {
      final fine = plan('a', 'Read for 20 minutes');
      expect(fine.difficultyFor(QuestSize.tiny), Difficulty.minor);
      expect(fine.difficultyFor(QuestSize.target), Difficulty.standard);
      expect(fine.difficultyFor(QuestSize.stretch), Difficulty.heroic);
      final heavy = plan('b', 'Strength work for 20 minutes', dread: Dread.heavy);
      expect(heavy.difficultyFor(QuestSize.tiny), Difficulty.minor);
      expect(heavy.difficultyFor(QuestSize.target), Difficulty.heroic);
    });

    test('the default size is Target, and Tiny through a Tiny-only week', () {
      final p = plan('a', 'Read for 20 minutes', tinyUntil: '2026-11-20');
      expect(p.defaultSize('2026-11-14'), QuestSize.tiny);
      expect(p.defaultSize('2026-11-20'), QuestSize.tiny);
      expect(p.defaultSize('2026-11-21'), QuestSize.target);
      expect(plan('b', 'Read').defaultSize('2026-11-14'), QuestSize.target);
    });

    test('week one runs timed Targets at its calibration', () {
      final p = plan('a', 'Paint for 30 minutes');
      expect(targetTextOn(p, 100), 'Paint for 30 minutes');
      expect(targetTextOn(p, 75), 'Paint for 25 minutes');
      expect(targetTextOn(p, 125), 'Paint for 40 minutes');
      expect(targetTextOn(plan('b', 'Walk the dog'), 75), 'Walk the dog');
    });
  });

  group('tracks and anchors (Chapter 3)', () {
    test('care for the companion is offered the Companion track, things '
        'done together the Shared one', () {
      expect(suggestTrack('Read for 20 minutes'), Track.hero);
      expect(suggestTrack('Walk the dog'), Track.shared);
      expect(suggestTrack('Feed the cat'), Track.companion);
      expect(suggestTrack('Brush Babs', companionName: 'Babs'), Track.companion);
      expect(suggestTrack('Walk for 20 minutes'), Track.hero);
    });

    test('an anchor names its part of the day', () {
      expect(windowOfAnchor('After coffee or breakfast'), DayWindow.morning);
      expect(windowOfAnchor('after Babs’ evening walk'), DayWindow.evening);
      expect(windowOfAnchor('Whenever'), DayWindow.anytime);
    });
  });

  group('the class recommendation (Chapter 5)', () {
    test('goals and answers both count, and the reasoning is shown', () {
      final score = scoreClasses(
        answers: <HeroClass?>[
          HeroClass.warden, HeroClass.warden, HeroClass.ranger, null, null, null, //
        ],
        domains: <LifeDomain>[LifeDomain.body, LifeDomain.adventure],
      );
      expect(score.recommended, HeroClass.warden);
      expect(score.close, HeroClass.ranger);
      expect(
        score.reason,
        'Your goals lean Vitality and Adventure: Warden fits, Ranger is close.',
      );
      final again = ClassScore.fromJson(score.toJson());
      expect(again.recommended, HeroClass.warden);
      expect(again.scores[HeroClass.warden], score.scores[HeroClass.warden]);
    });

    test('with nothing answered it still recommends, and says why', () {
      final score = scoreClasses(
        answers: const <HeroClass?>[],
        domains: const <LifeDomain>[],
      );
      expect(HeroClass.choices, contains(score.recommended));
      expect(score.reason, isNotEmpty);
    });

    test('the quiz has six questions with an answer for each class', () {
      expect(quiz, hasLength(6));
      for (var q = 0; q < quiz.length; q++) {
        expect(quiz[q].answers, hasLength(HeroClass.choices.length));
        expect(quizOrder(q).toSet(), <int>{0, 1, 2, 3});
      }
    });
  });

  group('the questionnaire (Amendment v0.4 §3)', () {
    FirstDawnDraft scripted() => FirstDawnDraft(
          goals: <GoalDraft>[
            GoalDraft(
              domain: LifeDomain.body,
              why: 'Stairs without thinking about them',
              text: 'Feel stronger',
              plans: <PlanDraft>[
                PlanDraft(habit: 'Walk for 20 minutes', anchor: 'At lunch'),
                PlanDraft(
                  habit: 'Strength work for 20 minutes',
                  frequency: PlanFrequency.days,
                  weekdays: <int>{1, 3, 5},
                  dread: Dread.heavy,
                ),
              ],
            ),
            GoalDraft(
              domain: LifeDomain.making,
              why: 'A painted army on the table',
              plans: <PlanDraft>[
                PlanDraft(
                  habit: 'Paint for 30 minutes',
                  frequency: PlanFrequency.weekly,
                  weekdays: <int>{6},
                  tinyOnly: true,
                ),
              ],
            ),
          ],
          restDays: <int>{7},
        );

    test('seven chapters, each ending in its mirror, one step a screen', () {
      final steps = stepsFor(
        scripted(),
        calendarGranted: false,
        hasExisting: false,
      );
      for (var chapter = 1; chapter <= 6; chapter++) {
        final own = steps.where((s) => chapterOf(s) == chapter).toList();
        expect(own, isNotEmpty, reason: 'chapter $chapter');
        expect(own.last, 'c$chapter.mirror');
      }
      expect(steps.last, 'c7.camp');
      expect(steps.toSet(), hasLength(steps.length), reason: 'no step twice');
      expect(steps, contains('c3.dread.0.1'));
      expect(steps, isNot(contains('c6.series')));
      expect(
        stepsFor(scripted(), calendarGranted: true, hasExisting: true),
        containsAll(<String>['c6.calendars', 'c6.series', 'c7.existing']),
      );
    });

    test('with nothing chosen every chapter is still there to pass', () {
      final steps = stepsFor(
        FirstDawnDraft(),
        calendarGranted: false,
        hasExisting: false,
      );
      for (var chapter = 1; chapter <= chapterCount; chapter++) {
        expect(steps.any((s) => chapterOf(s) == chapter), isTrue);
      }
    });

    test('the draft survives being saved and read back', () {
      final d = scripted()
        ..quizAnswers[0] = 'warden'
        ..chosenClass = 'warden'
        ..at = 'c3.anchor.0.1'
        ..confirmed.add(1)
        ..existing['q9'] = 'goal:1';
      final back = FirstDawnDraft.decode(d.encode());
      expect(back.goals, hasLength(2));
      expect(back.goals[0].plans[1].dread, Dread.heavy);
      expect(back.goals[0].plans[1].weekdays, <int>{1, 3, 5});
      expect(back.goals[1].plans[0].tinyOnly, isTrue);
      expect(back.restDays, <int>{7});
      expect(back.quizAnswers[0], 'warden');
      expect(back.at, 'c3.anchor.0.1');
      expect(back.confirmed, <int>{1});
      expect(back.existing['q9'], 'goal:1');
      expect(FirstDawnDraft.decode('not json').goals, isEmpty);
    });

    test('answers become goals and plans, in the user’s words', () {
      var n = 0;
      final made = plansFrom(
        scripted(),
        newId: () => 'id${n++}',
        startDay: '2026-11-14',
      );
      expect(made.goals, hasLength(2));
      expect(made.goals[0].text, 'Feel stronger');
      expect(made.goals[0].why, 'Stairs without thinking about them');
      // A goal whose words were never given takes its why-line.
      expect(made.goals[1].text, 'A painted army on the table');
      expect(made.plans, hasLength(3));
      final walk = made.plans[0];
      expect(walk.goalId, made.goals[0].id);
      expect(walk.target, 'Walk for 20 minutes');
      expect(walk.tiny, 'Walk for 5 minutes');
      expect(walk.attribute, Attribute.vitality);
      expect(walk.window, DayWindow.afternoon);
      final paint = made.plans[2];
      expect(paint.attribute, Attribute.craft);
      expect(paint.weekdays, <int>{6});
      expect(paint.tinyUntil, '2026-11-20');
      expect(paint.schedule.isDueOn('2026-11-14'), isTrue, reason: 'a Saturday');
      expect(paint.schedule.isDueOn('2026-11-15'), isFalse);
    });

    test('the first week is laid out by the same rules as the board', () {
      final week = weekPreview(scripted(), startDay: '2026-11-14');
      expect(week, hasLength(7));
      final (saturday, onSaturday) = week[0];
      expect(saturday, '2026-11-14');
      expect(onSaturday.map((e) => e.text), <String>[
        'Walk for 20 minutes',
        'Paint for 5 minutes',
      ]);
      expect(onSaturday[1].size, QuestSize.tiny);
      // Sunday is a rest day: light, and nothing heavy.
      final (_, onSunday) = week[1];
      expect(onSunday.every((e) => e.size == QuestSize.tiny), isTrue);
      expect(onSunday.any((e) => e.heavy), isFalse);
      // Monday has the heavy one.
      final (_, onMonday) = week[2];
      expect(onMonday.where((e) => e.heavy), hasLength(1));
      for (final (_, entries) in week) {
        for (final e in entries) {
          expect(e.forLine, startsWith('For: '));
        }
      }
    });
  });

  group('the board Dawn composes (Amendment v0.4 §§1, 5)', () {
    final walk = plan('walk', 'Walk for 20 minutes', anchor: 'At lunch');
    final lift = plan(
      'lift',
      'Strength work for 20 minutes',
      dread: Dread.heavy,
      anchor: 'After work',
    );
    final run = plan(
      'run',
      'Run for 30 minutes',
      dread: Dread.heavy,
      anchor: 'After work',
    );
    final paint = plan(
      'paint',
      'Paint for 30 minutes',
      goal: army,
      anchor: 'After dinner',
    );
    final all = <HabitPlan>[walk, lift, run, paint];

    test('no quest without a source: every quest has a kind and a For-line',
        () {
      const own = QuestFact(
        id: 'q-own',
        name: 'Water the plants',
        source: QuestSource.recurring,
        attribute: Attribute.care,
        track: Track.hero,
        difficulty: Difficulty.minor,
      );
      const fromCalendar = QuestFact(
        id: 'q-cal',
        name: 'Dentist',
        source: QuestSource.calendar,
        attribute: Attribute.order,
        track: Track.hero,
        difficulty: Difficulty.standard,
      );
      final board = composeBoard(
        day: '2026-11-16',
        quests: <QuestFact>[
          for (final p in all) questOf(p),
          campfire,
          own,
          fromCalendar,
        ],
        goals: const <Goal>[stronger, army],
        plans: all,
        rhythm: const Rhythm(),
        calendarTimes: const <String, String>{'q-cal': '10:30'},
      );
      expect(board.order, hasLength(7));
      for (final id in board.order) {
        final line = board.lines[id]!;
        expect(line.forLine, startsWith('For: '));
        expect(line.forLine.length, greaterThan(6));
      }
      expect(board.lines['q-walk']!.kind, SourceKind.habit);
      expect(board.lines['q-walk']!.forLine, 'For: Feel stronger · at lunch');
      expect(board.lines['q-paint']!.forLine, 'For: Finish my army · after dinner');
      expect(board.lines['q-campfire']!.kind, SourceKind.system);
      expect(board.lines['q-own']!.kind, SourceKind.own);
      expect(board.lines['q-cal']!.forLine, 'For: your calendar · 10:30');
      expect(board.lines['q-cal']!.forLine, isNot(contains('Dentist')));
      expect(board.lines['q-walk']!.size, QuestSize.target);
      expect(board.lines['q-own']!.size, isNull);
    });

    test('two heavy habits are not left side by side', () {
      final board = composeBoard(
        day: '2026-11-16',
        quests: <QuestFact>[for (final p in all) questOf(p)],
        goals: const <Goal>[stronger, army],
        plans: all,
        rhythm: const Rhythm(),
      );
      // By window: walk (lunch), then lift and run (after work), then paint.
      // Paint is drawn between the two heavy ones.
      expect(board.order, <String>['q-walk', 'q-lift', 'q-paint', 'q-run']);
    });

    test('a rest day runs light: Tiny sizes, and the heavy habits stay off',
        () {
      final board = composeBoard(
        day: '2026-11-15',
        quests: <QuestFact>[for (final p in all) questOf(p)],
        goals: const <Goal>[stronger, army],
        plans: all,
        rhythm: const Rhythm(restDays: <int>{7}),
      );
      expect(board.order, <String>['q-walk', 'q-paint']);
      expect(board.lines['q-walk']!.size, QuestSize.tiny);
      expect(board.lines['q-walk']!.title, 'Walk for 5 minutes');
    });

    test('one quest is marked as feeding the class resource, and only while '
        'nothing done has fed it', () {
      ComposedBoard compose({bool walked = false}) => composeBoard(
            day: '2026-11-16',
            quests: <QuestFact>[
              questOf(walk, done: walked),
              questOf(paint),
              questOf(lift),
              campfire,
            ],
            goals: const <Goal>[stronger, army],
            plans: all,
            rhythm: const Rhythm(),
            heroClass: HeroClass.warden,
            encounterOpen: true,
          );
      final before = compose();
      final marked = <String>[
        for (final id in before.order)
          if (before.lines[id]!.feeds != null) id,
      ];
      // The heavy Vitality habit is worth most Guard.
      expect(marked, <String>['q-lift']);
      expect(before.lines['q-lift']!.feeds, 'Feeds Guard');
      expect(before.order, hasLength(4), reason: 'a highlight, not an addition');
      final after = compose(walked: true);
      expect(after.lines.values.where((l) => l.feeds != null), isEmpty);
    });

    test('the scout points existing quests at the fight, and says so when '
        'none feeds the resource', () {
      final lines = composeBoard(
        day: '2026-11-16',
        quests: <QuestFact>[questOf(paint), campfire],
        goals: const <Goal>[stronger, army],
        plans: all,
        rhythm: const Rhythm(),
      ).lines;
      expect(
        boardHint(
          cls: HeroClass.artificer,
          type: EnemyType.armoured,
          quests: <QuestFact>[questOf(paint), campfire],
          lines: lines,
        ),
        'Your Paint for 30 minutes stocks the pouch before you go in. A Trap '
        'breaks an Armoured hide.',
      );
      expect(
        boardHint(
          cls: HeroClass.warden,
          type: EnemyType.swift,
          quests: <QuestFact>[questOf(paint), campfire],
          lines: lines,
        ),
        contains('Nothing on today’s board feeds Guard in full'),
      );
    });
  });

  group('the calendar (Chapter 6, §2)', () {
    final paint = plan('paint', 'Paint for 30 minutes', goal: army);

    test('a series is remembered by a key that does not hold its title', () {
      final key = seriesKeyOf('cal1', 'Painting block');
      expect(key, startsWith('cal1:'));
      expect(key.toLowerCase(), isNot(contains('paint')));
      expect(seriesKeyOf('cal1', 'painting  BLOCK'), key);
      expect(seriesKeyOf('cal2', 'Painting block'), isNot(key));
    });

    test('recurring events are found, typed, and counted once each', () {
      final events = <EventFact>[
        event('Painting block', day: 17),
        event('Painting block', day: 24),
        event('Dentist', day: 18),
        event('Gym', day: 16, hour: 7),
        event('Gym', day: 18, hour: 7),
        event('Gym', day: 20, hour: 7),
      ];
      final series = recurringSeries(events);
      expect(series.map((s) => s.title), <String>['Painting block', 'Gym']);
      expect(series[0].proposed, MappingKind.craft);
      expect(series[0].count, 2);
      expect(series[0].when, 'Tuesdays · 14:00');
      expect(series[1].proposed, MappingKind.health);
      expect(proposeKind('Budget review'), MappingKind.commitment);
    });

    test('a calendar event that is a habit plan makes exactly one quest', () {
      final mapping = CalendarMapping(
        seriesKey: seriesKeyOf('cal1', 'Painting block'),
        kind: MappingKind.craft,
        planId: paint.id,
      );
      final today = planCalendar(
        events: <EventFact>[event('Painting block')],
        mappings: <CalendarMapping>[mapping],
        plans: <HabitPlan>[paint],
        boardNames: const <String, List<String>>{},
      );
      expect(today.asQuests, isEmpty);
      expect(today.suggestions, isEmpty);
      expect(today.merged.keys, <String>['q-paint']);
      final board = composeBoard(
        day: '2026-11-16',
        quests: <QuestFact>[questOf(paint)],
        goals: const <Goal>[army],
        plans: <HabitPlan>[paint],
        rhythm: const Rhythm(),
        merged: today.merged,
      );
      expect(board.order, <String>['q-paint']);
      expect(
        board.lines['q-paint']!.forLine,
        'For: Finish my army · on your calendar 14:00',
      );
    });

    test('a mapped event whose words match a quest on the board merges too; '
        'an unmapped one is only offered; an ignored one is nothing', () {
      CalendarMapping map(String title, MappingKind kind) => CalendarMapping(
            seriesKey: seriesKeyOf('cal1', title),
            kind: kind,
          );
      final today = planCalendar(
        events: <EventFact>[
          event('Paint'),
          event('Standup', hour: 9),
          event('Lunch with Sam', hour: 12),
          event('Budget review', hour: 16),
        ],
        mappings: <CalendarMapping>[
          map('Paint', MappingKind.craft),
          map('Standup', MappingKind.ignore),
          map('Budget review', MappingKind.commitment),
        ],
        plans: <HabitPlan>[paint],
        boardNames: <String, List<String>>{
          'q-paint': <String>[paint.target, paint.tiny, paint.stretch],
        },
      );
      expect(today.merged.keys, <String>['q-paint']);
      expect(today.asQuests.map((e) => e.title), <String>['Budget review']);
      expect(today.suggestions.map((e) => e.title), <String>['Lunch with Sam']);
    });

    test('a heavy event is offered a Prep before it and a Follow-through '
        'after, each once, and never again once turned off', () {
      final e = event('Board meeting', hour: 14);
      var mapping = CalendarMapping(
        seriesKey: e.seriesKey,
        kind: MappingKind.commitment,
        heavy: true,
      );
      List<CalendarOffer> at(int hour, {Set<String> settled = const <String>{}}) =>
          offersAt(
            now: DateTime(2026, 11, 16, hour),
            events: <EventFact>[e],
            mappings: <CalendarMapping>[mapping],
            settled: settled,
          );
      expect(at(9).single.prep, isTrue);
      expect(at(9).single.questName, 'Lay out what you need for Board meeting');
      expect(at(20).single.prep, isFalse);
      expect(at(9, settled: <String>{at(9).single.choiceKey}), isEmpty);
      mapping = mapping.copyWith(prepOff: true);
      expect(at(9), isEmpty);
      expect(at(20), hasLength(1));
      mapping = mapping.copyWith(heavy: false);
      expect(at(20), isEmpty);
    });
  });

  group('the Sunday Check-In (Amendment v0.4 §6)', () {
    final paint = plan('paint', 'Paint for 30 minutes', goal: army);
    final walk = plan('walk', 'Walk the dog');
    const mostlyTiny = SizeCounts(tiny: 3);

    test('at most one change is proposed, with the counts it rests on', () {
      final p = proposeChange(
        plans: <HabitPlan>[paint, walk],
        counts: const <String, SizeCounts>{'paint': mostlyTiny, 'walk': mostlyTiny},
        felt: Felt.right,
        declined: const <String>{},
      )!;
      expect(p.planId, 'paint');
      expect(p.kind, ProposalKind.shrinkTarget);
      expect(
        p.ask,
        'Paint for 30 minutes: 3 Tiny, 0 Target in two weeks. Shrink the '
        'Target to 20 minutes?',
      );
      expect(p.changed.target, 'Paint for 20 minutes');
      expect(p.changed.minutes, 20);
      expect(p.changed.tiny, paint.tiny, reason: 'the Tiny is left alone');
    });

    test('declining a proposal is final for that suggestion', () {
      var declined = <String>{};
      final first = proposeChange(
        plans: <HabitPlan>[paint],
        counts: const <String, SizeCounts>{'paint': mostlyTiny},
        felt: Felt.right,
        declined: declined,
      )!;
      declined = <String>{...declined, first.key};
      // The same counts, week after week: it is not put again.
      for (var week = 0; week < 4; week++) {
        final again = proposeChange(
          plans: <HabitPlan>[paint],
          counts: const <String, SizeCounts>{'paint': mostlyTiny},
          felt: Felt.right,
          declined: declined,
        );
        expect(again?.key, isNot(first.key));
        if (again != null) declined = <String>{...declined, again.key};
      }
      expect(
        proposeChange(
          plans: <HabitPlan>[paint],
          counts: const <String, SizeCounts>{'paint': mostlyTiny},
          felt: Felt.right,
          declined: declined,
        ),
        isNull,
      );
    });

    test('nothing is proposed when the counts suggest nothing', () {
      expect(
        proposeChange(
          plans: <HabitPlan>[paint, walk],
          counts: const <String, SizeCounts>{
            'paint': SizeCounts(tiny: 1, target: 4),
            'walk': SizeCounts(target: 9),
          },
          felt: Felt.right,
          declined: const <String>{},
        ),
        isNull,
      );
    });

    test('a week that felt too heavy offers weekdays only; one outgrown '
        'offers more', () {
      final heavy = proposeChange(
        plans: <HabitPlan>[walk],
        counts: const <String, SizeCounts>{'walk': SizeCounts(target: 5)},
        felt: Felt.heavy,
        declined: const <String>{},
      )!;
      expect(heavy.kind, ProposalKind.weekdaysOnly);
      expect(heavy.changed.frequency, PlanFrequency.weekdays);
      final grown = proposeChange(
        plans: <HabitPlan>[paint],
        counts: const <String, SizeCounts>{'paint': SizeCounts(stretch: 4)},
        felt: Felt.right,
        declined: const <String>{},
      )!;
      expect(grown.kind, ProposalKind.growTarget);
      expect(grown.changed.target, 'Paint for 40 minutes');
    });

    test('what was answered, declined and accepted is remembered', () {
      final c = const CheckIns()
          .withFelt('2026-11-15', Felt.heavy)
          .withDeclined('shrinkTarget:paint:20')
          .withAccepted('weekdaysOnly:walk:0');
      final back = CheckIns.decode(c.encode());
      expect(back.feltOn('2026-11-15'), Felt.heavy);
      expect(back.feltOn('2026-11-22'), isNull);
      expect(back.declined, <String>{'shrinkTarget:paint:20'});
      expect(back.accepted, <String>{'weekdaysOnly:walk:0'});
    });
  });

  test('goals, plans, mappings and the rhythm survive the settings table',
      () {
    final p = plan(
      'a',
      'Paint for 30 minutes',
      goal: army,
      frequency: PlanFrequency.days,
      weekdays: <int>{2, 6},
      dread: Dread.heavy,
      tinyUntil: '2026-11-20',
    );
    final back = decodePlans(encodePlans(<HabitPlan>[p])).single;
    expect(back.target, p.target);
    expect(back.weekdays, <int>{2, 6});
    expect(back.dread, Dread.heavy);
    expect(back.minutes, 30);
    expect(back.tinyUntil, '2026-11-20');
    expect(back.questId, 'q-a');
    expect(back.frequencyLabel, 'Tue, Sat');
    final g = decodeGoals(encodeGoals(const <Goal>[stronger])).single;
    expect(g.text, 'Feel stronger');
    expect(g.why, 'Stairs without thinking about them');
    expect(g.domain, LifeDomain.body);
    const m = CalendarMapping(
      seriesKey: 'cal1:abc',
      kind: MappingKind.health,
      heavy: true,
      prepOff: true,
    );
    final mb = decodeMappings(encodeMappings(const <CalendarMapping>[m])).single;
    expect(mb.kind, MappingKind.health);
    expect(mb.heavy, isTrue);
    expect(mb.prepOff, isTrue);
    expect(mb.followOff, isFalse);
    const r = Rhythm(
      wake: '6 to 8',
      peak: DayWindow.morning,
      restDays: <int>{7},
      sprints: true,
      calibration: 75,
      weekOneEnds: '2026-11-20',
    );
    final rb = decodeRhythm('{"wake":"6 to 8","peak":"morning","restDays":[7],'
        '"sprints":true,"calibration":75,"weekOneEnds":"2026-11-20"}');
    expect(rb.isRestDay('2026-11-15'), isTrue);
    expect(rb.calibrationOn('2026-11-20'), r.calibration);
    expect(rb.calibrationOn('2026-11-21'), 100);
    expect(decodeGoals('garbage'), isEmpty);
  });
}
