import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/suggestions.dart';

// Calendar suggestions: one event offered once, and an event that repeats a
// quest already on the board recognised as such (DESIGN §9.3).

void main() {
  const seeds = <String>[
    'Morning Health Check',
    '7,000 Steps',
    'Painting / Craft Block',
    'Weekly Injection (Mounjaro)',
    'Walk Babs',
    'Play / Train with Babs',
    'Campfire Review',
  ];

  group('The same event in two calendars', () {
    final begin = DateTime(2026, 11, 14, 10, 30);
    final end = DateTime(2026, 11, 14, 11, 15);

    String key(String title, {DateTime? from, DateTime? to, bool allDay = false}) =>
        eventKey(title: title, begin: from ?? begin, end: to ?? end, allDay: allDay);

    test('same title and times make one event, however it is typed', () {
      expect(key('Dentist'), key('dentist '));
      expect(key('Covid and Flu Shots'), key('COVID and flu shots'));
      expect(key('Team lunch'), key('Team  Lunch!'));
    });

    test('a different time is a different event', () {
      expect(
        key('Dentist'),
        isNot(key('Dentist', from: begin.add(const Duration(hours: 3)))),
      );
      expect(
        key('Dentist'),
        isNot(key('Dentist', to: end.add(const Duration(minutes: 15)))),
      );
      expect(key('Dentist'), isNot(key('Dentist', allDay: true)));
    });

    test('a different title is a different event', () {
      expect(key('Dentist'), isNot(key('Dentist follow-up')));
    });
  });

  group('An event that repeats a quest on the board', () {
    test('one word of the quest is enough when it is a telling one', () {
      expect(questMatching('Mounjaro', seeds), 'Weekly Injection (Mounjaro)');
      expect(questMatching('Craft block', seeds), 'Painting / Craft Block');
    });

    test('small words and punctuation are looked past', () {
      expect(questMatching('Walk with Babs', seeds), 'Walk Babs');
      expect(questMatching('walk babs!', seeds), 'Walk Babs');
    });

    test('the quest can be the shorter of the two', () {
      expect(
        questMatching('Evening walk, Babs and the kids', seeds),
        'Walk Babs',
      );
    });

    test('an event about something else matches nothing', () {
      expect(questMatching('Covid and Flu Shots', seeds), isNull);
      expect(questMatching('Dentist', seeds), isNull);
      expect(questMatching('Lunch with Sam', seeds), isNull);
      // Sharing one word is not enough when each has words of its own.
      expect(questMatching('Health and safety training', seeds), isNull);
    });

    test('a title with nothing telling in it matches nothing', () {
      expect(questMatching('', seeds), isNull);
      expect(questMatching('To do', seeds), isNull);
      expect(questMatching('Go', const <String>['Go to bed']), isNull);
    });

    test('accents and other alphabets are words too', () {
      expect(titleWords('Café — Zoë'), <String>['café', 'zoë']);
      expect(questMatching('Séance photo', const <String>['Séance photo']),
          'Séance photo');
    });
  });
}
