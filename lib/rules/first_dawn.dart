/// First Dawn (Amendment v0.4 §3): what the questionnaire asks, what it
/// keeps while it is being answered, and how the answers become goals,
/// habit plans and a class recommendation.
///
/// Pure rules. The screens in `lib/ui/firstdawn/` hold no logic of their
/// own beyond showing a step and writing an answer into the draft.
library;

import 'dart:convert';

import 'classes.dart';
import 'day_key.dart';
import 'enums.dart';
import 'goals.dart';

/// At most this many goals at launch (Chapter 2): the questionnaire steers
/// away from a twelve-goal board.
const int maxGoals = 3;

/// At most this many habits for one goal (Chapter 3).
const int maxPlansPerGoal = 2;

const int chapterCount = 7;

const List<String> chapterTitles = <String>[
  'Your Story',
  'Goals',
  'Habit Design',
  'Your Rhythm',
  'Class & Companion',
  'Calendar',
  'Your First Week',
];

// ---- The library the chips are drawn from ------------------------------

/// A habit offered as a chip, already in three sizes.
class HabitIdea {
  const HabitIdea(this.target, this.tiny, this.stretch);
  final String target;
  final String tiny;
  final String stretch;
}

/// Sentence starters for a goal (Chapter 2). Free text is always there.
const Map<LifeDomain, List<String>> goalStarters = <LifeDomain, List<String>>{
  LifeDomain.body: <String>[
    'Feel stronger',
    'Move every day',
    'Have more energy',
    'Sleep better',
  ],
  LifeDomain.making: <String>[
    'Finish my project',
    'Make something every week',
    'Get better at my craft',
    'Clear the project pile',
  ],
  LifeDomain.mind: <String>[
    'Read more',
    'Learn something new',
    'Think more clearly',
    'Keep a journal',
  ],
  LifeDomain.home: <String>[
    'Be present at home',
    'Keep the house in hand',
    'Look after my companion well',
    'Eat together more',
  ],
  LifeDomain.adventure: <String>[
    'Get outside more',
    'See new places',
    'Walk further',
    'Try something new each month',
  ],
  LifeDomain.work: <String>[
    'Stay on top of things',
    'Keep the week planned',
    'Finish what I start',
    'Leave work at work',
  ],
  LifeDomain.community: <String>[
    'See friends more',
    'Stay in touch',
    'Show up for my people',
    'Host more often',
  ],
};

/// Small, repeatable things offered for a domain (Chapter 3).
const Map<LifeDomain, List<HabitIdea>> habitIdeas =
    <LifeDomain, List<HabitIdea>>{
  LifeDomain.body: <HabitIdea>[
    HabitIdea(
      'Walk for 20 minutes',
      'Walk to the corner and back',
      'Walk for 45 minutes',
    ),
    HabitIdea(
      'Stretch for 10 minutes',
      'Stretch for 2 minutes',
      'Stretch for 20 minutes',
    ),
    HabitIdea(
      'Strength work for 20 minutes',
      'One set of anything',
      'Strength work for 40 minutes',
    ),
    HabitIdea(
      'Wind down before bed',
      'Phone down ten minutes early',
      'A full hour of winding down',
    ),
  ],
  LifeDomain.making: <HabitIdea>[
    HabitIdea(
      'Paint for 30 minutes',
      'Paint one small detail',
      'Paint for 60 minutes',
    ),
    HabitIdea(
      'Make for 30 minutes',
      'Do one small step',
      'Make for 60 minutes',
    ),
    HabitIdea('Sketch one page', 'Sketch for 2 minutes', 'Fill three pages'),
    HabitIdea(
      'Tidy the workbench',
      'Put five things away',
      'Reset the whole bench',
    ),
  ],
  LifeDomain.mind: <HabitIdea>[
    HabitIdea(
      'Read for 20 minutes',
      'Read one page',
      'Read for 45 minutes',
    ),
    HabitIdea(
      'Practise for 15 minutes',
      'Practise for 2 minutes',
      'Practise for 30 minutes',
    ),
    HabitIdea('Write three lines in a journal', 'Write one line', 'Write a page'),
    HabitIdea(
      'Sit quietly for 10 minutes',
      'Three slow breaths',
      'Sit quietly for 20 minutes',
    ),
  ],
  LifeDomain.home: <HabitIdea>[
    HabitIdea('Walk the dog', 'Once round the block', 'The long loop'),
    HabitIdea(
      'Tidy for 10 minutes',
      'Clear one surface',
      'Reset one whole room',
    ),
    HabitIdea(
      'Cook a proper dinner',
      'Chop one thing ahead',
      'Cook enough for tomorrow too',
    ),
    HabitIdea(
      'Unhurried time with family',
      'Ten minutes, phone away',
      'A whole evening, phone away',
    ),
  ],
  LifeDomain.adventure: <HabitIdea>[
    HabitIdea(
      'Get outside for 20 minutes',
      'Step outside for 2 minutes',
      'Get outside for 60 minutes',
    ),
    HabitIdea(
      'Take a new route',
      'Turn down one new street',
      'Go somewhere I have not been',
    ),
    HabitIdea('Plan the next outing', 'Write down one place', 'Book it'),
  ],
  LifeDomain.work: <HabitIdea>[
    HabitIdea(
      'Plan tomorrow for 5 minutes',
      'Write down one thing for tomorrow',
      'Plan the whole week',
    ),
    HabitIdea(
      'Clear messages for 15 minutes',
      'Answer one message',
      'Clear messages for 30 minutes',
    ),
    HabitIdea(
      'Do one errand or admin job',
      'Find the paper it needs',
      'Clear three of them',
    ),
    HabitIdea(
      'Focus block of 25 minutes',
      'Focus for 5 minutes',
      'Two focus blocks of 25 minutes',
    ),
  ],
  LifeDomain.community: <HabitIdea>[
    HabitIdea('Message one friend', 'Send one line', 'Call instead'),
    HabitIdea('Make one plan with someone', 'Suggest a day', 'Host it'),
    HabitIdea('Check in on family', 'A two-line message', 'A proper call'),
  ],
};

/// Rough windows for waking and sleeping (Chapter 4).
const List<String> wakeWindows = <String>[
  'Before 6',
  '6 to 8',
  '8 to 10',
  'After 10',
];
const List<String> sleepWindows = <String>[
  'Before 10',
  '10 to midnight',
  'After midnight',
];
const List<String> workPatterns = <String>[
  'Weekdays',
  'Shifts',
  'Irregular',
  'None',
];

// ---- The taste quiz (Chapter 5) ----------------------------------------

class QuizQuestion {
  const QuizQuestion(this.ask, this.answers);
  final String ask;

  /// One answer for each of the four classes, in [HeroClass.choices] order.
  final List<String> answers;
}

const List<QuizQuestion> quiz = <QuizQuestion>[
  QuizQuestion('A locked gate stands in your way. You…', <String>[
    'Scout for another way round',
    'Put a shoulder to it',
    'Study the lock until it makes sense',
    'Build something to lift it',
  ]),
  QuizQuestion('The best moment in a story is…', <String>[
    'Setting out at first light, a friend at your heel',
    'Holding the bridge so the others get across',
    'The riddle finally coming clear',
    'The plan clicking into place',
  ]),
  QuizQuestion('A friend is having a rough week. You…', <String>[
    'Take them out for a long walk',
    'Turn up, and stay',
    'Listen, then help them see it another way',
    'Fix the thing that is broken',
  ]),
  QuizQuestion('A free afternoon is best spent…', <String>[
    'Somewhere you have never been',
    'Moving: the garden, a swim, a long ride',
    'Deep in a book',
    'At the workbench',
  ]),
  QuizQuestion('When a job is big, you…', <String>[
    'Start walking and find the path as you go',
    'Keep steadily at it until it gives',
    'Think it through first',
    'Lay out the tools and prepare',
  ]),
  QuizQuestion('People count on you to be…', <String>[
    'The one who notices things',
    'The steady one',
    'The one who knows',
    'The one who can make it work',
  ]),
];

/// The order a question's four answers are shown in, so the same class is
/// not always the first choice.
List<int> quizOrder(int question) =>
    <int>[for (var i = 0; i < 4; i++) (i + question) % 4];

/// What Chapter 5 worked out, kept with the recommendation that was shown
/// (Amendment v0.4 §8).
class ClassScore {
  const ClassScore({
    required this.scores,
    required this.recommended,
    required this.reason,
    this.close,
  });

  factory ClassScore.fromJson(Map<String, dynamic> j) => ClassScore(
        scores: <HeroClass, int>{
          for (final cls in HeroClass.choices)
            cls: ((j['scores'] as Map<String, dynamic>?)?[cls.name] as int?) ?? 0,
        },
        recommended: HeroClass.byId(j['recommended'] as String?) ??
            HeroClass.choices.first,
        close: HeroClass.byId(j['close'] as String?),
        reason: '${j['reason'] ?? ''}',
      );

  final Map<HeroClass, int> scores;
  final HeroClass recommended;

  /// A second class within two points of the first, if there is one.
  final HeroClass? close;

  /// The reasoning, as shown.
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scores': <String, int>{
          for (final e in scores.entries) e.key.name: e.value,
        },
        'recommended': recommended.name,
        if (close != null) 'close': close!.name,
        'reason': reason,
      };
}

String _joinAnd(List<String> words) {
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first;
  return '${words.sublist(0, words.length - 1).join(', ')} and ${words.last}';
}

/// Class scores from the quiz and the chosen domains. Each answer is two
/// points; a domain whose attribute is a class's own is three; the two
/// attributes no class owns lean toward the classes nearest them.
ClassScore scoreClasses({
  required List<HeroClass?> answers,
  required List<LifeDomain> domains,
}) {
  final scores = <HeroClass, int>{for (final c in HeroClass.choices) c: 0};
  void add(HeroClass cls, int points) => scores[cls] = scores[cls]! + points;
  for (final a in answers) {
    if (a != null && scores.containsKey(a)) add(a, 2);
  }
  for (final d in domains) {
    for (final cls in HeroClass.choices) {
      if (cls.home == d.attribute) add(cls, 3);
    }
    if (d.attribute == Attribute.care) {
      add(HeroClass.ranger, 1);
      add(HeroClass.warden, 1);
    }
    if (d.attribute == Attribute.order) {
      add(HeroClass.sage, 1);
      add(HeroClass.artificer, 1);
    }
  }
  final ranked = HeroClass.choices.toList()
    ..sort((a, b) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
  final first = ranked[0];
  final second = ranked[1];
  final close = scores[first]! - scores[second]! <= 2 ? second : null;
  final attributes = <String>[];
  for (final d in domains) {
    if (!attributes.contains(d.attribute.label)) attributes.add(d.attribute.label);
  }
  final fits = close == null
      ? '${first.label} fits'
      : '${first.label} fits, ${close.label} is close';
  final answered = answers.where((a) => a != null).length;
  final String reason;
  if (attributes.isNotEmpty) {
    reason = 'Your goals lean ${_joinAnd(attributes)}: $fits.';
  } else if (answered > 0) {
    reason = 'From your answers: $fits.';
  } else {
    reason = 'With nothing to go on yet, ${first.label} is a sound place to '
        'start.';
  }
  return ClassScore(
    scores: scores,
    recommended: first,
    close: close,
    reason: reason,
  );
}

// ---- The draft: answers so far, kept so the flow can be resumed --------

/// One habit being designed (Chapter 3), and what the first-week review
/// did with it (Chapter 7).
class PlanDraft {
  PlanDraft({
    this.habit = '',
    this.anchor = '',
    this.frequency = PlanFrequency.daily,
    Set<int>? weekdays,
    this.tiny = '',
    this.stretch = '',
    this.track = Track.hero,
    this.trackChosen = false,
    this.dread = Dread.fine,
    this.tinyOnly = false,
    this.dropped = false,
  }) : weekdays = weekdays ?? <int>{};

  factory PlanDraft.fromJson(Map<String, dynamic> j) => PlanDraft(
        habit: '${j['habit'] ?? ''}',
        anchor: '${j['anchor'] ?? ''}',
        frequency: PlanFrequency.byName(j['frequency'] as String?),
        weekdays: <int>{
          for (final d in (j['weekdays'] as List<dynamic>? ?? const <dynamic>[]))
            if (d is int) d,
        },
        tiny: '${j['tiny'] ?? ''}',
        stretch: '${j['stretch'] ?? ''}',
        track: Track.values.firstWhere(
          (t) => t.name == j['track'],
          orElse: () => Track.hero,
        ),
        trackChosen: j['trackChosen'] == true,
        dread: Dread.byName(j['dread'] as String?),
        tinyOnly: j['tinyOnly'] == true,
        dropped: j['dropped'] == true,
      );

  /// The Target, in the user's words.
  String habit;
  String anchor;
  PlanFrequency frequency;
  Set<int> weekdays;
  String tiny;
  String stretch;
  Track track;

  /// The user has confirmed or moved the track, so it is no longer
  /// re-suggested when the habit's words change.
  bool trackChosen;
  Dread dread;

  /// Chapter 7: Tiny is the size shown for the first week.
  bool tinyOnly;

  /// Chapter 7: not to be made into a plan after all.
  bool dropped;

  bool get isEmpty => habit.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'habit': habit,
        'anchor': anchor,
        'frequency': frequency.name,
        'weekdays': weekdays.toList()..sort(),
        'tiny': tiny,
        'stretch': stretch,
        'track': track.name,
        'trackChosen': trackChosen,
        'dread': dread.name,
        'tinyOnly': tinyOnly,
        'dropped': dropped,
      };
}

/// One domain, its why-line (Chapter 1), its goal (Chapter 2) and the
/// habits designed for it (Chapter 3).
class GoalDraft {
  GoalDraft({
    required this.domain,
    this.why = '',
    this.text = '',
    this.horizon = Horizon.ongoing,
    this.check = '',
    List<PlanDraft>? plans,
  }) : plans = plans ?? <PlanDraft>[];

  factory GoalDraft.fromJson(Map<String, dynamic> j) => GoalDraft(
        domain: LifeDomain.byName(j['domain'] as String?),
        why: '${j['why'] ?? ''}',
        text: '${j['text'] ?? ''}',
        horizon: Horizon.byName(j['horizon'] as String?),
        check: '${j['check'] ?? ''}',
        plans: <PlanDraft>[
          for (final p in (j['plans'] as List<dynamic>? ?? const <dynamic>[]))
            if (p is Map<String, dynamic>) PlanDraft.fromJson(p),
        ],
      );

  LifeDomain domain;
  String why;
  String text;
  Horizon horizon;
  String check;
  List<PlanDraft> plans;

  /// The goal's words, falling back to the why-line and then the domain,
  /// so a goal whose chapter was passed over still has a name.
  String get title {
    if (text.trim().isNotEmpty) return text.trim();
    if (why.trim().isNotEmpty) return why.trim();
    return domain.label;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'domain': domain.name,
        'why': why,
        'text': text,
        'horizon': horizon.name,
        'check': check,
        'plans': <Map<String, dynamic>>[for (final p in plans) p.toJson()],
      };
}

/// Everything answered so far. Saved after every answer, so leaving the
/// app half way loses nothing.
class FirstDawnDraft {
  FirstDawnDraft({
    List<GoalDraft>? goals,
    this.wake = '',
    this.sleep = '',
    this.work = '',
    this.peak,
    Set<int>? restDays,
    this.sprints,
    List<String?>? quizAnswers,
    this.chosenClass,
    this.realAnimal,
    this.calibration = 100,
    Map<String, String>? existing,
    this.at = '',
    Set<int>? confirmed,
    Set<int>? passed,
  })  : goals = goals ?? <GoalDraft>[],
        restDays = restDays ?? <int>{},
        quizAnswers = quizAnswers ?? List<String?>.filled(quiz.length, null),
        existing = existing ?? <String, String>{},
        confirmed = confirmed ?? <int>{},
        passed = passed ?? <int>{};

  factory FirstDawnDraft.fromJson(Map<String, dynamic> j) {
    final answers = List<String?>.filled(quiz.length, null);
    final raw = j['quiz'] as List<dynamic>? ?? const <dynamic>[];
    for (var i = 0; i < raw.length && i < answers.length; i++) {
      answers[i] = raw[i] as String?;
    }
    Set<int> ints(Object? source) => <int>{
          for (final v in (source as List<dynamic>? ?? const <dynamic>[]))
            if (v is int) v,
        };
    return FirstDawnDraft(
      goals: <GoalDraft>[
        for (final g in (j['goals'] as List<dynamic>? ?? const <dynamic>[]))
          if (g is Map<String, dynamic>) GoalDraft.fromJson(g),
      ],
      wake: '${j['wake'] ?? ''}',
      sleep: '${j['sleep'] ?? ''}',
      work: '${j['work'] ?? ''}',
      peak: j['peak'] == null ? null : DayWindow.byName(j['peak'] as String?),
      restDays: ints(j['restDays']),
      sprints: j['sprints'] as bool?,
      quizAnswers: answers,
      chosenClass: j['class'] as String?,
      realAnimal: j['realAnimal'] as bool?,
      calibration: (j['calibration'] as int?) ?? 100,
      existing: <String, String>{
        for (final e
            in (j['existing'] as Map<String, dynamic>? ?? const <String, dynamic>{})
                .entries)
          e.key: '${e.value}',
      },
      at: '${j['at'] ?? ''}',
      confirmed: ints(j['confirmed']),
      passed: ints(j['passed']),
    );
  }

  static FirstDawnDraft decode(String? source) {
    if (source == null || source.isEmpty) return FirstDawnDraft();
    try {
      final raw = jsonDecode(source);
      return raw is Map<String, dynamic>
          ? FirstDawnDraft.fromJson(raw)
          : FirstDawnDraft();
    } on FormatException {
      return FirstDawnDraft();
    }
  }

  List<GoalDraft> goals;

  // Chapter 4.
  String wake;
  String sleep;
  String work;
  DayWindow? peak;
  Set<int> restDays;
  bool? sprints;

  // Chapter 5: a class name for each quiz question, and the class chosen.
  List<String?> quizAnswers;
  String? chosenClass;
  bool? realAnimal;

  // Chapter 7.
  int calibration;

  /// What to do with each quest already on the board (migration): `keep`,
  /// `archive`, or `goal:<index into goals>`.
  Map<String, String> existing;

  /// The step the user is on, so the flow resumes there.
  String at;

  /// Chapters whose mirror has been confirmed, and chapters passed over.
  Set<int> confirmed;
  Set<int> passed;

  /// Goals with a habit to make into a plan.
  Iterable<PlanDraft> get livePlans sync* {
    for (final g in goals) {
      for (final p in g.plans) {
        if (!p.isEmpty && !p.dropped) yield p;
      }
    }
  }

  List<HeroClass?> get answeredClasses =>
      <HeroClass?>[for (final a in quizAnswers) HeroClass.byId(a)];

  ClassScore get classScore => scoreClasses(
        answers: answeredClasses,
        domains: <LifeDomain>[for (final g in goals) g.domain],
      );

  Rhythm rhythm({required String startDay}) => Rhythm(
        wake: wake,
        sleep: sleep,
        work: work,
        peak: peak ?? DayWindow.anytime,
        restDays: restDays,
        sprints: sprints ?? false,
        calibration: calibration,
        weekOneEnds: DayKey.addDays(startDay, 6),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goals': <Map<String, dynamic>>[for (final g in goals) g.toJson()],
        'wake': wake,
        'sleep': sleep,
        'work': work,
        if (peak != null) 'peak': peak!.name,
        'restDays': restDays.toList()..sort(),
        if (sprints != null) 'sprints': sprints,
        'quiz': quizAnswers,
        if (chosenClass != null) 'class': chosenClass,
        if (realAnimal != null) 'realAnimal': realAnimal,
        'calibration': calibration,
        'existing': existing,
        'at': at,
        'confirmed': confirmed.toList()..sort(),
        'passed': passed.toList()..sort(),
      };

  String encode() => jsonEncode(toJson());
}

/// Where First Dawn stands for this hero.
enum FirstDawnState {
  /// A new hero: it opens by itself after the prologue.
  fresh,

  /// A hero from before 0.8: offered on the board as "Tell Valebound your
  /// goals".
  offered,

  /// Begun and left part way.
  begun,

  /// Put off: only the Settings prompt remains.
  later,

  /// Finished.
  done;

  static FirstDawnState byName(String? name) =>
      FirstDawnState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => FirstDawnState.offered,
      );
}

// ---- The steps ----------------------------------------------------------

/// The chapter a step belongs to, from its id (`c3.anchor.0.1` is 3).
int chapterOf(String step) {
  if (step.length < 2 || step[0] != 'c') return 1;
  return int.tryParse(step[1]) ?? 1;
}

/// Every step of First Dawn for the answers so far, in order. One step is
/// one screen and one question; each chapter ends in its mirror. A chapter
/// with nothing to ask (no domains chosen) is only its mirror.
List<String> stepsFor(
  FirstDawnDraft d, {
  required bool calendarGranted,
  required bool hasExisting,
}) {
  final steps = <String>['c1.domains'];
  for (var g = 0; g < d.goals.length; g++) {
    steps.add('c1.why.$g');
  }
  steps.add('c1.mirror');

  for (var g = 0; g < d.goals.length; g++) {
    steps
      ..add('c2.goal.$g')
      ..add('c2.horizon.$g')
      ..add('c2.check.$g');
  }
  steps.add('c2.mirror');

  for (var g = 0; g < d.goals.length; g++) {
    final plans = d.goals[g].plans;
    final count = plans.isEmpty ? 1 : plans.length;
    for (var p = 0; p < count && p < maxPlansPerGoal; p++) {
      steps
        ..add('c3.habit.$g.$p')
        ..add('c3.anchor.$g.$p')
        ..add('c3.often.$g.$p')
        ..add('c3.size.$g.$p')
        ..add('c3.track.$g.$p')
        ..add('c3.dread.$g.$p');
    }
  }
  steps
    ..add('c3.mirror')
    ..addAll(<String>[
      'c4.wake',
      'c4.sleep',
      'c4.work',
      'c4.peak',
      'c4.rest',
      'c4.burst',
      'c4.mirror',
    ]);
  for (var q = 0; q < quiz.length; q++) {
    steps.add('c5.quiz.$q');
  }
  steps.addAll(<String>['c5.class', 'c5.companion', 'c5.mirror']);
  steps.add('c6.promise');
  if (calendarGranted) {
    steps.addAll(<String>['c6.calendars', 'c6.series']);
  }
  steps.add('c6.mirror');
  steps.add('c7.week');
  if (hasExisting) steps.add('c7.existing');
  steps.addAll(<String>['c7.calibrate', 'c7.camp']);
  return steps;
}

/// The first step of [chapter] in [steps], or the last step if the
/// chapter is not there.
String firstStepOf(int chapter, List<String> steps) => steps.firstWhere(
      (s) => chapterOf(s) == chapter,
      orElse: () => steps.last,
    );

/// The two numbers after a step's name (`c3.anchor.1.0` gives 1 and 0).
(int, int) stepIndexes(String step) {
  final parts = step.split('.');
  final a = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  final b = parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0;
  return (a, b);
}

// ---- From answers to goals and plans -----------------------------------

/// The goals and habit plans a draft makes. [newId] supplies ids; plans
/// come back without a quest yet.
({List<Goal> goals, List<HabitPlan> plans}) plansFrom(
  FirstDawnDraft d, {
  required String Function() newId,
  required String startDay,
}) {
  final goals = <Goal>[];
  final plans = <HabitPlan>[];
  for (final g in d.goals) {
    final goal = Goal(
      id: newId(),
      domain: g.domain,
      text: g.title,
      why: g.why.trim(),
      horizon: g.horizon,
      check: g.check.trim(),
    );
    goals.add(goal);
    for (final p in g.plans) {
      if (p.isEmpty || p.dropped) continue;
      plans.add(planFrom(p, goal, id: newId(), startDay: startDay));
    }
  }
  return (goals: goals, plans: plans);
}

/// One habit plan from one designed habit.
HabitPlan planFrom(
  PlanDraft p,
  Goal goal, {
  required String id,
  required String startDay,
}) {
  final target = p.habit.trim();
  final proposed = proposeSizes(target);
  final weekdays = switch (p.frequency) {
    PlanFrequency.days => p.weekdays,
    PlanFrequency.weekly => p.weekdays.isEmpty
        ? <int>{DateTime.saturday}
        : <int>{(p.weekdays.toList()..sort()).first},
    _ => const <int>{},
  };
  return HabitPlan(
    id: id,
    goalId: goal.id,
    target: target,
    tiny: p.tiny.trim().isEmpty ? proposed.tiny : p.tiny.trim(),
    stretch: p.stretch.trim().isEmpty ? proposed.stretch : p.stretch.trim(),
    attribute: goal.domain.attribute,
    anchor: p.anchor.trim(),
    window: windowOfAnchor(p.anchor.trim()),
    frequency: p.frequency == PlanFrequency.days && weekdays.isEmpty
        ? PlanFrequency.daily
        : p.frequency,
    weekdays: weekdays,
    track: p.track,
    dread: p.dread,
    minutes: minutesIn(target),
    tinyUntil: p.tinyOnly ? DayKey.addDays(startDay, 6) : null,
  );
}
