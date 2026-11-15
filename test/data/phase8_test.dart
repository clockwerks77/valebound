import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/data/settings.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/export/vault_port.dart';
import 'package:habit_adventure/rules/checkin.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/rules/generation.dart';
import 'package:habit_adventure/rules/goals.dart';
import 'package:habit_adventure/state/game_controller.dart';

import '../support/harness.dart';

// Amendment v0.4 against the real storage: First Dawn's answers becoming
// goals, plans and a board; sizes; the calendar; the Sunday Check-In; and
// what happens to a board that was there before.

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
          text: 'Finish my army',
          plans: <PlanDraft>[
            PlanDraft(
              habit: 'Paint for 30 minutes',
              frequency: PlanFrequency.weekly,
              weekdays: <int>{7},
              anchor: 'After dinner',
            ),
          ],
        ),
      ],
      chosenClass: 'warden',
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;
  late GameController game;
  late MemoryDevice device;

  setUp(() {
    now = DateTime(2026, 11, 14, 9);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
    device = MemoryDevice();
    game = GameController(repo, vault: const NoVault(), device: device);
  });

  tearDown(() async {
    game.dispose();
    await db.close();
  });

  Future<void> newHero() async {
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    await game.init();
  }

  Future<void> goTo(int dayOfMonth, [int hour = 9]) async {
    now = DateTime(2026, 11, dayOfMonth, hour);
    await game.refresh(fromDevice: true);
  }

  BoardQuest onBoard(String title) =>
      game.board.firstWhere((b) => game.titleFor(b) == title);

  Future<void> doAt(String title, QuestSize size) async {
    final entry = onBoard(title);
    while (game.sizeFor(entry.quest.id) != size) {
      game.cycleSize(entry.quest.id);
    }
    await game.complete(entry.quest.id);
  }

  group('First Dawn becomes a board (Amendment v0.4 §§1 to 3)', () {
    test('a new hero is marked for First Dawn; one from before is offered it',
        () async {
      await newHero();
      expect(game.firstDawnState, FirstDawnState.fresh);
      expect(game.firstDawnOffered, isFalse, reason: 'it opens by itself');
      await repo.setSetting(SettingKey.firstDawn, null);
      await game.refresh();
      expect(game.firstDawnState, FirstDawnState.offered);
      expect(game.firstDawnOffered, isTrue);
    });

    test('a scripted run makes a Week 1 board where every quest has a source '
        'and a For-line', () async {
      await newHero();
      await game.finishFirstDawn(scripted());
      expect(game.firstDawnState, FirstDawnState.done);
      expect(game.goals.map((g) => g.text), <String>[
        'Feel stronger',
        'Finish my army',
      ]);
      expect(game.plans, hasLength(3));
      expect(game.heroClass, HeroClass.warden);
      expect(game.settings.classScore, isNotNull);

      final seen = <String>{};
      final titles = <int, List<String>>{};
      for (var offset = 0; offset < 7; offset++) {
        await goTo(14 + offset);
        expect(game.board, isNotEmpty, reason: 'day ${14 + offset}');
        titles[14 + offset] = game.board.map(game.titleFor).toList();
        if (offset == 1) {
          expect(
            game.lineFor(onBoard('Paint for 30 minutes').quest.id)!.forLine,
            'For: Finish my army · after dinner',
          );
        }
        for (final b in game.board) {
          final line = game.lineFor(b.quest.id);
          expect(line, isNotNull, reason: b.quest.name);
          expect(
            line!.kind,
            anyOf(SourceKind.habit, SourceKind.system),
            reason: '${b.quest.name}: the starter board has stepped back',
          );
          expect(line.forLine, startsWith('For: '));
          if (line.kind == SourceKind.habit) {
            expect(line.goal, isNotNull);
            expect(line.forLine, contains(line.goal!.text));
            seen.add(game.titleFor(b));
          }
        }
      }
      expect(seen, <String>{
        'Walk for 20 minutes',
        'Strength work for 20 minutes',
        'Paint for 30 minutes',
      });

      // Saturday: the walk and the Campfire. Sunday adds the painting,
      // Monday the strength work.
      expect(titles[14], <String>['Walk for 20 minutes', 'Campfire Review']);
      expect(titles[15], contains('Paint for 30 minutes'));
      expect(titles[16], contains('Strength work for 20 minutes'));
      expect(titles[17], isNot(contains('Strength work for 20 minutes')));
    });

    test('the starter quests step back for a new hero who designed habits; '
        'none is deleted', () async {
      await newHero();
      final before = await repo.allQuests();
      await game.finishFirstDawn(scripted());
      final after = await repo.allQuests();
      expect(after.length, before.length + 3);
      for (final q in before) {
        final now = after.firstWhere((a) => a.id == q.id);
        expect(now.name, q.name);
        if (q.source == QuestSource.system) {
          expect(now.active, q.active);
        } else {
          expect(now.active, isFalse, reason: '${q.name} is in the library');
        }
      }
    });

    test('skipping every chapter still leaves a working board: the starter '
        'quests, each with a For-line', () async {
      await newHero();
      final before = game.board.map((b) => b.quest.name).toList();
      await game.finishFirstDawn(FirstDawnDraft());
      expect(game.firstDawnState, FirstDawnState.done);
      expect(game.goals, isEmpty);
      expect(game.plans, isEmpty);
      expect(game.board.map((b) => b.quest.name), before);
      expect(game.board, isNotEmpty);
      for (final b in game.board) {
        final line = game.lineFor(b.quest.id)!;
        expect(line.forLine, startsWith('For: '));
        expect(line.kind, anyOf(SourceKind.own, SourceKind.system));
      }
      // And it can be played.
      final walk = game.board.firstWhere((b) => b.quest.name == 'Walk Babs');
      expect(await game.complete(walk.quest.id), isNotNull);
    });

    test('a board from before 0.8 is reviewed, not replaced: pin, keep or '
        'archive, and nothing is deleted', () async {
      await newHero();
      await repo.setSetting(SettingKey.firstDawn, null);
      await game.refresh();
      final walk = game.quests.firstWhere((q) => q.name == 'Walk Babs');
      final check =
          game.quests.firstWhere((q) => q.name == 'Morning Health Check');
      final reset = game.quests.firstWhere((q) => q.name == 'Five-Minute Reset');
      await game.complete(walk.id);
      final count = game.quests.length;
      final xp = game.hero!.totalXp;

      final draft = scripted()
        ..existing[walk.id] = 'goal:0'
        ..existing[check.id] = 'keep'
        ..existing[reset.id] = 'archive';
      await game.finishFirstDawn(draft);

      expect(game.quests.length, count + 3, reason: 'only the new plans');
      expect(game.hero!.totalXp, xp);
      final pinned = game.quests.firstWhere((q) => q.id == walk.id);
      expect(pinned.active, isTrue);
      expect(pinned.goalId, game.goals.first.id);
      expect(
        game.lineFor(walk.id)!.forLine,
        startsWith('For: Feel stronger'),
      );
      expect(game.lineFor(walk.id)!.kind, SourceKind.habit);
      final kept = game.quests.firstWhere((q) => q.id == check.id);
      expect(kept.active, isTrue);
      expect(kept.goalId, isNull);
      expect(game.lineFor(check.id)!.kind, SourceKind.own);
      expect(game.quests.firstWhere((q) => q.id == reset.id).active, isFalse);
      // A starter quest nobody chose anything for is left exactly as it was.
      final steps = game.quests.firstWhere((q) => q.name == '7,000 Steps');
      expect(steps.active, isTrue);
    });
  });

  group('sizes (Amendment v0.4 §4)', () {
    test('a Tiny completion awards Minor XP and counts in full; Target and '
        'Stretch are worth more', () async {
      await newHero();
      await game.finishFirstDawn(scripted());
      final id = onBoard('Walk for 20 minutes').quest.id;
      expect(game.sizeFor(id), QuestSize.target);
      expect(game.worthFor(onBoard('Walk for 20 minutes')), Difficulty.standard);
      game.cycleSize(id);
      expect(game.sizeFor(id), QuestSize.stretch);
      game.cycleSize(id);
      expect(game.sizeFor(id), QuestSize.tiny);
      final tinyEntry = game.board.firstWhere((b) => b.quest.id == id);
      expect(game.titleFor(tinyEntry), 'Walk for 5 minutes');
      expect(game.worthFor(tinyEntry), Difficulty.minor);

      final done = (await game.complete(id))!;
      expect(done.heroXpGained, Difficulty.minor.xp);
      final entry = game.board.firstWhere((b) => b.quest.id == id);
      expect(entry.isDone, isTrue, reason: 'full completion credit');
      final row = entry.completion!;
      expect(row.difficultySnapshot, Difficulty.minor);
      expect(row.questNameSnapshot, 'Walk for 5 minutes');
      expect(sizeOf(row), QuestSize.tiny);
      expect(forLineOf(row), 'For: Feel stronger · at lunch');
      expect(sourceOf(row), 'habit');
      // It feeds the encounter like any Minor Vitality quest: Guard 2 + 1.
      expect(game.resourceNow, 3);

      await goTo(15);
      expect((await game.complete(id))!.heroXpGained, Difficulty.standard.xp);
      await goTo(16);
      await doAt('Walk for 20 minutes', QuestSize.stretch);
      final counts = await game.sizeCounts();
      final plan = game.plans.firstWhere((p) => p.questId == id);
      expect(counts[plan.id]!.label, '1 Tiny · 1 Target · 1 Stretch');
    });

    test('a heavy habit carries Heroic weight at its Target', () async {
      await newHero();
      await game.finishFirstDawn(scripted());
      await goTo(16); // Monday
      final entry = onBoard('Strength work for 20 minutes');
      expect(game.worthFor(entry), Difficulty.heroic);
      final done = (await game.complete(entry.quest.id))!;
      expect(done.heroXpGained, Difficulty.heroic.xp);
    });

    test('a rest day runs light, and week one runs at its calibration',
        () async {
      await newHero();
      final draft = scripted()
        ..restDays = <int>{7}
        ..calibration = 75;
      await game.finishFirstDawn(draft);
      expect(game.settings.rhythm.calibration, 75);
      await goTo(15); // Sunday, a rest day
      final titles = game.board.map(game.titleFor).toList();
      expect(titles, contains('Walk for 5 minutes'));
      expect(titles, contains('Paint for 5 minutes'));
      await goTo(16); // Monday, inside week one
      expect(game.board.map(game.titleFor), contains('Walk for 15 minutes'));
      await goTo(23); // the Monday after week one
      expect(game.board.map(game.titleFor), contains('Walk for 20 minutes'));
    });
  });

  group('the calendar (Amendment v0.4 §§2, 5 and Chapter 6)', () {
    CalendarEvent at(String title, int hour, {int day = 14, String id = '7'}) {
      final begin = DateTime(2026, 11, day, hour);
      return CalendarEvent(
        id: '$id@${begin.millisecondsSinceEpoch}',
        title: title,
        begin: begin,
        end: begin.add(const Duration(hours: 1)),
        calendarId: '1',
      );
    }

    Future<void> connected() async {
      device.calendarPermission = true;
      await repo.setSetting(SettingKey.calendarOn, '1');
      await repo.setSetting(SettingKey.calendarAsked, '1');
    }

    test('a calendar event that is a habit plan makes exactly one quest',
        () async {
      await newHero();
      await game.finishFirstDawn(scripted());
      await connected();
      final paint = game.plans.firstWhere((p) => p.target.startsWith('Paint'));
      device.events = <CalendarEvent>[at('Painting block', 14)];
      await game.saveMappings(<CalendarMapping>[
        CalendarMapping(
          seriesKey: seriesKeyOf('1', 'Painting block'),
          kind: MappingKind.craft,
          planId: paint.id,
        ),
      ]);
      // Saturday: the plan itself is for Sundays, and the calendar has it
      // today. One quest, the plan's.
      await goTo(14);
      final painting = <BoardQuest>[
        for (final b in game.board)
          if (b.quest.planId == paint.id || b.quest.source == QuestSource.calendar)
            b,
      ];
      expect(painting, hasLength(1));
      expect(painting.single.quest.id, paint.questId);
      expect(
        game.lineFor(paint.questId!)!.forLine,
        startsWith('For: Finish my army · on your calendar'),
      );
      expect(game.suggestions, isEmpty);
      expect(
        (await repo.allQuests()).where((q) => q.source == QuestSource.calendar),
        isEmpty,
      );
    });

    test('a mapped event becomes a quest by itself, an unmapped one is only '
        'offered, an ignored one is nothing; its title stays out of the log',
        () async {
      await newHero();
      await game.finishFirstDawn(scripted());
      await connected();
      device.events = <CalendarEvent>[
        at('Budget review', 10, id: '1'),
        at('Standup', 9, id: '2'),
        at('Lunch with Sam', 12, id: '3'),
      ];
      await game.saveMappings(<CalendarMapping>[
        CalendarMapping(
          seriesKey: seriesKeyOf('1', 'Budget review'),
          kind: MappingKind.commitment,
        ),
        CalendarMapping(
          seriesKey: seriesKeyOf('1', 'Standup'),
          kind: MappingKind.ignore,
        ),
      ]);
      await goTo(14);
      final fromCalendar = <BoardQuest>[
        for (final b in game.board)
          if (b.quest.source == QuestSource.calendar) b,
      ];
      expect(fromCalendar.map((b) => b.quest.name), <String>['Budget review']);
      expect(game.suggestions.map((e) => e.title), <String>['Lunch with Sam']);
      final line = game.lineFor(fromCalendar.single.quest.id)!;
      expect(line.kind, SourceKind.calendar);
      expect(line.forLine, startsWith('For: your calendar'));
      expect(line.forLine, isNot(contains('Budget')));

      // Refreshing does not make it twice.
      await game.refresh(fromDevice: true);
      expect(
        game.board.where((b) => b.quest.source == QuestSource.calendar),
        hasLength(1),
      );

      await game.complete(fromCalendar.single.quest.id);
      final logged = (await repo.completionsOn('2026-11-14')).single;
      expect(logged.questNameSnapshot, 'Calendar commitment');
      expect(forLineOf(logged), isNot(contains('Budget')));
    });

    test('with the export toggle on, the title is written', () async {
      await newHero();
      await connected();
      await game.setExportEventNames(on: true);
      device.events = <CalendarEvent>[at('Budget review', 10)];
      await game.saveMappings(<CalendarMapping>[
        CalendarMapping(
          seriesKey: seriesKeyOf('1', 'Budget review'),
          kind: MappingKind.commitment,
        ),
      ]);
      await goTo(14);
      final quest = game.board
          .firstWhere((b) => b.quest.source == QuestSource.calendar)
          .quest;
      await game.complete(quest.id);
      final logged = (await repo.completionsOn('2026-11-14')).single;
      expect(logged.questNameSnapshot, 'Budget review');
    });

    test('a heavy event is offered a Prep and a Follow-through; each is an '
        'offer, and "never for this one" is kept', () async {
      await newHero();
      await connected();
      device.events = <CalendarEvent>[at('Board meeting', 14)];
      await game.saveMappings(<CalendarMapping>[
        CalendarMapping(
          seriesKey: seriesKeyOf('1', 'Board meeting'),
          kind: MappingKind.commitment,
          heavy: true,
        ),
      ]);
      await goTo(14, 9);
      final before = game.board.length;
      expect(game.offers.single.prep, isTrue);
      expect(game.board.length, before, reason: 'an offer adds nothing');

      await game.acceptOffer(game.offers.single);
      expect(game.offers, isEmpty);
      final prep =
          game.board.firstWhere((b) => b.quest.source == QuestSource.prep);
      expect(prep.quest.name, 'Lay out what you need for Board meeting');
      expect(prep.quest.difficulty, Difficulty.minor);
      expect(game.lineFor(prep.quest.id)!.kind, SourceKind.prep);
      await game.complete(prep.quest.id);
      final logged = (await repo.completionsOn('2026-11-14'))
          .firstWhere((c) => c.questId == prep.quest.id);
      expect(logged.questNameSnapshot, 'Prep for a calendar commitment');

      // After it has begun, the Follow-through; and never again for this
      // series once that is said.
      await goTo(14, 20);
      expect(game.offers.single.prep, isFalse);
      await game.neverOffer(game.offers.single);
      expect(game.offers, isEmpty);
      device.events = <CalendarEvent>[at('Board meeting', 14, day: 21)];
      await goTo(21, 9);
      expect(
        game.offers.single.prep,
        isTrue,
        reason: 'only the Follow-through was turned off',
      );
      await goTo(21, 20);
      expect(game.offers, isEmpty);
    });

    test('the mapping pass finds the recurring events of four weeks', () async {
      await newHero();
      await connected();
      device.events = <CalendarEvent>[
        at('Painting block', 14, day: 17, id: '5'),
        at('Painting block', 14, day: 24, id: '5'),
        at('Dentist', 9, day: 18, id: '6'),
      ];
      await goTo(14);
      final series = await game.readSeries();
      expect(series.map((s) => s.title), <String>['Painting block']);
      expect(series.single.proposed, MappingKind.craft);
      expect(series.single.key, isNot(contains('Painting')));
    });

    test('a "not now" is not asked about again for a season', () async {
      await newHero();
      expect(game.calendarOfferDue, isTrue);
      await game.declineCalendar();
      expect(game.calendarOfferDue, isFalse);
      now = DateTime(2026, 12, 31, 9);
      await game.refresh();
      expect(game.calendarOfferDue, isFalse);
      now = DateTime(2027, 2, 13, 9);
      await game.refresh();
      expect(game.calendarOfferDue, isTrue);
    });
  });

  group('the Sunday Check-In (Amendment v0.4 §6)', () {
    Future<void> weekOfTinies() async {
      now = DateTime(2026, 11, 9, 9); // a Monday
      await newHero();
      final draft = FirstDawnDraft(
        goals: <GoalDraft>[
          GoalDraft(
            domain: LifeDomain.making,
            text: 'Finish my army',
            plans: <PlanDraft>[PlanDraft(habit: 'Paint for 30 minutes')],
          ),
        ],
      );
      await game.finishFirstDawn(draft);
      for (final d in <int>[9, 10, 11]) {
        await goTo(d);
        await doAt('Paint for 30 minutes', QuestSize.tiny);
      }
    }

    test('it opens on the weekly day, once', () async {
      await weekOfTinies();
      await goTo(14);
      expect(game.checkInOpen, isFalse, reason: 'Saturday');
      await goTo(15);
      expect(game.checkInOpen, isTrue);
      await game.answerCheckIn(Felt.right);
      expect(game.checkInOpen, isFalse);
      expect(game.settings.checkIns.feltOn('2026-11-15'), Felt.right);
    });

    test('a change is proposed, never made: the plan is as it was until the '
        'user says yes', () async {
      await weekOfTinies();
      await goTo(15);
      final proposal = (await game.answerCheckIn(Felt.right))!;
      expect(proposal.ask, contains('3 Tiny, 0 Target in two weeks'));
      expect(game.plans.single.target, 'Paint for 30 minutes');
      await game.acceptProposal(proposal);
      expect(game.plans.single.target, 'Paint for 20 minutes');
      expect(game.plans.single.minutes, 20);
      final quest =
          game.quests.firstWhere((q) => q.id == game.plans.single.questId);
      expect(quest.name, 'Paint for 20 minutes');
      expect(game.settings.checkIns.accepted, contains(proposal.key));
    });

    test('declining a proposal never re-proposes it', () async {
      await weekOfTinies();
      await goTo(15);
      final first = (await game.answerCheckIn(Felt.right))!;
      await game.declineProposal(first);
      expect(game.plans.single.target, 'Paint for 30 minutes');
      expect(game.settings.checkIns.declined, contains(first.key));

      // Another week of the same, and another, and it is not put again.
      for (final sunday in <int>[22, 29]) {
        for (final d in <int>[sunday - 5, sunday - 4, sunday - 3]) {
          await goTo(d);
          await doAt('Paint for 30 minutes', QuestSize.tiny);
        }
        await goTo(sunday);
        expect(game.checkInOpen, isTrue);
        final again = await game.answerCheckIn(Felt.right);
        expect(again?.key, isNot(first.key));
        if (again != null) await game.declineProposal(again);
      }
      expect(game.plans.single.target, 'Paint for 30 minutes');
    });
  });

  test('goals and plans come back from a backup', () async {
    await newHero();
    await game.finishFirstDawn(scripted());
    final backup = await repo.exportBackupJson();
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final restored = GameRepository(other, clock: () => now);
    expect((await restored.importBackupJson(backup)).ok, isTrue);
    final settings = await restored.settings();
    expect(settings.goals.map((g) => g.text), <String>[
      'Feel stronger',
      'Finish my army',
    ]);
    expect(settings.plans, hasLength(3));
    expect(settings.firstDawn, FirstDawnState.done);
    final quests = await restored.allQuests();
    for (final p in settings.plans) {
      final quest = quests.firstWhere((q) => q.id == p.questId);
      expect(quest.planId, p.id);
      expect(quest.goalId, p.goalId);
    }
  });
}
