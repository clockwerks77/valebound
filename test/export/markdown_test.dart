import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/export/markdown.dart';
import 'package:habit_adventure/rules/enums.dart';

// The Markdown export contract, DESIGN §11, checked field by field.

Map<MaterialKind, int> mats(int timber, int stone, int shards) =>
    <MaterialKind, int>{
      MaterialKind.timber: timber,
      MaterialKind.stone: stone,
      MaterialKind.starShard: shards,
    };

/// The frontmatter block as key → raw value.
Map<String, String> frontmatter(String markdown) {
  final lines = markdown.split('\n');
  expect(lines.first, '---', reason: 'file starts with frontmatter');
  final end = lines.indexOf('---', 1);
  expect(end, greaterThan(0), reason: 'frontmatter is closed');
  final out = <String, String>{};
  for (final line in lines.sublist(1, end)) {
    final split = line.indexOf(': ');
    expect(split, greaterThan(0), reason: 'frontmatter line "$line"');
    out[line.substring(0, split)] = line.substring(split + 2);
  }
  return out;
}

/// `## Heading` lines, in order.
List<String> sections(String markdown) => <String>[
      for (final line in markdown.split('\n'))
        if (line.startsWith('## ')) line.substring(3),
    ];

SheetData sheet() => SheetData(
      updated: DateTime(2026, 11, 14, 21, 30, 5),
      heroName: 'Adam',
      heroLevel: 4,
      heroTotalXp: 1014,
      title: 'Path Finder',
      attributes: const <AttributeLine>[
        AttributeLine(Attribute.vitality, 3, 610),
        AttributeLine(Attribute.care, 2, 195),
        AttributeLine(Attribute.craft, 1, 60),
        AttributeLine(Attribute.mind, 2, 140),
        AttributeLine(Attribute.adventure, 1, 0),
        AttributeLine(Attribute.order, 1, 9),
      ],
      questsCompleted: 72,
      gold: 310,
      stores: mats(3, 1, 9),
      gathered: mats(18, 15, 13),
      daysVisited: 15,
      companionName: 'Babs',
      companionKind: 'Hound',
      companionLevel: 3,
      companionXp: 525,
      bond: 33,
      tricks: const <String>['Sniff Out'],
      gear: const <String>['Moss Neckerchief', 'Brass Bell', 'Hearth Blanket'],
      paces: 30,
      discoveries: const <String>[
        'The Listening Stone',
        'Kettle Spring',
        'The Quiet Cart',
      ],
      placesRestored: 4,
      placesDrafted: 20,
      restoredByRegion: const <String, List<String>>{
        'Hearthmere': <String>[
          'The Gate Lantern',
          'The Village Well',
          'The Bakehouse',
          'The Moot Hall',
        ],
      },
      nextTarget: 'The Sheepfold',
      nextNeeds: const <TargetNeed>[
        TargetNeed(MaterialKind.timber, 3, 7),
        TargetNeed(MaterialKind.stone, 1, 4),
        TargetNeed(MaterialKind.starShard, 2, 2),
      ],
    );

DayData day({
  int paces = 2,
  List<String> discoveries = const <String>['The Quiet Cart'],
  List<HealthLine> health = const <HealthLine>[
    HealthLine('Glucose', '5.8', 'mmol/L'),
    HealthLine('Steps', '8,214', ''),
  ],
  List<String> restorations = const <String>['The Moot Hall (Hearthmere)'],
  String note = 'Long walk by the river. Babs found a stick.',
  int? steps = 8214,
  List<DayQuestLine>? quests,
}) =>
    DayData(
      day: '2026-11-14',
      heroLevel: 4,
      xpEarned: 118,
      companionXpEarned: 35,
      paces: paces,
      questsTotal: 8,
      steps: steps,
      quests: quests ??
          <DayQuestLine>[
            DayQuestLine(
              completedAt: DateTime(2026, 11, 14, 7, 40),
              quest: 'Morning Health Check',
              track: Track.hero,
              attribute: Attribute.vitality,
              difficulty: Difficulty.minor,
              heroXp: 10,
              companionXp: 0,
              forWhat: 'Feel stronger · after coffee',
            ),
            DayQuestLine(
              completedAt: DateTime(2026, 11, 14, 8, 25),
              quest: 'Walk Babs',
              track: Track.shared,
              attribute: Attribute.care,
              difficulty: Difficulty.standard,
              heroXp: 13,
              companionXp: 25,
            ),
            DayQuestLine(
              completedAt: DateTime(2026, 11, 14, 16, 10),
              quest: 'Play / Train with Babs',
              track: Track.companion,
              attribute: Attribute.care,
              difficulty: Difficulty.minor,
              heroXp: 0,
              companionXp: 10,
            ),
          ],
      pacesTotal: 30,
      campRegion: 'Hearthmere',
      pacesToNextDiscovery: 10,
      discoveries: discoveries,
      health: health,
      restorations: restorations,
      note: note,
    );

void main() {
  group('File names', () {
    test('the three files the design names', () {
      expect(characterSheetFile, 'Character Sheet.md');
      expect(questsFile, 'Quests.md');
      expect(dailyFile('2026-11-14'), 'Daily/2026-11-14.md');
    });
  });

  group('Every file: UTF-8 text, LF endings, YAML frontmatter', () {
    final files = <String, String>{
      'sheet': characterSheetMarkdown(sheet()),
      'day': dailyMarkdown(day()),
      'quests': questsMarkdown(
        QuestsData(
          updated: DateTime(2026, 11, 14, 21, 30, 5),
          companionName: 'Babs',
          quests: const <QuestLine>[],
        ),
      ),
    };
    for (final entry in files.entries) {
      test(entry.key, () {
        final text = entry.value;
        expect(text.contains('\r'), isFalse, reason: 'LF only');
        expect(text.startsWith('---\n'), isTrue);
        expect(text.endsWith('\n'), isTrue);
        expect(text.endsWith('\n\n'), isFalse);
        expect(frontmatter(text)['type'], startsWith('valebound-'));
      });
    }
  });

  group('Character Sheet.md', () {
    final text = characterSheetMarkdown(sheet());

    test('frontmatter has exactly the fields in §11', () {
      expect(frontmatter(text), <String, String>{
        'type': 'valebound-character',
        'updated': '2026-11-14T21:30:05',
        'level': '4',
        'total_xp': '1014',
        'companion_name': '"Babs"',
        'companion_kind': '"Hound"',
        'companion_level': '3',
        'bond': '33',
      });
    });

    test('body: attributes, totals, title, Companion, World', () {
      expect(sections(text), <String>['Attributes', 'Totals', 'Companion', 'World']);
      expect(text, contains('- Title: Path Finder'));
      expect(text, contains('| Attribute | Level | XP |\n|---|---|---|\n| Vitality | 3 | 610 |'));
      for (final a in Attribute.values) {
        expect(text, contains('| ${a.label} | '));
      }
      expect(text, contains('- Total XP: 1014'));
      expect(text, contains('- Quests completed: 72'));
      expect(text, contains('- Gold: 310'));
      expect(text, contains('- Materials in the stores: Timber 3, Stone 1, Star Shards 9'));
    });

    test('the Companion section has every field in §11', () {
      final start = text.indexOf('## Companion');
      final companion = text.substring(start, text.indexOf('## World'));
      expect(companion, contains('- Kind: Hound'));
      expect(companion, contains('- Name: Babs'));
      expect(companion, contains('- Level: 3'));
      expect(companion, contains('- Companion XP: 525'));
      expect(companion, contains('- Bond: 33'));
      expect(companion, contains('- Tricks: Sniff Out'));
      expect(companion, contains('- Gear: Moss Neckerchief, Brass Bell, Hearth Blanket'));
      expect(companion, contains('- Paces: 30'));
      expect(
        companion,
        contains('- Discoveries: 3 (The Listening Stone, Kettle Spring, The Quiet Cart)'),
      );
    });

    test('the world restoration summary', () {
      expect(text, contains('- Places restored: 4 of 20'));
      expect(
        text,
        contains('- Hearthmere: The Gate Lantern, The Village Well, The Bakehouse, The Moot Hall'),
      );
      expect(
        text,
        contains('- Working toward: The Sheepfold (Timber 3 of 7, Stone 1 of 4, Star Shards 2 of 2)'),
      );
    });

    test('a companion name with quotes or a colon stays valid YAML', () {
      final odd = characterSheetMarkdown(
        SheetData(
          updated: DateTime(2026, 11, 14),
          heroName: 'Adam',
          heroLevel: 1,
          heroTotalXp: 0,
          title: 'Newcomer to the Vale',
          attributes: const <AttributeLine>[],
          questsCompleted: 0,
          gold: 0,
          stores: const <MaterialKind, int>{},
          gathered: const <MaterialKind, int>{},
          daysVisited: 1,
          companionName: 'Sir "Tock": the 2nd',
          companionKind: 'Clockwork Sprite',
          companionLevel: 1,
          companionXp: 0,
          bond: 0,
          tricks: const <String>[],
          gear: const <String>[],
          paces: 0,
          discoveries: const <String>[],
          placesRestored: 0,
          placesDrafted: 20,
          restoredByRegion: const <String, List<String>>{},
          nextTarget: 'The Gate Lantern',
          nextNeeds: const <TargetNeed>[
            TargetNeed(MaterialKind.timber, 0, 2),
            TargetNeed(MaterialKind.stone, 0, 1),
            TargetNeed(MaterialKind.starShard, 0, 0),
          ],
        ),
      );
      expect(
        frontmatter(odd)['companion_name'],
        r'"Sir \"Tock\": the 2nd"',
      );
      expect(odd, contains('- Tricks: none yet'));
      expect(odd, contains('- Gear: none yet'));
      expect(odd, contains('- Discoveries: 0'));
      // A material the place does not ask for is left out.
      expect(odd, contains('- Working toward: The Gate Lantern (Timber 0 of 2, Stone 0 of 1)'));
    });
  });

  group('Daily/YYYY-MM-DD.md', () {
    test('frontmatter has every field §11 says it MUST, in order', () {
      final text = dailyMarkdown(day());
      final fm = frontmatter(text);
      expect(fm.keys.toList(), <String>[
        'type',
        'date',
        'level',
        'xp_earned',
        'companion_xp_earned',
        'paces',
        'quests_completed',
        'quests_total',
        'steps',
      ]);
      expect(fm['type'], 'valebound-day');
      expect(fm['date'], '2026-11-14');
      expect(fm['level'], '4');
      expect(fm['xp_earned'], '118');
      expect(fm['companion_xp_earned'], '35');
      expect(fm['paces'], '2');
      expect(fm['quests_completed'], '3');
      expect(fm['quests_total'], '8');
      expect(fm['steps'], '8214');
    });

    test('steps is left out when it is not known', () {
      final fm = frontmatter(dailyMarkdown(day(steps: null)));
      expect(fm.containsKey('steps'), isFalse);
    });

    test('sections come in the order §11 gives', () {
      expect(sections(dailyMarkdown(day())), <String>[
        'Quests Completed',
        'Journey',
        'Health',
        'World',
        'Notes',
      ]);
    });

    test('the quest table: Time | Quest | Track | Attribute | Difficulty | XP '
        '| For (Amendment v0.4 §8)', () {
      final text = dailyMarkdown(day());
      expect(
        text,
        contains(
          '| Time | Quest | Track | Attribute | Difficulty | XP | For |\n'
          '|---|---|---|---|---|---|---|\n'
          '| 07:40 | Morning Health Check | Hero | Vitality | Minor | 10 XP | Feel stronger · after coffee |\n'
          '| 08:25 | Walk Babs | Shared | Care | Standard | 13 XP + 25 Companion XP |  |\n'
          '| 16:10 | Play / Train with Babs | Companion | Care | Minor | 10 Companion XP |  |\n',
        ),
      );
    });

    test('Goals & Habits.md: goals with their why-lines, habits in three '
        'sizes, class and companion', () {
      final text = goalsMarkdown(
        GoalsData(
          updated: DateTime(2026, 11, 14, 21, 30),
          heroClass: 'Warden',
          companionName: 'Babs',
          companionKind: 'Hound',
          goals: const <GoalBlock>[
            GoalBlock(
              text: 'Feel stronger',
              domain: 'Body & Health',
              why: 'Stairs without thinking about them',
              horizon: 'This season',
              check: 'I take the stairs',
              habits: <HabitLine>[
                HabitLine(
                  target: 'Walk for 20 minutes',
                  tiny: 'Walk for 5 minutes',
                  stretch: 'Walk for 30 minutes',
                  anchor: 'At lunch',
                  frequency: 'Every day',
                  track: Track.hero,
                ),
              ],
            ),
          ],
        ),
      );
      expect(goalsFile, 'Goals & Habits.md');
      expect(
        text,
        '---\n'
        'type: valebound-goals\n'
        'updated: 2026-11-14T21:30:00\n'
        'active_goals: 1\n'
        'class: "Warden"\n'
        'companion_name: "Babs"\n'
        'companion_kind: "Hound"\n'
        '---\n'
        '\n'
        '# Goals & Habits\n'
        '\n'
        '## Feel stronger\n'
        '\n'
        '- Part of life: Body & Health\n'
        '- Why: Stairs without thinking about them\n'
        '- Horizon: This season\n'
        '- Working when: I take the stairs\n'
        '\n'
        '| Habit (Target) | When | How often | Tiny | Stretch | Track |\n'
        '|---|---|---|---|---|---|\n'
        '| Walk for 20 minutes | At lunch | Every day | Walk for 5 minutes | Walk for 30 minutes | Hero |\n'
        '\n'
        '## Class and companion\n'
        '\n'
        '- Class: Warden\n'
        '- Companion: Babs (Hound)\n',
      );
      final empty = goalsMarkdown(
        GoalsData(
          updated: DateTime(2026, 11, 14, 21, 30),
          heroClass: '',
          companionName: 'Babs',
          companionKind: 'Hound',
          goals: const <GoalBlock>[],
        ),
      );
      expect(empty, contains('No goals stated yet.'));
      expect(empty, contains('- Class: not chosen yet'));
      expect(empty, isNot(contains('class: "')));
    });

    test('a quest name with a pipe cannot break the table', () {
      final text = dailyMarkdown(
        day(
          quests: <DayQuestLine>[
            DayQuestLine(
              completedAt: DateTime(2026, 11, 14, 9),
              quest: 'Tidy desk | shelf',
              track: Track.hero,
              attribute: Attribute.order,
              difficulty: Difficulty.minor,
              heroXp: 10,
              companionXp: 0,
            ),
          ],
        ),
      );
      expect(text, contains(r'| 09:00 | Tidy desk \| shelf | Hero |'));
    });

    test('Journey: Paces today, any Discovery, camp position', () {
      final text = dailyMarkdown(day());
      expect(text, contains('## Journey\n\n- Paces today: 2\n- Discovery: The Quiet Cart\n'));
      expect(
        text,
        contains('- Camp: 30 Paces along the road, in Hearthmere. 10 to the next discovery.'),
      );
    });

    test('Journey is left out only with zero Paces and no Discovery', () {
      final none = dailyMarkdown(day(paces: 0, discoveries: const <String>[]));
      expect(sections(none), isNot(contains('Journey')));
      final pacesOnly = dailyMarkdown(day(discoveries: const <String>[]));
      expect(sections(pacesOnly), contains('Journey'));
      final discoveryOnly = dailyMarkdown(day(paces: 0));
      expect(sections(discoveryOnly), contains('Journey'));
    });

    test('Health lists what was logged, and is left out entirely when empty',
        () {
      final text = dailyMarkdown(day());
      expect(text, contains('## Health\n\n- Glucose: 5.8 mmol/L\n- Steps: 8,214\n'));
      final none = dailyMarkdown(day(health: const <HealthLine>[]));
      expect(sections(none), isNot(contains('Health')));
    });

    test('World lists the day’s restorations, or says the Vale rests', () {
      expect(
        dailyMarkdown(day()),
        contains('## World\n\n- Restored: The Moot Hall (Hearthmere)\n'),
      );
      final quiet = dailyMarkdown(day(restorations: const <String>[]));
      expect(quiet, contains('## World\n\nThe Vale rests.\n'));
    });

    test('Notes is the Campfire note verbatim, left out when empty', () {
      const note = 'First line.\n\n- a list item\n- **bold** stays as typed';
      final text = dailyMarkdown(day(note: note));
      expect(text.endsWith('## Notes\n\n$note\n'), isTrue);
      expect(sections(dailyMarkdown(day(note: ''))), isNot(contains('Notes')));
      expect(sections(dailyMarkdown(day(note: '   '))), isNot(contains('Notes')));
    });

    test('a day with a note but no quests still makes a tidy file', () {
      final text = dailyMarkdown(
        day(
          quests: const <DayQuestLine>[],
          paces: 0,
          discoveries: const <String>[],
          health: const <HealthLine>[],
          restorations: const <String>[],
          steps: null,
        ),
      );
      expect(frontmatter(text)['quests_completed'], '0');
      expect(text, contains('## Quests Completed\n\nA quiet day in the Vale.\n'));
      expect(sections(text), <String>['Quests Completed', 'World', 'Notes']);
    });

    test('quests_total is never below quests_completed', () {
      final text = dailyMarkdown(
        DayData(
          day: '2026-11-14',
          heroLevel: 1,
          xpEarned: 10,
          companionXpEarned: 0,
          paces: 0,
          questsTotal: 0,
          quests: <DayQuestLine>[
            DayQuestLine(
              completedAt: DateTime(2026, 11, 14, 9),
              quest: 'One-off',
              track: Track.hero,
              attribute: Attribute.order,
              difficulty: Difficulty.minor,
              heroXp: 10,
              companionXp: 0,
            ),
          ],
          pacesTotal: 0,
          campRegion: 'Hearthmere',
          pacesToNextDiscovery: 10,
        ),
      );
      expect(frontmatter(text)['quests_total'], '1');
    });
  });

  group('Quests.md', () {
    final text = questsMarkdown(
      QuestsData(
        updated: DateTime(2026, 11, 14, 21, 30, 5),
        companionName: 'Babs',
        quests: const <QuestLine>[
          QuestLine(
            name: '7,000 Steps',
            attribute: Attribute.vitality,
            difficulty: Difficulty.standard,
            schedule: 'Daily',
            type: 'Auto, 7,000 steps',
            track: Track.hero,
          ),
          QuestLine(
            name: 'Walk Babs',
            attribute: Attribute.care,
            difficulty: Difficulty.standard,
            schedule: 'Daily',
            type: 'Tap',
            track: Track.shared,
          ),
          QuestLine(
            name: 'Play / Train with Babs',
            attribute: Attribute.care,
            difficulty: Difficulty.minor,
            schedule: 'Daily',
            type: 'Timer, 10 min',
            track: Track.companion,
          ),
        ],
      ),
    );

    test('frontmatter', () {
      expect(frontmatter(text), <String, String>{
        'type': 'valebound-quests',
        'updated': '2026-11-14T21:30:05',
        'active_quests': '3',
      });
    });

    test('each quest: name, attribute, difficulty, schedule, type', () {
      expect(
        text,
        contains('- **7,000 Steps** · Vitality · Standard · Daily · Auto, 7,000 steps\n'),
      );
      expect(
        text,
        contains('- **Walk Babs** · Care · Standard · Daily · Tap · Shared track\n'),
      );
      expect(
        text,
        contains(
          '- **Play / Train with Babs** · Care · Minor · Daily · Timer, 10 min · Companion track\n',
        ),
      );
      expect(sections(text), <String>['Hero', 'With Babs']);
    });
  });

  group('Helpers', () {
    test('describeType', () {
      expect(describeType(CompletionType.tap, null), 'Tap');
      expect(describeType(CompletionType.count, 8), 'Count to 8');
      expect(describeType(CompletionType.timer, 60), 'Timer, 60 min');
      expect(describeType(CompletionType.auto, 7000), 'Auto, 7,000 steps');
      expect(describeType(CompletionType.confirm, null), 'Confirm');
    });

    test('thousands, healthLabel, isoLocal', () {
      expect(thousands(0), '0');
      expect(thousands(999), '999');
      expect(thousands(7412), '7,412');
      expect(thousands(1234567), '1,234,567');
      expect(healthLabel('steps'), 'Steps');
      expect(healthLabel('time_in_range'), 'Time in range');
      expect(healthLabel('resting_heart_rate'), 'Resting heart rate');
      expect(isoLocal(DateTime(2026, 1, 2, 3, 4, 5)), '2026-01-02T03:04:05');
    });
  });
}
