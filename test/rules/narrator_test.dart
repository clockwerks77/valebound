import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/narrator.dart';
import 'package:habit_adventure/rules/world.dart';

// The narrator (DECISIONS D-76): the words Adam chose, and the rules for
// which line is told when.

/// 2026-11-14, a Saturday: the day the narrator arrived.
const String saturday = '2026-11-14';
final DateTime morning = DateTime(2026, 11, 14, 9, 12);

Narration at({
  DateTime? now,
  String day = saturday,
  int restored = 1,
  int paces = 0,
  bool returning = false,
}) =>
    dawnNarration(
      now: now ?? morning,
      day: day,
      restored: restored,
      paces: paces,
      companionName: 'Nhia',
      returning: returning,
    );

void main() {
  group('The prologue', () {
    test('opens with the three beats Adam chose', () {
      final pages = prologuePages('Nhia');
      expect(
        pages[0].text,
        'You come over the last hill at first light, and Nhia is already '
        'ahead of you.',
      );
      expect(
        pages[1].text,
        'Below lies the Vale. It should be full of lantern light. It is '
        'grey, and very quiet.',
      );
      expect(pages[2].text, 'One lantern still burns, at the gate.');
      expect(prologueArrivalPages, 3);
    });

    test('then says what the Vale is and what the days do for it', () {
      final pages = prologuePages('Babs');
      expect(pages.length, 5);
      expect(pages[3].text, contains('asleep'));
      expect(pages[4].text, contains('timber, stone and light'));
      expect(pages[4].text, contains('with Babs'));
      expect(pages.last.text, endsWith('Begin at the gate.'));
    });

    test('speaks to the player, in the present tense', () {
      final all = prologuePages('Babs').map((p) => p.text).join(' ');
      expect(all, contains('You come'));
      expect(all, isNot(contains(' came ')));
      expect(all, isNot(contains(' was ')));
    });
  });

  group('Chapters', () {
    test('one to a region, in the order the regions wake', () {
      expect(chapters.length, regions.length);
      for (var i = 0; i < chapters.length; i++) {
        expect(chapters[i].number, i + 1);
        expect(chapters[i].region, regions[i].key);
        expect(chapters[i].opens, isNotEmpty);
        expect(chapters[i].wakes, startsWith(regions[i].name == 'The Silverrun'
            ? 'The Silverrun is awake'
            : '${regions[i].name} is awake'));
      }
      expect(chapters.first.heading, 'Chapter One · Hearthmere');
      expect(chapters[2].heading, 'Chapter Three · The Silverrun');
    });

    test('the chapter follows the place being woken', () {
      expect(chapterAt(0).number, 1);
      expect(chapterAt(3).number, 1, reason: 'the Moot Hall is still asleep');
      expect(chapterAt(4).number, 2);
      expect(chapterAt(7).number, 2);
      expect(chapterAt(8).number, 3);
      expect(chapterAt(16).number, 5);
      expect(chapterAt(19).number, 5);
      expect(chapterAt(20).number, 5);
      expect(chapterAt(34).number, 5);
    });

    test('a chapter closes with the last place of its region', () {
      for (var i = 0; i < restorationTargets.length; i++) {
        final closed = chapterClosedBy(i);
        if ((i + 1) % 4 == 0) {
          expect(closed, isNotNull, reason: restorationTargets[i].name);
          expect(closed!.region, restorationTargets[i].region);
        } else {
          expect(closed, isNull, reason: restorationTargets[i].name);
        }
      }
      expect(chapterClosedBy(-1), isNull);
      expect(chapterClosedBy(20), isNull, reason: 'a Vale lantern');
      expect(chapterAfter(chapters[0])!.number, 2);
      expect(chapterAfter(chapters[4]), isNull);
    });

    test('progress counts the places of that region only', () {
      expect(chapterProgress(chapters[0], 0), (awake: 0, of: 4));
      expect(chapterProgress(chapters[0], 3), (awake: 3, of: 4));
      expect(chapterProgress(chapters[0], 9), (awake: 4, of: 4));
      expect(chapterProgress(chapters[1], 5), (awake: 1, of: 4));
      expect(chapterProgress(chapters[4], 5), (awake: 0, of: 4));
    });

    test('the heading over the story', () {
      expect(storyHeading(0), 'Chapter One · Hearthmere');
      expect(storyHeading(5), 'Chapter Two · Larkdown');
      expect(storyHeading(19), 'Chapter Five · Old Lanternhall');
      expect(storyHeading(20), 'The Vale awake');
      expect(valeIsAwake(19), isFalse);
      expect(valeIsAwake(20), isTrue);
    });
  });

  group('The Dawn line', () {
    test('the line Adam chose, on the day he first reads it', () {
      final n = at();
      expect(n.setting, 'Morning in Hearthmere');
      expect(n.line, 'The Gate Lantern is burning. The well is waiting.');
      expect(
        n.full,
        'Morning in Hearthmere. The Gate Lantern is burning. The well is '
        'waiting.',
      );
    });

    test('follows the clock', () {
      String setting(int hour) =>
          at(now: DateTime(2026, 11, 14, hour, 30)).setting;
      expect(setting(5), 'Morning in Hearthmere');
      expect(setting(11), 'Morning in Hearthmere');
      expect(setting(12), 'Afternoon in Hearthmere');
      expect(setting(16), 'Afternoon in Hearthmere');
      expect(setting(17), 'Evening in Hearthmere');
      expect(setting(21), 'Evening in Hearthmere');
      expect(setting(22), 'Night in Hearthmere');
      expect(setting(3), 'Night in Hearthmere');
    });

    test('is set where the camp is on the road', () {
      expect(at(paces: 0).setting, 'Morning in Hearthmere');
      expect(at(paces: 39).setting, 'Morning in Hearthmere');
      expect(at(paces: 40).setting, 'Morning in Larkdown');
      expect(at(paces: 95).setting, 'Morning on the Silverrun');
      expect(at(paces: 130).setting, 'Morning in Highcairn');
      expect(at(paces: 170).setting, 'Morning in Old Lanternhall');
      expect(at(paces: 900).setting, 'Morning in Old Lanternhall');
    });

    test('before anything is awake', () {
      final n = at(restored: 0);
      expect(n.line, 'Every door is shut. The Gate Lantern burns low, and waits.');
    });

    test('always ends on the place that is waiting', () {
      for (var restored = 0; restored <= 22; restored++) {
        for (var d = 0; d < 8; d++) {
          final day = DayKey.addDays(saturday, d);
          final n = at(day: day, restored: restored);
          expect(
            n.line,
            endsWith(placeWaiting(targetAt(restored))),
            reason: '$restored places, $day',
          );
        }
      }
    });

    test('is the same all day, and turns with the calendar', () {
      expect(at().line, at(now: DateTime(2026, 11, 14, 20)).line);
      final week = <String>{
        for (var d = 0; d < 4; d++)
          at(day: DayKey.addDays(saturday, d), restored: 5).line,
      };
      expect(week.length, 4, reason: 'four days, four different lines');
    });

    test('names the companion on its day', () {
      final lines = <String>[
        for (var d = 0; d < 4; d++)
          at(day: DayKey.addDays(saturday, d), restored: 5).line,
      ];
      expect(lines.where((l) => l.contains('Nhia')).length, 1);
    });

    test('counts what is awake, in words', () {
      final lines = <String>[
        for (var d = 0; d < 4; d++)
          at(day: DayKey.addDays(saturday, d), restored: 5).line,
      ];
      expect(
        lines.where((l) => l.startsWith('Five places are awake')).length,
        1,
      );
      expect(numberWord(1), 'One');
      expect(numberWord(20), 'Twenty');
      expect(numberWord(21), '21');
    });

    test('after days away it says only that the Vale has kept', () {
      final n = at(restored: 5, returning: true);
      expect(
        n.line,
        'The Vale has kept, just as you left it. The sails of Larkdown Mill '
        'hang still, waiting for a wind.',
      );
    });

    test('every drafted place has its own two lines', () {
      final lit = <String>{};
      final waiting = <String>{};
      for (final target in restorationTargets) {
        lit.add(placeLit(target));
        waiting.add(placeWaiting(target));
      }
      expect(lit.length, restorationTargets.length);
      expect(waiting.length, restorationTargets.length);
      // Past the drafted places the road still has a line.
      expect(placeWaiting(targetAt(20)), 'One more lantern waits along the road.');
      expect(placeLit(targetAt(20)), isNotEmpty);
    });

    test('every region has a setting of its own', () {
      final settings = <String>{for (final r in regions) whereIn(r.key)};
      expect(settings.length, regions.length);
      expect(whereIn('nowhere'), 'in the Vale');
    });
  });

  group('The Campfire line', () {
    String fire({
      String day = saturday,
      int questsDone = 0,
      List<RestorationTarget> woke = const <RestorationTarget>[],
      String? creature,
      int restored = 1,
    }) =>
        campfireNarration(
          day: day,
          questsDone: questsDone,
          wokeToday: woke,
          creatureWoke: creature,
          companionName: 'Nhia',
          next: targetAt(restored),
        );

    test('a day with nothing done is as warm as any other', () {
      final line = fire();
      expect(
        line,
        startsWith('The fire is lit all the same. The Vale keeps, and so '
            'does the road.'),
      );
      expect(line.toLowerCase(), isNot(contains('nothing')));
      expect(line.toLowerCase(), isNot(contains('no quests')));
    });

    test('counts the quests done, in words', () {
      expect(fire(questsDone: 1), startsWith('One quest done, and the fire'));
      expect(fire(questsDone: 3), startsWith('Three quests done, and the'));
      expect(fire(questsDone: 24), startsWith('24 quests done'));
    });

    test('a place that woke comes first', () {
      expect(
        fire(questsDone: 4, woke: <RestorationTarget>[targetAt(1)]),
        startsWith('The fire is lit. The Village Well woke today, and Marla '
            'is home.'),
      );
      expect(
        fire(
          questsDone: 9,
          woke: <RestorationTarget>[targetAt(1), targetAt(2), targetAt(3)],
        ),
        startsWith('The fire is lit. The Village Well, The Bakehouse and '
            'The Moot Hall woke today.'),
      );
      expect(
        fire(questsDone: 2, woke: <RestorationTarget>[targetAt(21)]),
        startsWith('The fire is lit. One more lantern burns along the road'),
      );
    });

    test('then the day’s creature', () {
      expect(
        fire(questsDone: 3, creature: 'Fogfinch'),
        startsWith('The fire is lit. The Fogfinch woke today'),
      );
    });

    test('closes three ways, turning with the calendar', () {
      final endings = <String>{
        for (var d = 0; d < 3; d++)
          fire(day: DayKey.addDays(saturday, d), questsDone: 2)
              .replaceFirst('Two quests done, and the fire is warm. ', ''),
      };
      expect(endings, <String>{
        'Nhia is asleep before the kettle boils.',
        'The Village Well will be there in the morning.',
        'It is quiet in the Vale tonight, the good kind of quiet.',
      });
    });
  });

  group('The Chronicle', () {
    Map<String, String> datedFrom(int restored, String firstDay) =>
        <String, String>{
          for (var i = 0; i < restored && i < restorationTargets.length; i++)
            restorationTargets[i].key: DayKey.addDays(firstDay, i),
        };

    List<ChronicleEntry> story(int restored) => chronicle(
          arrivedOn: '2026-11-01',
          companionName: 'Nhia',
          restored: restored,
          restoredOn: datedFrom(restored, '2026-11-02'),
        );

    test('begins with the arrival and Chapter One', () {
      final entries = story(0);
      expect(entries.length, 2);
      expect(entries[0].kind, ChronicleKind.arrival);
      expect(entries[0].day, '2026-11-01');
      expect(entries[0].text, startsWith('You come over the last hill'));
      expect(entries[0].text, endsWith('One lantern still burns, at the gate.'));
      expect(entries[1].kind, ChronicleKind.chapterOpens);
      expect(entries[1].title, 'Chapter One · Hearthmere');
    });

    test('adds each place as it wakes, with who came home and when', () {
      final entries = story(2);
      expect(entries.length, 4);
      final well = entries.last;
      expect(well.kind, ChronicleKind.placeWakes);
      expect(well.title, 'The Village Well');
      expect(well.day, '2026-11-03');
      expect(
        well.text,
        'Clear water rises again, and Marla draws the first bucket. Marla '
        'the well-keeper has come home.',
      );
    });

    test('closes a chapter and opens the next on the same day', () {
      final entries = story(4);
      final kinds = entries.map((e) => e.kind).toList();
      expect(kinds.sublist(kinds.length - 3), <ChronicleKind>[
        ChronicleKind.placeWakes,
        ChronicleKind.chapterWakes,
        ChronicleKind.chapterOpens,
      ]);
      expect(entries[entries.length - 2].title, 'Hearthmere wakes');
      expect(entries.last.title, 'Chapter Two · Larkdown');
      expect(entries.last.day, '2026-11-05');
    });

    test('ends with the Vale awake, then the lanterns along the road', () {
      final whole = story(20);
      expect(whole.last.kind, ChronicleKind.chapterWakes);
      expect(whole.last.title, 'Old Lanternhall wakes');
      // Arrival, five openings, twenty places, five wakings.
      expect(whole.length, 1 + 5 + 20 + 5);

      final more = story(23);
      expect(more.last.kind, ChronicleKind.lanterns);
      expect(more.last.text, 'Three more lanterns have been lit along the road.');
      expect(story(21).last.text, 'One more lantern has been lit along the road.');
    });

    test('is told oldest first', () {
      final days = story(12)
          .map((e) => e.day)
          .whereType<String>()
          .toList();
      final sorted = List<String>.of(days)..sort();
      expect(days, sorted);
    });
  });
}
