/// How Dawn composes the board (Amendment v0.4 §§2, 5): habit plans due
/// today, today's mapped calendar, and a class pass that points existing
/// quests at the game. It never invents an obligation.
///
/// Pure rules: the repository and controller hand in plain facts.
library;

import 'classes.dart';
import 'combat.dart' show EnemyType, ItemKind;
import 'day_key.dart';
import 'enums.dart';
import 'first_dawn.dart';
import 'goals.dart';
import 'suggestions.dart';

// ---- The calendar -------------------------------------------------------

/// One calendar event, reduced to what the rules need.
class EventFact {
  const EventFact({
    required this.key,
    required this.calendarId,
    required this.title,
    required this.begin,
    required this.end,
    this.allDay = false,
    this.timeLabel = '',
  });

  /// The same for every copy of one occurrence (`CalendarEvent.sameAs`).
  final String key;
  final String calendarId;
  final String title;
  final DateTime begin;
  final DateTime end;
  final bool allDay;
  final String timeLabel;

  String get seriesKey => seriesKeyOf(calendarId, title);
}

int _fnv1a(String text) {
  var hash = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// What a recurring event is remembered by: its calendar and a hash of its
/// title's words. The title itself is never stored (Amendment v0.4 §3,
/// Chapter 6).
String seriesKeyOf(String calendarId, String title) =>
    '$calendarId:${_fnv1a(titleWords(title).join(' ')).toRadixString(16)}';

/// A recurring event found on the calendar, for the mapping pass.
class EventSeries {
  const EventSeries({
    required this.key,
    required this.title,
    required this.count,
    required this.when,
    required this.proposed,
  });
  final String key;
  final String title;

  /// How many times it comes round in the weeks looked at.
  final int count;

  /// e.g. `Tuesdays · 2:00 PM – 3:00 PM`, or `Most days`.
  final String when;
  final MappingKind proposed;
}

const Map<MappingKind, List<String>> _kindWords = <MappingKind, List<String>>{
  MappingKind.health: <String>[
    'gym', 'run', 'yoga', 'physio', 'doctor', 'dentist', 'clinic', 'swim',
    'workout', 'training', 'pilates', 'appointment', 'therapy', //
  ],
  MappingKind.craft: <String>[
    'paint', 'painting', 'craft', 'hobby', 'print', 'build', 'sketch',
    'workshop', 'sew', 'knit', 'woodwork', 'writing', //
  ],
  MappingKind.social: <String>[
    'dinner', 'lunch', 'coffee', 'party', 'game', 'games', 'visit', 'drinks',
    'birthday', 'club', 'league', 'date', //
  ],
  MappingKind.travel: <String>[
    'flight', 'train', 'drive', 'trip', 'travel', 'airport', 'ferry', 'sail',
    'sailing', //
  ],
};

/// The type proposed for a recurring event from the words of its title.
/// Anything unrecognised is a Commitment; the user confirms or changes it.
MappingKind proposeKind(String title) {
  final words = titleWords(title).toSet();
  for (final entry in _kindWords.entries) {
    if (entry.value.any(words.contains)) return entry.key;
  }
  return MappingKind.commitment;
}

/// The recurring events among [events]: any event that comes round twice
/// or more in the span looked at (four weeks), one entry for each, in
/// the order first met.
List<EventSeries> recurringSeries(List<EventFact> events) {
  final byKey = <String, List<EventFact>>{};
  final seenOccurrence = <String>{};
  for (final e in events) {
    // One event copied into two calendars is still one occurrence.
    if (!seenOccurrence.add('${e.seriesKey}|${e.key}')) continue;
    byKey.putIfAbsent(e.seriesKey, () => <EventFact>[]).add(e);
  }
  final out = <EventSeries>[];
  for (final entry in byKey.entries) {
    final list = entry.value;
    if (list.length < 2) continue;
    final days = <int>{for (final e in list) e.begin.weekday};
    final String dayWords;
    if (days.length >= 5) {
      dayWords = 'Most days';
    } else {
      final sorted = days.toList()..sort();
      dayWords = sorted.length == 1
          ? '${DayKey.weekdayLong[sorted.first - 1]}s'
          : sorted.map((d) => DayKey.weekdayShort[d - 1]).join(', ');
    }
    final first = list.first;
    out.add(
      EventSeries(
        key: entry.key,
        title: first.title,
        count: list.length,
        when: first.timeLabel.isEmpty
            ? dayWords
            : '$dayWords · ${first.timeLabel}',
        proposed: proposeKind(first.title),
      ),
    );
  }
  return out;
}

/// The habit plan a recurring event most likely *is*: one whose words
/// match the title, or the only plan of the attribute its type points at.
/// Null when there is no clear one. The user confirms it.
HabitPlan? planMatching(
  String title,
  MappingKind kind,
  List<HabitPlan> plans,
) {
  final byWords = planByWords(title, plans);
  if (byWords != null) return byWords;
  final live = <HabitPlan>[for (final p in plans) if (p.active) p];
  if (kind == MappingKind.commitment || kind == MappingKind.ignore) return null;
  final same = <HabitPlan>[
    for (final p in live)
      if (p.attribute == kind.attribute) p,
  ];
  return same.length == 1 ? same.first : null;
}

/// The habit plan whose own words match an event's title, or null. A
/// match by words is sure enough to be switched on for the user to see;
/// one by type alone is only offered.
HabitPlan? planByWords(String title, List<HabitPlan> plans) {
  for (final p in plans) {
    if (!p.active) continue;
    if (questMatching(title, <String>[p.target, p.tiny, p.stretch]) != null) {
      return p;
    }
  }
  return null;
}

/// What today's events become (Amendment v0.4 §2): a mapped event is a
/// quest; one that is a habit plan, or repeats a quest already on the
/// board, merges into it; an unmapped one is only ever a suggestion.
class CalendarToday {
  const CalendarToday({
    this.asQuests = const <EventFact>[],
    this.merged = const <String, EventFact>{},
    this.suggestions = const <EventFact>[],
  });

  /// Mapped events to put on the board as quests of their own.
  final List<EventFact> asQuests;

  /// Events that are a quest already there, by that quest's id.
  final Map<String, EventFact> merged;

  /// Events the user has said nothing about: offered, never added.
  final List<EventFact> suggestions;
}

CalendarToday planCalendar({
  required List<EventFact> events,
  required List<CalendarMapping> mappings,
  required List<HabitPlan> plans,

  /// Quests on today's board by id, with their names (plan quests under
  /// every size's words).
  required Map<String, List<String>> boardNames,
}) {
  final byKey = <String, CalendarMapping>{
    for (final m in mappings) m.seriesKey: m,
  };
  final planById = <String, HabitPlan>{for (final p in plans) p.id: p};
  final asQuests = <EventFact>[];
  final merged = <String, EventFact>{};
  final suggestions = <EventFact>[];
  final seen = <String>{};
  for (final e in events) {
    if (!seen.add(e.key)) continue;
    final mapping = byKey[e.seriesKey];
    if (mapping == null) {
      suggestions.add(e);
      continue;
    }
    if (mapping.kind == MappingKind.ignore) continue;
    final plan = planById[mapping.planId];
    final planQuest = plan != null && plan.active ? plan.questId : null;
    if (planQuest != null) {
      merged.putIfAbsent(planQuest, () => e);
      continue;
    }
    String? same;
    for (final entry in boardNames.entries) {
      if (questMatching(e.title, entry.value) != null) {
        same = entry.key;
        break;
      }
    }
    if (same != null) {
      merged.putIfAbsent(same, () => e);
    } else {
      asQuests.add(e);
    }
  }
  return CalendarToday(
    asQuests: asQuests,
    merged: merged,
    suggestions: suggestions,
  );
}

/// A Prep or Follow-through that may be offered for a heavy event
/// (Amendment v0.4 §5.3). An offer, never an addition.
class CalendarOffer {
  const CalendarOffer({required this.event, required this.prep});
  final EventFact event;

  /// True for a Prep quest before it, false for a Follow-through after.
  final bool prep;

  /// What remembers the user's answer for today.
  String get choiceKey => '${prep ? 'prep' : 'follow'}:${event.key}';

  String get questName => prep
      ? 'Lay out what you need for ${event.title}'
      : 'Note one thing from ${event.title}';
}

/// The offers open at [now]: a Prep for a heavy event still ahead, a
/// Follow-through for one that has begun. [settled] holds the choice keys
/// already answered today.
List<CalendarOffer> offersAt({
  required DateTime now,
  required List<EventFact> events,
  required List<CalendarMapping> mappings,
  required Set<String> settled,
}) {
  final byKey = <String, CalendarMapping>{
    for (final m in mappings) m.seriesKey: m,
  };
  final out = <CalendarOffer>[];
  final seen = <String>{};
  for (final e in events) {
    if (!seen.add(e.key)) continue;
    final m = byKey[e.seriesKey];
    if (m == null || !m.heavy || m.kind == MappingKind.ignore) continue;
    final ahead = now.isBefore(e.begin);
    final offer = CalendarOffer(event: e, prep: ahead);
    if (ahead ? m.prepOff : m.followOff) continue;
    if (settled.contains(offer.choiceKey)) continue;
    out.add(offer);
  }
  return out;
}

// ---- The board ----------------------------------------------------------

/// A quest on today's board, reduced to what the rules need.
class QuestFact {
  const QuestFact({
    required this.id,
    required this.name,
    required this.source,
    required this.attribute,
    required this.track,
    required this.difficulty,
    this.systemKey,
    this.goalId,
    this.planId,
    this.done = false,
  });
  final String id;
  final String name;
  final QuestSource source;
  final Attribute attribute;
  final Track track;
  final Difficulty difficulty;
  final String? systemKey;
  final String? goalId;
  final String? planId;
  final bool done;
}

/// What the board shows for one quest beyond the quest itself.
class BoardLine {
  const BoardLine({
    required this.kind,
    required this.forLine,
    required this.title,
    this.plan,
    this.goal,
    this.size,
    this.feeds,
  });

  final SourceKind kind;

  /// "For: …": what put this quest here.
  final String forLine;

  /// The words on the card: for a habit plan, the words of [size].
  final String title;
  final HabitPlan? plan;
  final Goal? goal;

  /// The size shown before the user picks one. Null unless it is a habit
  /// plan's quest.
  final QuestSize? size;

  /// "Feeds Guard": set on at most one quest a day (Amendment v0.4 §5.1).
  final String? feeds;

  /// What completing at [chosen] is worth.
  Difficulty difficultyAt(QuestSize chosen, Difficulty fallback) =>
      plan?.difficultyFor(chosen) ?? fallback;

  /// The words on the card at [chosen], at week one's calibration.
  String titleAt(QuestSize chosen, {int calibration = 100}) {
    final p = plan;
    if (p == null) return title;
    return chosen == QuestSize.target
        ? targetTextOn(p, calibration)
        : p.textFor(chosen);
  }
}

/// Today's board as Dawn composes it.
class ComposedBoard {
  const ComposedBoard({required this.order, required this.lines});

  /// Quest ids in the order to show them. A quest missing from here stays
  /// off the board today (a heavy habit on a rest day).
  final List<String> order;
  final Map<String, BoardLine> lines;
}

int _windowRank(DayWindow window, DayWindow peak) => switch (window) {
      DayWindow.morning => 0,
      DayWindow.afternoon => 1,
      DayWindow.evening => 2,
      // Something with no time of its own sits where energy peaks.
      DayWindow.anytime => peak == DayWindow.anytime ? 1 : _windowRank(peak, peak),
    };

/// Composes today's board from the quests due.
///
/// - every quest gets its For-line and source;
/// - a habit plan's quest gets its default size (Tiny in a Tiny-only first
///   week and on a rest day);
/// - on a rest day a heavy habit stays off unless it is already done or
///   the calendar put it there;
/// - habit quests are ordered by the part of the day they attach to, and
///   no two heavy ones sit next to each other when that can be avoided;
/// - if nothing done today feeds the class resource and the encounter is
///   open, the one open quest that feeds it best is marked.
ComposedBoard composeBoard({
  required String day,
  required List<QuestFact> quests,
  required List<Goal> goals,
  required List<HabitPlan> plans,
  required Rhythm rhythm,
  Map<String, EventFact> merged = const <String, EventFact>{},
  Map<String, String> calendarTimes = const <String, String>{},
  HeroClass? heroClass,
  bool encounterOpen = false,
}) {
  final goalById = <String, Goal>{for (final g in goals) g.id: g};
  final planById = <String, HabitPlan>{for (final p in plans) p.id: p};
  final restDay = rhythm.isRestDay(day);
  final calibration = rhythm.calibrationOn(day);

  final lines = <String, BoardLine>{};
  final shown = <QuestFact>[];
  for (final q in quests) {
    final plan = planById[q.planId];
    final event = merged[q.id];
    if (plan != null && plan.heavy && restDay && !q.done && event == null) {
      continue;
    }
    final kind = sourceKindOf(
      source: q.source,
      systemKey: q.systemKey,
      goalId: q.goalId,
      planId: q.planId,
    );
    final goal = goalById[plan?.goalId ?? q.goalId];
    final size = plan?.defaultSize(day, restDay: restDay);
    final time = event?.timeLabel ?? calendarTimes[q.id] ?? '';
    final String title;
    if (plan == null) {
      title = q.name;
    } else if (size == QuestSize.target) {
      title = targetTextOn(plan, calibration);
    } else {
      title = plan.textFor(size!);
    }
    lines[q.id] = BoardLine(
      kind: kind,
      forLine: forLine(
        kind: kind,
        goal: goal,
        anchor: plan?.anchor ?? '',
        calendarTime: time,
        systemKey: q.systemKey ?? '',
      ),
      title: title,
      plan: plan,
      goal: goal,
      size: size,
    );
    shown.add(q);
  }

  // Order: quests that are not habit plans keep their place; habit quests
  // are sorted among themselves by window, then spread so that two heavy
  // ones are not side by side.
  final habit = <QuestFact>[
    for (final q in shown)
      if (planById[q.planId] != null) q,
  ];
  final rank = <String, int>{
    for (var i = 0; i < habit.length; i++)
      habit[i].id:
          _windowRank(planById[habit[i].planId]!.window, rhythm.peak) * 100 + i,
  };
  habit.sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
  bool heavyAt(int i) => planById[habit[i].planId]!.heavy;
  for (var i = 1; i < habit.length; i++) {
    if (!(heavyAt(i) && heavyAt(i - 1))) continue;
    for (var j = i + 1; j < habit.length; j++) {
      if (!heavyAt(j)) {
        final lighter = habit.removeAt(j);
        habit.insert(i, lighter);
        break;
      }
    }
  }
  final order = <String>[];
  var next = 0;
  for (final q in shown) {
    if (planById[q.planId] != null) {
      order.add(habit[next++].id);
    } else {
      order.add(q.id);
    }
  }

  // The class pass: a highlight, never an addition.
  final cls = heroClass;
  if (cls != null && encounterOpen) {
    final fedInFull = shown.any(
      (q) => q.done && feedsInFull(cls, q.attribute, q.track),
    );
    if (!fedInFull) {
      QuestFact? best;
      var bestGain = 0;
      for (final q in shown) {
        if (q.done) continue;
        final line = lines[q.id]!;
        final worth = line.size == null
            ? q.difficulty
            : line.difficultyAt(line.size!, q.difficulty);
        final gain = resourceFrom(cls, q.attribute, q.track, worth) +
            (feedsInFull(cls, q.attribute, q.track) ? 10 : 0);
        if (gain > bestGain) {
          best = q;
          bestGain = gain;
        }
      }
      if (best != null && bestGain > 10) {
        final line = lines[best.id]!;
        lines[best.id] = BoardLine(
          kind: line.kind,
          forLine: line.forLine,
          title: line.title,
          plan: line.plan,
          goal: line.goal,
          size: line.size,
          feeds: 'Feeds ${cls.resource}',
        );
      }
    }
  }
  return ComposedBoard(order: order, lines: lines);
}

/// What the scout says about today's board (Amendment v0.4 §5.1, §5.2):
/// existing life pointed at the game. Null when there is nothing to say.
String? boardHint({
  required HeroClass cls,
  required EnemyType type,
  required List<QuestFact> quests,
  required Map<String, BoardLine> lines,
  Map<ItemKind, int> pouch = const <ItemKind, int>{},
}) {
  final open = <QuestFact>[
    for (final q in quests)
      if (!q.done && lines.containsKey(q.id)) q,
  ];
  String nameOf(QuestFact q) => lines[q.id]?.title ?? q.name;
  final timeOf = RegExp(r'on your calendar (.+)$');
  String withTime(QuestFact q) {
    final m = timeOf.firstMatch(lines[q.id]?.forLine ?? '');
    return m == null ? nameOf(q) : '${nameOf(q)} (${m.group(1)})';
  }

  if (cls == HeroClass.artificer) {
    for (final q in open) {
      if (q.attribute == Attribute.craft) {
        final handy = type == EnemyType.armoured
            ? ' A Trap breaks an Armoured hide.'
            : '';
        return 'Your ${withTime(q)} stocks the pouch before you go in.$handy';
      }
    }
  }
  for (final q in open) {
    if (feedsInFull(cls, q.attribute, q.track)) {
      return 'Your ${withTime(q)} feeds ${cls.resource}: worth doing before '
          'you go in.';
    }
  }
  final fed = quests.any(
    (q) => q.done && feedsInFull(cls, q.attribute, q.track),
  );
  if (fed) return null;
  return 'Nothing on today’s board feeds ${cls.resource} in full. You go in '
      'on what any quest gives, and that is enough to win.';
}

// ---- The first week, for Chapter 7 --------------------------------------

class WeekEntry {
  const WeekEntry({
    required this.goal,
    required this.plan,
    required this.text,
    required this.forLine,
    required this.size,
    required this.heavy,
  });

  /// Indexes into the draft's goals, and that goal's plans.
  final int goal;
  final int plan;
  final String text;
  final String forLine;
  final QuestSize size;
  final bool heavy;
}

/// The seven days from [startDay] as the designed habits would fill them:
/// the same rules as the board itself.
List<(String, List<WeekEntry>)> weekPreview(
  FirstDawnDraft d, {
  required String startDay,
}) {
  final rhythm = d.rhythm(startDay: startDay);
  final out = <(String, List<WeekEntry>)>[];
  for (var offset = 0; offset < 7; offset++) {
    final day = DayKey.addDays(startDay, offset);
    final restDay = rhythm.isRestDay(day);
    final entries = <WeekEntry>[];
    for (var g = 0; g < d.goals.length; g++) {
      final gd = d.goals[g];
      final goal = Goal(id: 'g$g', domain: gd.domain, text: gd.title);
      for (var p = 0; p < gd.plans.length; p++) {
        final pd = gd.plans[p];
        if (pd.isEmpty || pd.dropped) continue;
        final plan = planFrom(pd, goal, id: 'p$g.$p', startDay: startDay);
        if (!plan.schedule.isDueOn(day)) continue;
        if (plan.heavy && restDay) continue;
        final size = plan.defaultSize(day, restDay: restDay);
        entries.add(
          WeekEntry(
            goal: g,
            plan: p,
            text: size == QuestSize.target
                ? targetTextOn(plan, rhythm.calibrationOn(day))
                : plan.textFor(size),
            forLine: forLine(
              kind: SourceKind.habit,
              goal: goal,
              anchor: plan.anchor,
            ),
            size: size,
            heavy: plan.heavy,
          ),
        );
      }
    }
    out.add((day, entries));
  }
  return out;
}
