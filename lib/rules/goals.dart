/// Goals, habit plans and what a quest is for (Amendment v0.4 §§1, 2, 4, 8).
///
/// Pure rules and plain data. A goal is something the user stated; a habit
/// plan is the repeatable thing that serves it; a quest on the board is
/// that plan on a given day. Nothing here invents an obligation: every
/// function composes from what the user said.
library;

import 'dart:convert';

import 'day_key.dart';
import 'enums.dart';
import 'schedule.dart';

/// The seven parts of life First Dawn offers (Chapter 1).
enum LifeDomain {
  body('Body & Health', 'sprig', Attribute.vitality),
  making('Making & Craft', 'brush', Attribute.craft),
  mind('Mind & Learning', 'book', Attribute.mind),
  home('Home & Family', 'home', Attribute.care),
  adventure('Adventure & Outdoors', 'compass', Attribute.adventure),
  work('Work & Order', 'scroll', Attribute.order),
  community('Friendship & Community', 'people', Attribute.care);

  const LifeDomain(this.label, this.icon, this.attribute);
  final String label;
  final String icon;
  final Attribute attribute;

  static LifeDomain byName(String? name) => LifeDomain.values.firstWhere(
        (d) => d.name == name,
        orElse: () => LifeDomain.body,
      );
}

/// How far off a goal sits (Chapter 2).
enum Horizon {
  month('This month'),
  season('This season'),
  ongoing('Ongoing');

  const Horizon(this.label);
  final String label;

  static Horizon byName(String? name) => Horizon.values.firstWhere(
        (h) => h.name == name,
        orElse: () => Horizon.ongoing,
      );
}

/// How a habit feels before it is done (Chapter 3, the dread check).
enum Dread {
  easy('Easy'),
  fine('Fine'),
  heavy('Heavy');

  const Dread(this.label);
  final String label;

  static Dread byName(String? name) => Dread.values.firstWhere(
        (d) => d.name == name,
        orElse: () => Dread.fine,
      );
}

/// How often a habit plan comes round.
enum PlanFrequency {
  daily('Every day'),
  weekdays('Weekdays'),
  days('Chosen days'),
  weekly('Once a week');

  const PlanFrequency(this.label);
  final String label;

  static PlanFrequency byName(String? name) => PlanFrequency.values.firstWhere(
        (f) => f.name == name,
        orElse: () => PlanFrequency.daily,
      );
}

/// The part of the day a habit sits in. Used only to order the board.
enum DayWindow {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening'),
  anytime('Any time');

  const DayWindow(this.label);
  final String label;

  static DayWindow byName(String? name) => DayWindow.values.firstWhere(
        (w) => w.name == name,
        orElse: () => DayWindow.anytime,
      );
}

/// The three sizes of a habit-plan quest (Amendment v0.4 §4). Tiny is a
/// designed size: it counts in full.
enum QuestSize {
  tiny('Tiny', Difficulty.minor),
  target('Target', Difficulty.standard),
  stretch('Stretch', Difficulty.heroic);

  const QuestSize(this.label, this.difficulty);
  final String label;
  final Difficulty difficulty;

  QuestSize get next => QuestSize.values[(index + 1) % QuestSize.values.length];

  static QuestSize? byName(String? name) {
    for (final s in QuestSize.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// What a quest was made from (Amendment v0.4 §8). [own] is a quest the
/// user made or kept by hand and has not pinned to a goal.
enum SourceKind {
  habit,
  calendar,
  prep,
  followThrough,
  encounter,
  system,
  own;

  /// The name used in the exported files.
  String get exportName => switch (this) {
        SourceKind.followThrough => 'follow-through',
        _ => name,
      };
}

/// What a recurring calendar event is (Chapter 6, the mapping pass).
enum MappingKind {
  commitment('Commitment', Attribute.order),
  health('Health', Attribute.vitality),
  craft('Craft block', Attribute.craft),
  social('Social', Attribute.care),
  travel('Travel', Attribute.adventure),
  ignore('Ignore', Attribute.order);

  const MappingKind(this.label, this.attribute);
  final String label;
  final Attribute attribute;

  static MappingKind byName(String? name) => MappingKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => MappingKind.commitment,
      );
}

/// Something the user stated they want (Amendment v0.4 §2).
class Goal {
  const Goal({
    required this.id,
    required this.domain,
    required this.text,
    this.why = '',
    this.horizon = Horizon.ongoing,
    this.check = '',
    this.active = true,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: '${j['id']}',
        domain: LifeDomain.byName(j['domain'] as String?),
        text: '${j['text'] ?? ''}',
        why: '${j['why'] ?? ''}',
        horizon: Horizon.byName(j['horizon'] as String?),
        check: '${j['check'] ?? ''}',
        active: j['active'] != false,
      );

  final String id;
  final LifeDomain domain;

  /// The goal, in the user's words.
  final String text;

  /// "What would better look like?", verbatim.
  final String why;
  final Horizon horizon;

  /// "How will you know it's working?"
  final String check;
  final bool active;

  Goal copyWith({String? text, String? why, Horizon? horizon, bool? active}) =>
      Goal(
        id: id,
        domain: domain,
        text: text ?? this.text,
        why: why ?? this.why,
        horizon: horizon ?? this.horizon,
        check: check,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'domain': domain.name,
        'text': text,
        'why': why,
        'horizon': horizon.name,
        'check': check,
        'active': active,
      };
}

/// The repeatable thing that serves a goal (Amendment v0.4 §2), in three
/// sizes (§4).
class HabitPlan {
  const HabitPlan({
    required this.id,
    required this.goalId,
    required this.target,
    required this.tiny,
    required this.stretch,
    required this.attribute,
    this.anchor = '',
    this.window = DayWindow.anytime,
    this.frequency = PlanFrequency.daily,
    this.weekdays = const <int>{},
    this.track = Track.hero,
    this.dread = Dread.fine,
    this.minutes,
    this.tinyUntil,
    this.questId,
    this.active = true,
  });

  factory HabitPlan.fromJson(Map<String, dynamic> j) => HabitPlan(
        id: '${j['id']}',
        goalId: '${j['goalId'] ?? ''}',
        target: '${j['target'] ?? ''}',
        tiny: '${j['tiny'] ?? ''}',
        stretch: '${j['stretch'] ?? ''}',
        attribute: Attribute.values.firstWhere(
          (a) => a.name == j['attribute'],
          orElse: () => Attribute.order,
        ),
        anchor: '${j['anchor'] ?? ''}',
        window: DayWindow.byName(j['window'] as String?),
        frequency: PlanFrequency.byName(j['frequency'] as String?),
        weekdays: <int>{
          for (final d in (j['weekdays'] as List<dynamic>? ?? const <dynamic>[]))
            if (d is int && d >= 1 && d <= 7) d,
        },
        track: Track.values.firstWhere(
          (t) => t.name == j['track'],
          orElse: () => Track.hero,
        ),
        dread: Dread.byName(j['dread'] as String?),
        minutes: j['minutes'] as int?,
        tinyUntil: j['tinyUntil'] as String?,
        questId: j['questId'] as String?,
        active: j['active'] != false,
      );

  final String id;
  final String goalId;

  /// The habit as designed, in the user's words. This is what the board
  /// shows by default.
  final String target;

  /// The smallest version that still keeps the thread.
  final String tiny;

  /// The sprint version.
  final String stretch;
  final Attribute attribute;

  /// The moment in the day it attaches to ("after coffee").
  final String anchor;
  final DayWindow window;
  final PlanFrequency frequency;

  /// ISO weekdays (1 Monday to 7 Sunday) for [PlanFrequency.days] and
  /// [PlanFrequency.weekly].
  final Set<int> weekdays;
  final Track track;
  final Dread dread;

  /// The Target's length when it is a timed habit, or null.
  final int? minutes;

  /// Tiny is the size shown until the end of this day (the first-week
  /// review's "Tiny only this week"), or null.
  final String? tinyUntil;

  /// The quest row that puts this plan on the board.
  final String? questId;
  final bool active;

  bool get heavy => dread == Dread.heavy;

  /// The words for one size.
  String textFor(QuestSize size) => switch (size) {
        QuestSize.tiny => tiny,
        QuestSize.target => target,
        QuestSize.stretch => stretch,
      };

  /// What a size is worth. A habit that feels heavy carries Heroic weight
  /// at its Target (Chapter 3, the dread check).
  Difficulty difficultyFor(QuestSize size) {
    if (size == QuestSize.target && heavy) return Difficulty.heroic;
    return size.difficulty;
  }

  /// The size the board shows before the user picks one.
  QuestSize defaultSize(String day, {bool restDay = false}) {
    final until = tinyUntil;
    if (restDay) return QuestSize.tiny;
    if (until != null && DayKey.daysBetween(day, until) >= 0) {
      return QuestSize.tiny;
    }
    return QuestSize.target;
  }

  Schedule get schedule => switch (frequency) {
        PlanFrequency.daily => const Schedule.daily(),
        PlanFrequency.weekdays => const Schedule.workdays(),
        PlanFrequency.days || PlanFrequency.weekly => weekdays.isEmpty
            ? const Schedule.daily()
            : Schedule.onWeekdays(weekdays),
      };

  /// e.g. `Every day`, `Mon, Wed, Fri`, `Saturdays`.
  String get frequencyLabel {
    switch (frequency) {
      case PlanFrequency.daily:
        return 'Every day';
      case PlanFrequency.weekdays:
        return 'Weekdays';
      case PlanFrequency.days:
      case PlanFrequency.weekly:
        if (weekdays.isEmpty) return 'Every day';
        final sorted = weekdays.toList()..sort();
        if (sorted.length == 1) {
          return '${DayKey.weekdayLong[sorted.first - 1]}s';
        }
        return sorted.map((d) => DayKey.weekdayShort[d - 1]).join(', ');
    }
  }

  HabitPlan copyWith({
    String? goalId,
    String? target,
    String? tiny,
    String? stretch,
    String? anchor,
    DayWindow? window,
    PlanFrequency? frequency,
    Set<int>? weekdays,
    Track? track,
    Dread? dread,
    int? minutes,
    bool clearMinutes = false,
    String? tinyUntil,
    bool clearTinyUntil = false,
    String? questId,
    bool? active,
  }) =>
      HabitPlan(
        id: id,
        goalId: goalId ?? this.goalId,
        target: target ?? this.target,
        tiny: tiny ?? this.tiny,
        stretch: stretch ?? this.stretch,
        attribute: attribute,
        anchor: anchor ?? this.anchor,
        window: window ?? this.window,
        frequency: frequency ?? this.frequency,
        weekdays: weekdays ?? this.weekdays,
        track: track ?? this.track,
        dread: dread ?? this.dread,
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        tinyUntil: clearTinyUntil ? null : (tinyUntil ?? this.tinyUntil),
        questId: questId ?? this.questId,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goalId': goalId,
        'target': target,
        'tiny': tiny,
        'stretch': stretch,
        'attribute': attribute.name,
        'anchor': anchor,
        'window': window.name,
        'frequency': frequency.name,
        'weekdays': weekdays.toList()..sort(),
        'track': track.name,
        'dread': dread.name,
        if (minutes != null) 'minutes': minutes,
        if (tinyUntil != null) 'tinyUntil': tinyUntil,
        if (questId != null) 'questId': questId,
        'active': active,
      };
}

/// The rhythm answers of Chapter 4, and the first week's calibration.
class Rhythm {
  const Rhythm({
    this.wake = '',
    this.sleep = '',
    this.work = '',
    this.peak = DayWindow.anytime,
    this.restDays = const <int>{},
    this.sprints = false,
    this.calibration = 100,
    this.weekOneEnds,
  });

  factory Rhythm.fromJson(Map<String, dynamic> j) => Rhythm(
        wake: '${j['wake'] ?? ''}',
        sleep: '${j['sleep'] ?? ''}',
        work: '${j['work'] ?? ''}',
        peak: DayWindow.byName(j['peak'] as String?),
        restDays: <int>{
          for (final d in (j['restDays'] as List<dynamic>? ?? const <dynamic>[]))
            if (d is int && d >= 1 && d <= 7) d,
        },
        sprints: j['sprints'] == true,
        calibration: (j['calibration'] as int?) ?? 100,
        weekOneEnds: j['weekOneEnds'] as String?,
      );

  /// Rough windows, as chosen ("6 to 8", "After midnight").
  final String wake;
  final String sleep;

  /// Weekdays, shifts, irregular or none.
  final String work;

  /// When energy peaks. Used only to order the board.
  final DayWindow peak;

  /// Days the board runs light on purpose.
  final Set<int> restDays;

  /// Works in sprints and quiet stretches rather than steadily.
  final bool sprints;

  /// Week one's volume, as a percentage of the timed Targets: 75, 100 or
  /// 125 (Chapter 7).
  final int calibration;

  /// The last day the calibration applies to.
  final String? weekOneEnds;

  bool isRestDay(String day) => restDays.contains(DayKey.weekday(day));

  /// The calibration in force on [day]: 100 once week one is over.
  int calibrationOn(String day) {
    final ends = weekOneEnds;
    if (ends == null || DayKey.daysBetween(day, ends) < 0) return 100;
    return calibration;
  }

  Rhythm copyWith({int? calibration, String? weekOneEnds}) => Rhythm(
        wake: wake,
        sleep: sleep,
        work: work,
        peak: peak,
        restDays: restDays,
        sprints: sprints,
        calibration: calibration ?? this.calibration,
        weekOneEnds: weekOneEnds ?? this.weekOneEnds,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wake': wake,
        'sleep': sleep,
        'work': work,
        'peak': peak.name,
        'restDays': restDays.toList()..sort(),
        'sprints': sprints,
        'calibration': calibration,
        if (weekOneEnds != null) 'weekOneEnds': weekOneEnds,
      };
}

/// What the user decided a recurring calendar event is (Chapter 6). The
/// event's title is never kept: [seriesKey] is the calendar and a hash.
class CalendarMapping {
  const CalendarMapping({
    required this.seriesKey,
    required this.kind,
    this.planId,
    this.heavy = false,
    this.prepOff = false,
    this.followOff = false,
  });

  factory CalendarMapping.fromJson(Map<String, dynamic> j) => CalendarMapping(
        seriesKey: '${j['key']}',
        kind: MappingKind.byName(j['kind'] as String?),
        planId: j['planId'] as String?,
        heavy: j['heavy'] == true,
        prepOff: j['prepOff'] == true,
        followOff: j['followOff'] == true,
      );

  final String seriesKey;
  final MappingKind kind;

  /// The habit plan this event is, when it is one: they make one quest.
  final String? planId;

  /// Takes something out of the user: Dawn may offer a Prep quest and the
  /// Campfire a Follow-through (Amendment v0.4 §5.3).
  final bool heavy;

  /// "Never for this one": the offers, each dismissed for good.
  final bool prepOff;
  final bool followOff;

  CalendarMapping copyWith({
    MappingKind? kind,
    String? planId,
    bool clearPlan = false,
    bool? heavy,
    bool? prepOff,
    bool? followOff,
  }) =>
      CalendarMapping(
        seriesKey: seriesKey,
        kind: kind ?? this.kind,
        planId: clearPlan ? null : (planId ?? this.planId),
        heavy: heavy ?? this.heavy,
        prepOff: prepOff ?? this.prepOff,
        followOff: followOff ?? this.followOff,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': seriesKey,
        'kind': kind.name,
        if (planId != null) 'planId': planId,
        if (heavy) 'heavy': true,
        if (prepOff) 'prepOff': true,
        if (followOff) 'followOff': true,
      };
}

// ---- Encoding lists for the settings table -----------------------------

List<T> _decodeList<T>(String? source, T Function(Map<String, dynamic>) make) {
  if (source == null || source.isEmpty) return <T>[];
  try {
    final raw = jsonDecode(source);
    if (raw is! List) return <T>[];
    return <T>[
      for (final item in raw)
        if (item is Map<String, dynamic>) make(item),
    ];
  } on FormatException {
    return <T>[];
  }
}

List<Goal> decodeGoals(String? source) => _decodeList(source, Goal.fromJson);
String encodeGoals(Iterable<Goal> goals) =>
    jsonEncode(<Map<String, dynamic>>[for (final g in goals) g.toJson()]);

List<HabitPlan> decodePlans(String? source) =>
    _decodeList(source, HabitPlan.fromJson);
String encodePlans(Iterable<HabitPlan> plans) =>
    jsonEncode(<Map<String, dynamic>>[for (final p in plans) p.toJson()]);

List<CalendarMapping> decodeMappings(String? source) =>
    _decodeList(source, CalendarMapping.fromJson);
String encodeMappings(Iterable<CalendarMapping> mappings) =>
    jsonEncode(<Map<String, dynamic>>[for (final m in mappings) m.toJson()]);

Rhythm decodeRhythm(String? source) {
  if (source == null || source.isEmpty) return const Rhythm();
  try {
    final raw = jsonDecode(source);
    return raw is Map<String, dynamic> ? Rhythm.fromJson(raw) : const Rhythm();
  } on FormatException {
    return const Rhythm();
  }
}

// ---- Sizing a habit (Amendment v0.4 §4) --------------------------------

/// The three sizes proposed for a habit, for the user to edit.
class SizeProposal {
  const SizeProposal({
    required this.tiny,
    required this.target,
    required this.stretch,
    this.minutes,
  });
  final String tiny;
  final String target;
  final String stretch;
  final int? minutes;
}

final RegExp _minutesIn = RegExp(
  r'(\d{1,3})\s*(?:-\s*)?(minutes|minute|mins|min)\b',
  caseSensitive: false,
);

/// The minutes a habit names ("Paint for 30 minutes" is 30), or null.
int? minutesIn(String text) {
  final m = _minutesIn.firstMatch(text);
  if (m == null) return null;
  final n = int.tryParse(m.group(1)!);
  return (n == null || n <= 0) ? null : n;
}

int _roundToFive(num value) {
  final r = ((value + 2.5) ~/ 5) * 5;
  return r < 5 ? 5 : r;
}

/// The Tiny length for a Target of [minutes]: about two minutes for a
/// short habit, never more than ten.
int tinyMinutes(int minutes) =>
    minutes <= 10 ? 2 : (minutes <= 30 ? 5 : 10);

/// The Stretch length for a Target of [minutes]: half as long again.
int stretchMinutes(int minutes) => _roundToFive(minutes * 1.5);

/// [text] with its named minutes changed from whatever it says to [to].
/// A habit that names no minutes comes back as it was.
String withMinutes(String text, int to) {
  final m = _minutesIn.firstMatch(text);
  if (m == null) return text;
  final unit = to == 1 ? 'minute' : 'minutes';
  final short = m.group(2)!.toLowerCase().startsWith('min') &&
      !m.group(2)!.toLowerCase().startsWith('minute');
  return text.replaceRange(m.start, m.end, '$to ${short ? 'min' : unit}');
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

/// Tiny and Stretch versions of a stated habit. With minutes in it, the
/// minutes are scaled; without, the words say "just start" and "keep
/// going". The user edits either before it becomes a plan.
SizeProposal proposeSizes(String habit) {
  final target = habit.trim();
  final minutes = minutesIn(target);
  if (minutes != null) {
    return SizeProposal(
      tiny: withMinutes(target, tinyMinutes(minutes)),
      target: target,
      stretch: withMinutes(target, stretchMinutes(minutes)),
      minutes: minutes,
    );
  }
  return SizeProposal(
    tiny: 'Just start: two minutes of ${_lowerFirst(target)}',
    target: target,
    stretch: '$target, and keep going a while longer',
  );
}

/// The Target as week one shows it: a timed habit runs at the first
/// week's calibration (Chapter 7); anything else is unchanged.
String targetTextOn(HabitPlan plan, int calibration) {
  final minutes = plan.minutes;
  if (minutes == null || calibration == 100) return plan.target;
  return withMinutes(plan.target, _roundToFive(minutes * calibration / 100));
}

// ---- Where a habit sits (Chapter 3) -------------------------------------

/// The anchors offered as chips, with the part of the day each sits in.
const Map<String, DayWindow> commonAnchors = <String, DayWindow>{
  'When I wake up': DayWindow.morning,
  'After coffee or breakfast': DayWindow.morning,
  'At lunch': DayWindow.afternoon,
  'After work': DayWindow.evening,
  'After dinner': DayWindow.evening,
  'Before bed': DayWindow.evening,
};

/// The part of the day an anchor in the user's own words points at.
DayWindow windowOfAnchor(String anchor) {
  final known = commonAnchors[anchor];
  if (known != null) return known;
  final a = anchor.toLowerCase();
  bool has(String word) => a.contains(word);
  if (has('morning') || has('wake') || has('breakfast') || has('coffee')) {
    return DayWindow.morning;
  }
  if (has('lunch') || has('afternoon') || has('noon')) {
    return DayWindow.afternoon;
  }
  if (has('dinner') ||
      has('supper') ||
      has('evening') ||
      has('bed') ||
      has('night') ||
      has('after work')) {
    return DayWindow.evening;
  }
  return DayWindow.anytime;
}

const List<String> _companionWords = <String>[
  'feed', 'groom', 'brush', 'water bowl', 'litter', 'treat', 'vet', //
];
const List<String> _sharedWords = <String>[
  'walk', 'hike', 'play', 'fetch', 'run with', 'outing', 'park', //
];

/// The track offered for a habit (DESIGN §7A.2): care for the companion
/// goes to the Companion track, things done together are Shared, and
/// everything else is the hero's. The user confirms or moves it.
Track suggestTrack(String habit, {String companionName = ''}) {
  final h = habit.toLowerCase();
  final named = companionName.trim().isNotEmpty &&
      h.contains(companionName.trim().toLowerCase());
  final petWord = RegExp(r'\b(dog|cat|pet|pup|puppy|kitten|hound)\b').hasMatch(h);
  if (!named && !petWord) return Track.hero;
  if (_sharedWords.any(h.contains)) return Track.shared;
  if (_companionWords.any(h.contains)) return Track.companion;
  return Track.shared;
}

/// The one line that explains a track (DESIGN §7A.2).
String trackLine(Track track, String companionName) => switch (track) {
      Track.hero => 'Your own quest. Its XP is yours.',
      Track.companion =>
        'A small act of care. Its XP goes to $companionName, and you gain Bond.',
      Track.shared =>
        'Something you do together. You both gain XP, and a Pace on the road.',
    };

// ---- What a quest is for (Amendment v0.4 §1) ----------------------------

/// The generic words that stand in for a calendar event's title wherever
/// the title must not be written (Amendment v0.4 §8).
String calendarStandIn(SourceKind kind) => switch (kind) {
      SourceKind.prep => 'Prep for a calendar commitment',
      SourceKind.followThrough => 'Follow-through on a calendar commitment',
      _ => 'Calendar commitment',
    };

/// What kind of thing put a quest on the board.
SourceKind sourceKindOf({
  required QuestSource source,
  required String? systemKey,
  required String? goalId,
  required String? planId,
}) {
  if (planId != null || goalId != null) return SourceKind.habit;
  return switch (source) {
    QuestSource.habit => SourceKind.habit,
    QuestSource.calendar => SourceKind.calendar,
    QuestSource.prep => SourceKind.prep,
    QuestSource.followThrough => SourceKind.followThrough,
    QuestSource.system => SourceKind.system,
    QuestSource.manual ||
    QuestSource.recurring ||
    QuestSource.health =>
      SourceKind.own,
  };
}

/// The short line on every quest card saying what it is for. It never
/// carries a calendar event's title.
String forLine({
  required SourceKind kind,
  Goal? goal,
  String anchor = '',
  String calendarTime = '',
  String systemKey = '',
}) {
  switch (kind) {
    case SourceKind.habit:
      final what = goal == null ? 'a goal of yours' : goal.text;
      final when = calendarTime.isNotEmpty
          ? ' · on your calendar $calendarTime'
          : (anchor.isEmpty ? '' : ' · ${_lowerFirst(anchor)}');
      return 'For: $what$when';
    case SourceKind.calendar:
      return calendarTime.isEmpty
          ? 'For: your calendar'
          : 'For: your calendar · $calendarTime';
    case SourceKind.prep:
      return 'For: getting ready for what is on your calendar';
    case SourceKind.followThrough:
      return 'For: taking one thing away from today’s calendar';
    case SourceKind.encounter:
      return 'For: today’s encounter';
    case SourceKind.system:
      return systemKey == 'comeback'
          ? 'For: coming back to the Vale'
          : 'For: closing the day';
    case SourceKind.own:
      return 'For: you · not pinned to a goal yet';
  }
}
