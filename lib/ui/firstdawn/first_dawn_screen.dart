import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../rules/classes.dart';
import '../../rules/day_key.dart';
import '../../rules/encounter.dart' show withArticle;
import '../../rules/enums.dart';
import '../../rules/first_dawn.dart';
import '../../rules/generation.dart';
import '../../rules/goals.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../campfire/campfire_screen.dart' show CampScene;
import '../encounter/class_choice.dart' show classIcon;
import '../feel.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// First Dawn (Amendment v0.4 §3): seven short chapters, one question to a
/// screen, each chapter ending in a mirror of what was heard. Every answer
/// is saved as it is given, so the flow can be left and picked up again.
Future<void> showFirstDawn(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const FirstDawnScreen()),
  );
}

/// A goal added later (Amendment v0.4 §7): the goal and its why, one habit
/// by the same design steps, and a look at its first week.
Future<void> showNewGoal(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const FirstDawnScreen(newGoal: true)),
  );
}

/// The mapping pass on its own, from Settings: say what each recurring
/// event is (Amendment v0.4 §3, Chapter 6).
Future<void> showSeriesReview(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const FirstDawnScreen(seriesOnly: true)),
  );
}

const List<String> _newGoalSteps = <String>[
  'n.domain',
  'c2.goal.0',
  'c1.why.0',
  'c3.habit.0.0',
  'c3.anchor.0.0',
  'c3.often.0.0',
  'c3.size.0.0',
  'c3.track.0.0',
  'c3.dread.0.0',
  'c7.week',
];

/// What the user has said about one recurring event in the mapping pass.
class _SeriesPick {
  _SeriesPick(this.kind);
  MappingKind kind;
  bool heavy = false;

  /// The habit this event is: a plan's id, or `draft:<goal>.<plan>` for
  /// one not made yet. Null when it is not a habit.
  String? plan;

  /// A habit it might be, offered with the switch off.
  String? candidate;
}

/// One screen of the flow: a question, a line of help, and its answers.
class _Page {
  const _Page({
    required this.ask,
    required this.body,
    this.help,
    this.next = 'Next',
    this.onNext,
    this.mirror = false,
  });
  final String ask;
  final String? help;
  final List<Widget> body;
  final String next;

  /// Runs before moving on; the flow moves on only if it returns true.
  final Future<bool> Function()? onNext;
  final bool mirror;
}

class FirstDawnScreen extends StatefulWidget {
  const FirstDawnScreen({
    super.key,
    this.newGoal = false,
    this.seriesOnly = false,
  });

  /// One goal added later, not the whole questionnaire.
  final bool newGoal;

  /// Only the calendar's mapping pass.
  final bool seriesOnly;

  @override
  State<FirstDawnScreen> createState() => _FirstDawnScreenState();
}

class _FirstDawnScreenState extends State<FirstDawnScreen> {
  late GameController _game;
  late FirstDawnDraft _d;
  bool _ready = false;
  bool _busy = false;
  String _at = '';

  final Map<String, TextEditingController> _text =
      <String, TextEditingController>{};

  /// Quests already on the board, for the review (migration).
  List<QuestRow> _existing = const <QuestRow>[];

  /// The recurring events found, once read; and what was said about each.
  List<EventSeries>? _series;
  bool _loadingSeries = false;
  final Map<String, _SeriesPick> _picks = <String, _SeriesPick>{};

  /// The first-week row that is open for changes, as `goal.plan`.
  String? _openRow;

  // Chapter 5: the companion, as confirmed.
  CompanionKind? _kind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _game = GameScope.of(context);
    if (widget.seriesOnly) {
      _d = FirstDawnDraft();
      _at = 'c6.series';
    } else if (widget.newGoal) {
      _d = FirstDawnDraft();
      _at = _newGoalSteps.first;
    } else {
      _d = _game.firstDawnDraft;
      if (_game.firstDawnState == FirstDawnState.fresh) _d.fresh = true;
      final steps = _steps;
      _at = steps.contains(_d.at) ? _d.at : steps.first;
      if (!_d.fresh) _loadExisting();
    }
    for (final m in _game.settings.mappings) {
      _picks[m.seriesKey] = _SeriesPick(m.kind)
        ..heavy = m.heavy
        ..plan = m.planId;
    }
  }

  Future<void> _loadExisting() async {
    final rows = await _game.repo.unpinnedQuests();
    if (!mounted) return;
    setState(() => _existing = rows);
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Moving through the flow ------------------------------------------

  bool get _calendarOn => _game.settings.calendarOn && _game.calendarGranted;

  /// The whole questionnaire, as opposed to one of its parts on its own.
  bool get _whole => !widget.newGoal && !widget.seriesOnly;

  List<String> get _steps {
    if (widget.seriesOnly) return const <String>['c6.series'];
    if (widget.newGoal) return _newGoalSteps;
    return stepsFor(
      _d,
      calendarGranted: _calendarOn,
      hasExisting: _existing.isNotEmpty,
    );
  }

  Future<void> _save() async {
    if (!_whole) return;
    _d.at = _at;
    await _game.saveFirstDawnDraft(_d);
  }

  void _go(String step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _at = step;
      _openRow = null;
    });
    _save();
  }

  Future<void> _next(_Page page) async {
    if (_busy) return;
    final before = page.onNext;
    if (before != null) {
      setState(() => _busy = true);
      final ok = await before();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
    }
    if (page.mirror) {
      final chapter = chapterOf(_at);
      _d.confirmed.add(chapter);
      _d.passed.remove(chapter);
    }
    final steps = _steps;
    final i = steps.indexOf(_at);
    if (i < 0 || i >= steps.length - 1) {
      await _finish();
      return;
    }
    Feel.tap();
    _go(steps[i + 1]);
  }

  void _back() {
    final steps = _steps;
    final i = steps.indexOf(_at);
    if (i > 0) _go(steps[i - 1]);
  }

  /// Passes over the rest of this chapter. Nothing answered is thrown away.
  void _skipChapter() {
    final chapter = chapterOf(_at);
    _d.passed.add(chapter);
    final steps = _steps;
    final next = steps.firstWhere(
      (s) => chapterOf(s) > chapter,
      orElse: () => steps.last,
    );
    _go(next);
  }

  /// Leaves the flow where it stands, to be picked up again.
  Future<void> _leave() async {
    if (_whole) {
      await _save();
      final state = _game.firstDawnState;
      if (state == FirstDawnState.fresh || state == FirstDawnState.offered) {
        await _game.setFirstDawn(FirstDawnState.begun);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    Feel.done();
    if (widget.seriesOnly) {
      // The page has saved the mappings already.
    } else if (widget.newGoal) {
      await _game.addGoalFrom(_d);
    } else {
      final already = _game.settings.plans.length;
      await _game.finishFirstDawn(_d);
      await _resolveDraftPlans(already);
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// A recurring event that was said to *be* a habit designed in this run
  /// could only point at the draft; now that the plans exist, it points at
  /// the plan.
  Future<void> _resolveDraftPlans(int already) async {
    if (!_picks.values.any((p) => p.plan?.startsWith('draft:') ?? false)) {
      return;
    }
    final made = _game.settings.plans.sublist(already);
    final ids = <String, String>{};
    var k = 0;
    for (var g = 0; g < _d.goals.length; g++) {
      for (var p = 0; p < _d.goals[g].plans.length; p++) {
        final plan = _d.goals[g].plans[p];
        if (plan.isEmpty || plan.dropped) continue;
        if (k < made.length) ids['draft:$g.$p'] = made[k].id;
        k++;
      }
    }
    await _game.saveMappings(_mappings(ids));
  }

  List<CalendarMapping> _mappings([Map<String, String> ids = const {}]) {
    final old = <String, CalendarMapping>{
      for (final m in _game.settings.mappings) m.seriesKey: m,
    };
    return <CalendarMapping>[
      for (final e in _picks.entries)
        CalendarMapping(
          seriesKey: e.key,
          kind: e.value.kind,
          heavy: e.value.heavy,
          planId: (e.value.plan?.startsWith('draft:') ?? false)
              ? ids[e.value.plan]
              : e.value.plan,
          prepOff: old[e.key]?.prepOff ?? false,
          followOff: old[e.key]?.followOff ?? false,
        ),
    ];
  }

  // ---- Small builders ----------------------------------------------------

  TextEditingController _field(String id, String initial) =>
      _text.putIfAbsent(id, () => TextEditingController(text: initial));

  Widget _card(Widget child) => ParchmentCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      );

  Widget _input(
    String id,
    String initial,
    String hint,
    ValueChanged<String> onChanged, {
    int lines = 1,
  }) =>
      _card(
        TextField(
          key: ValueKey<String>('field-$id'),
          controller: _field(id, initial),
          minLines: lines,
          maxLines: lines < 2 ? 2 : lines + 1,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          style: AppText.body.copyWith(fontSize: 16, color: Palette.slate),
          decoration: InputDecoration(hintText: hint),
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
        ),
      );

  Widget _chips(List<Widget> pills) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: pills),
      );

  Widget _pill(
    String label,
    bool selected,
    VoidCallback onTap, {
    String? caption,
    String? icon,
  }) =>
      ChoicePill(
        label: label,
        selected: selected,
        caption: caption,
        icon: icon,
        color: Palette.moss,
        onTap: () {
          Feel.tap();
          setState(onTap);
          _save();
        },
      );

  /// A full-width choice: a title and one line beneath.
  Widget _option(
    String title,
    String line,
    bool selected,
    VoidCallback onTap, {
    String? icon,
    String? tag,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected
              ? Palette.forest
              : Palette.forestNight.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? Palette.goldBright
                  : Palette.onDark.withValues(alpha: 0.14),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Feel.tap();
              setState(onTap);
              _save();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    VIcon(
                      icon,
                      size: 22,
                      color: selected ? Palette.goldBright : Palette.onDarkSoft,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style:
                              AppText.cardTitle.copyWith(color: Palette.onDark),
                        ),
                        if (line.isNotEmpty)
                          Text(
                            line,
                            style: AppText.small
                                .copyWith(color: Palette.onDarkSoft),
                          ),
                      ],
                    ),
                  ),
                  if (tag != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tag.toUpperCase(),
                        style: AppText.label.copyWith(
                          color: Palette.goldBright,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: VIcon('check', size: 18, color: Palette.goldBright),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          text,
          style: AppText.small.copyWith(color: Palette.onDarkSoft),
        ),
      );

  Widget _weekdayRow(Set<int> days, {bool single = false}) => _chips(<Widget>[
        for (var d = 1; d <= 7; d++)
          _pill(DayKey.weekdayShort[d - 1], days.contains(d), () {
            if (single) {
              days
                ..clear()
                ..add(d);
            } else if (!days.remove(d)) {
              days.add(d);
            }
          }),
      ]);

  /// One line of a mirror: what was heard, and a way back to change it.
  Widget _heard(String title, List<String> lines, {String? editAt}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ParchmentCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          onTap: editAt == null ? null : () => _go(editAt),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.cardTitle),
                    for (final l in lines)
                      if (l.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l,
                            style: AppText.small
                                .copyWith(color: Palette.slateSoft),
                          ),
                        ),
                  ],
                ),
              ),
              if (editAt != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: VIcon('edit', size: 16, color: Palette.slateFaint),
                ),
            ],
          ),
        ),
      );

  // ---- The pages ---------------------------------------------------------

  _Page _page(String step) {
    final (a, b) = stepIndexes(step);
    final name = step.split('.').take(2).join('.');
    switch (name) {
      case 'c1.domains':
      case 'n.domain':
        return _domains(single: name == 'n.domain');
      case 'c1.why':
        return _why(a);
      case 'c1.mirror':
        return _mirrorStory();
      case 'c2.goal':
        return _goal(a);
      case 'c2.horizon':
        return _horizon(a);
      case 'c2.check':
        return _check(a);
      case 'c2.mirror':
        return _mirrorGoals();
      case 'c3.habit':
        return _habit(a, b);
      case 'c3.anchor':
        return _anchor(a, b);
      case 'c3.often':
        return _often(a, b);
      case 'c3.size':
        return _size(a, b);
      case 'c3.track':
        return _track(a, b);
      case 'c3.dread':
        return _dread(a, b);
      case 'c3.mirror':
        return _mirrorHabits();
      case 'c4.wake':
        return _pick('When does your day usually start?', wakeWindows, _d.wake,
            (v) => _d.wake = v);
      case 'c4.sleep':
        return _pick('And when does it usually end?', sleepWindows, _d.sleep,
            (v) => _d.sleep = v);
      case 'c4.work':
        return _pick(
          'What does your working week look like?',
          workPatterns,
          _d.work,
          (v) => _d.work = v,
        );
      case 'c4.peak':
        return _peak();
      case 'c4.rest':
        return _rest();
      case 'c4.burst':
        return _burst();
      case 'c4.mirror':
        return _mirrorRhythm();
      case 'c5.quiz':
        return _quiz(a);
      case 'c5.class':
        return _class();
      case 'c5.companion':
        return _companion();
      case 'c5.mirror':
        return _mirrorClass();
      case 'c6.promise':
        return _promise();
      case 'c6.calendars':
        return _calendars();
      case 'c6.series':
        return _seriesPage();
      case 'c6.mirror':
        return _mirrorCalendar();
      case 'c7.week':
        return _week();
      case 'c7.existing':
        return _existingPage();
      case 'c7.calibrate':
        return _calibrate();
      default:
        return _camp();
    }
  }

  GoalDraft _goalAt(int g) {
    while (_d.goals.length <= g) {
      _d.goals.add(GoalDraft(domain: LifeDomain.body));
    }
    return _d.goals[g];
  }

  PlanDraft _planAt(int g, int p) {
    final goal = _goalAt(g);
    while (goal.plans.length <= p) {
      goal.plans.add(PlanDraft());
    }
    return goal.plans[p];
  }

  // Chapter 1.

  _Page _domains({required bool single}) {
    bool has(LifeDomain d) => _d.goals.any((g) => g.domain == d);
    return _Page(
      ask: single
          ? 'Which part of life is this goal for?'
          : 'Where would you like life to move?',
      help: single
          ? null
          : 'Pick up to three. More can be added later, one at a time.',
      body: <Widget>[
        for (final domain in LifeDomain.values)
          _option(domain.label, '', has(domain), () {
            if (single) {
              final kept = _d.goals.isEmpty ? null : _d.goals.first;
              _d.goals
                ..clear()
                ..add(
                  GoalDraft(
                    domain: domain,
                    why: kept?.why ?? '',
                    text: kept?.text ?? '',
                    plans: kept?.plans,
                  ),
                );
            } else if (has(domain)) {
              _d.goals.removeWhere((g) => g.domain == domain);
            } else if (_d.goals.length < maxGoals) {
              _d.goals.add(GoalDraft(domain: domain));
            }
          }, icon: domain.icon),
        if (!single && _d.goals.length >= maxGoals)
          _note('Three is plenty to begin with. Fewer, kept, beats many.'),
      ],
    );
  }

  _Page _why(int g) {
    final goal = _goalAt(g);
    return _Page(
      ask: '${goal.domain.label}: what would better look like?',
      help: 'One line, in your own words. Type it, or use the microphone on '
          'your keyboard.',
      body: <Widget>[
        _input('why.$g', goal.why, 'Better would look like…', (v) {
          goal.why = v;
        }, lines: 2),
      ],
    );
  }

  _Page _mirrorStory() => _Page(
        ask: 'Here’s what I heard',
        help: _d.goals.isEmpty
            ? 'Nothing chosen yet, and that is fine. The board starts from '
                'the starter quests, and you can tell Valebound your goals '
                'any time from Settings.'
            : 'Tap a line to change it.',
        mirror: true,
        next: 'That’s right',
        body: <Widget>[
          for (var g = 0; g < _d.goals.length; g++)
            _heard(
              _d.goals[g].domain.label,
              <String>[
                _d.goals[g].why.trim().isEmpty
                    ? 'No line yet.'
                    : '“${_d.goals[g].why.trim()}”',
              ],
              editAt: 'c1.why.$g',
            ),
        ],
      );

  // Chapter 2.

  _Page _goal(int g) {
    final goal = _goalAt(g);
    final field = _field('goal.$g', goal.text);
    return _Page(
      ask: '${goal.domain.label}: what is the goal?',
      help: goal.why.trim().isEmpty
          ? 'Start from one of these, or write your own.'
          : 'You said: “${goal.why.trim()}”',
      body: <Widget>[
        _chips(<Widget>[
          for (final starter in goalStarters[goal.domain] ?? const <String>[])
            _pill(starter, goal.text == starter, () {
              goal.text = starter;
              field.text = starter;
            }),
        ]),
        _input('goal.$g', goal.text, 'My goal is…', (v) => goal.text = v),
      ],
    );
  }

  _Page _horizon(int g) {
    final goal = _goalAt(g);
    return _Page(
      ask: 'How far off is “${goal.title}”?',
      body: <Widget>[
        for (final h in Horizon.values)
          _option(h.label, '', goal.horizon == h, () => goal.horizon = h),
      ],
    );
  }

  _Page _check(int g) {
    final goal = _goalAt(g);
    return _Page(
      ask: 'How will you know it’s working?',
      help: 'A phrase you would recognise, not a number.',
      body: <Widget>[
        _input('check.$g', goal.check, 'I’ll know because…', (v) {
          goal.check = v;
        }, lines: 2),
      ],
    );
  }

  _Page _mirrorGoals() => _Page(
        ask: 'Here’s what I heard',
        help: _d.goals.isEmpty ? 'No goals yet.' : 'Tap a goal to change it.',
        mirror: true,
        next: 'That’s right',
        body: <Widget>[
          for (var g = 0; g < _d.goals.length; g++)
            _heard(
              _d.goals[g].title,
              <String>[
                '${_d.goals[g].domain.label} · ${_d.goals[g].horizon.label}',
                if (_d.goals[g].check.trim().isNotEmpty)
                  'Working when: ${_d.goals[g].check.trim()}',
              ],
              editAt: 'c2.goal.$g',
            ),
        ],
      );

  // Chapter 3.

  _Page _habit(int g, int p) {
    final goal = _goalAt(g);
    final plan = _planAt(g, p);
    final field = _field('habit.$g.$p', plan.habit);
    void sized() {
      // Any earlier Tiny and Stretch belonged to other words.
      _text.remove('tiny.$g.$p')?.dispose();
      _text.remove('stretch.$g.$p')?.dispose();
      if (!plan.trackChosen) {
        plan.track = suggestTrack(
          plan.habit,
          companionName: _game.companionName,
        );
      }
    }

    return _Page(
      ask: 'What small, repeatable thing moves “${goal.title}”?',
      help: p == 0
          ? 'Pick one, or write your own.'
          : 'A second habit for the same goal.',
      body: <Widget>[
        _chips(<Widget>[
          for (final idea in habitIdeas[goal.domain] ?? const <HabitIdea>[])
            _pill(idea.target, plan.habit == idea.target, () {
              plan
                ..habit = idea.target
                ..tiny = idea.tiny
                ..stretch = idea.stretch;
              field.text = idea.target;
              sized();
            }),
        ]),
        _input('habit.$g.$p', plan.habit, 'For example: read for 20 minutes',
            (v) {
          plan
            ..habit = v
            ..tiny = ''
            ..stretch = '';
          sized();
        }),
      ],
    );
  }

  _Page _anchor(int g, int p) {
    final plan = _planAt(g, p);
    final field = _field('anchor.$g.$p', plan.anchor);
    return _Page(
      ask: 'When in your day does it attach?',
      help: 'A habit holds best stacked on something you already do.',
      body: <Widget>[
        _chips(<Widget>[
          for (final anchor in commonAnchors.keys)
            _pill(anchor, plan.anchor == anchor, () {
              plan.anchor = anchor;
              field.text = anchor;
            }),
        ]),
        _input('anchor.$g.$p', plan.anchor, 'Or in your own words', (v) {
          plan.anchor = v;
        }),
      ],
    );
  }

  _Page _often(int g, int p) {
    final plan = _planAt(g, p);
    final chosen = plan.frequency == PlanFrequency.days ||
        plan.frequency == PlanFrequency.weekly;
    return _Page(
      ask: 'How often?',
      body: <Widget>[
        _chips(<Widget>[
          for (final f in PlanFrequency.values)
            _pill(f.label, plan.frequency == f, () {
              plan.frequency = f;
              if (f == PlanFrequency.weekly && plan.weekdays.length > 1) {
                final first = (plan.weekdays.toList()..sort()).first;
                plan.weekdays
                  ..clear()
                  ..add(first);
              }
            }),
        ]),
        if (chosen)
          _weekdayRow(
            plan.weekdays,
            single: plan.frequency == PlanFrequency.weekly,
          ),
        _note(
          'Most people who pick daily for everything keep about half. '
          'Fewer, kept, beats many, dropped.',
        ),
      ],
    );
  }

  _Page _size(int g, int p) {
    final plan = _planAt(g, p);
    final proposed = proposeSizes(plan.habit);
    if (plan.tiny.trim().isEmpty) plan.tiny = proposed.tiny;
    if (plan.stretch.trim().isEmpty) plan.stretch = proposed.stretch;
    Widget size(String label, String line, Widget field) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: AppText.label.copyWith(color: Palette.goldBright),
              ),
              Text(line, style: AppText.small.copyWith(color: Palette.onDarkSoft)),
              const SizedBox(height: 4),
              field,
            ],
          ),
        );
    return _Page(
      ask: 'Size it',
      help: 'Every habit comes in three sizes, chosen on the day. Reword '
          'the Tiny and the Stretch until they fit.',
      body: <Widget>[
        size(
          'Tiny',
          'About two minutes. For the hard days: it counts in full.',
          _input('tiny.$g.$p', plan.tiny, 'The smallest version',
              (v) => plan.tiny = v),
        ),
        size(
          'Target',
          'The habit as you designed it.',
          _card(Text(plan.habit.trim(), style: AppText.body)),
        ),
        size(
          'Stretch',
          'The sprint version, for a good day.',
          _input('stretch.$g.$p', plan.stretch, 'The bigger version',
              (v) => plan.stretch = v),
        ),
      ],
    );
  }

  _Page _track(int g, int p) {
    final plan = _planAt(g, p);
    final suggested =
        suggestTrack(plan.habit, companionName: _game.companionName);
    final companion = _game.companionName;
    return _Page(
      ask: 'Whose quest is it?',
      body: <Widget>[
        for (final t in Track.values)
          _option(
            t == Track.hero ? 'Yours' : (t == Track.companion ? '$companion’s' : 'Shared'),
            trackLine(t, companion),
            plan.track == t,
            () {
              plan
                ..track = t
                ..trackChosen = true;
            },
            tag: t == suggested ? 'Suggested' : null,
          ),
      ],
    );
  }

  _Page _dread(int g, int p) {
    final plan = _planAt(g, p);
    const lines = <Dread, String>{
      Dread.easy: 'You would do it anyway.',
      Dread.fine: 'A normal effort.',
      Dread.heavy: 'It takes something. Heavy habits count for more, and are '
          'never placed back to back.',
    };
    return _Page(
      ask: 'How does this one feel?',
      body: <Widget>[
        for (final dread in Dread.values)
          _option(dread.label, lines[dread]!, plan.dread == dread, () {
            plan.dread = dread;
          }),
      ],
    );
  }

  _Page _mirrorHabits() {
    final rows = <Widget>[];
    for (var g = 0; g < _d.goals.length; g++) {
      final goal = _d.goals[g];
      final plans = <(int, PlanDraft)>[
        for (var p = 0; p < goal.plans.length; p++)
          if (!goal.plans[p].isEmpty) (p, goal.plans[p]),
      ];
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            goal.title.toUpperCase(),
            style: AppText.label.copyWith(color: Palette.goldBright),
          ),
        ),
      );
      if (plans.isEmpty) rows.add(_note('No habit for this goal yet.'));
      for (final (p, plan) in plans) {
        final made = planFrom(
          plan,
          Goal(id: '', domain: goal.domain, text: goal.title),
          id: '',
          startDay: _game.day,
        );
        rows.add(
          _heard(
            made.target,
            <String>[
              <String>[
                made.frequencyLabel,
                if (made.anchor.isNotEmpty) made.anchor,
                '${made.track.label} track',
                'feels ${made.dread.label.toLowerCase()}',
              ].join(' · '),
              'Tiny: ${made.tiny}',
              'Stretch: ${made.stretch}',
            ],
            editAt: 'c3.habit.$g.$p',
          ),
        );
      }
      if (plans.length == 1 && goal.plans.length < maxPlansPerGoal) {
        rows.add(
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: 'Add a second habit',
              icon: 'plus',
              color: Palette.onDarkSoft,
              onPressed: () {
                goal.plans.add(PlanDraft());
                _go('c3.habit.$g.${goal.plans.length - 1}');
              },
            ),
          ),
        );
      }
    }
    return _Page(
      ask: 'Here’s what I heard',
      help: _d.goals.isEmpty
          ? 'No habits to design without a goal.'
          : 'Tap a habit to change it.',
      mirror: true,
      next: 'That’s right',
      body: rows,
    );
  }

  // Chapter 4.

  _Page _pick(
    String ask,
    List<String> choices,
    String current,
    ValueChanged<String> set,
  ) =>
      _Page(
        ask: ask,
        help: 'Roughly is fine. It is kept with your rhythm; nothing is timed '
            'by it yet.',
        body: <Widget>[
          for (final c in choices) _option(c, '', current == c, () => set(c)),
        ],
      );

  _Page _peak() => _Page(
        ask: 'When is your energy at its best?',
        help: 'Used only to put quests in a sensible order.',
        body: <Widget>[
          for (final w in <DayWindow>[
            DayWindow.morning,
            DayWindow.afternoon,
            DayWindow.evening,
          ])
            _option(w.label, '', _d.peak == w, () => _d.peak = w),
        ],
      );

  _Page _rest() => _Page(
        ask: 'Any days the board should run light on purpose?',
        help: 'On a rest day heavy habits stay off, and the others show their '
            'Tiny size. Leave it empty for none.',
        body: <Widget>[_weekdayRow(_d.restDays)],
      );

  _Page _burst() => _Page(
        ask: 'Do you work in sprints and quiet stretches, or steady daily?',
        body: <Widget>[
          _option(
            'Sprints and quiet stretches',
            'The week’s total matters more than any one day.',
            _d.sprints == true,
            () => _d.sprints = true,
          ),
          _option(
            'Steady, most days',
            'A little, often.',
            _d.sprints == false,
            () => _d.sprints = false,
          ),
        ],
      );

  _Page _mirrorRhythm() {
    final rest = (_d.restDays.toList()..sort())
        .map((d) => DayKey.weekdayLong[d - 1])
        .join(', ');
    return _Page(
      ask: 'Here’s what I heard',
      help: 'Tap a line to change it.',
      mirror: true,
      next: 'That’s right',
      body: <Widget>[
        _heard(
          'Your day',
          <String>[
            'Starts ${_d.wake.isEmpty ? 'when it starts' : _d.wake.toLowerCase()}'
                ', ends ${_d.sleep.isEmpty ? 'when it ends' : _d.sleep.toLowerCase()}',
          ],
          editAt: 'c4.wake',
        ),
        _heard(
          'Your week',
          <String>[
            'Work: ${_d.work.isEmpty ? 'not said' : _d.work.toLowerCase()}',
            'Rest days: ${rest.isEmpty ? 'none' : rest}',
          ],
          editAt: 'c4.work',
        ),
        _heard(
          'Your energy',
          <String>[
            'Best in the ${(_d.peak ?? DayWindow.anytime) == DayWindow.anytime ? 'day, any time' : _d.peak!.label.toLowerCase()}',
            _d.sprints == null
                ? 'Sprints or steady: not said'
                : (_d.sprints!
                    ? 'In sprints and quiet stretches'
                    : 'Steady, most days'),
          ],
          editAt: 'c4.peak',
        ),
      ],
    );
  }

  // Chapter 5.

  _Page _quiz(int q) {
    final question = quiz[q];
    return _Page(
      ask: question.ask,
      help: 'Question ${q + 1} of ${quiz.length}. There are no wrong answers.',
      body: <Widget>[
        for (final i in quizOrder(q))
          _option(
            question.answers[i],
            '',
            _d.quizAnswers[q] == HeroClass.choices[i].name,
            () => _d.quizAnswers[q] = HeroClass.choices[i].name,
          ),
      ],
    );
  }

  HeroClass get _pickedClass =>
      HeroClass.byId(_d.chosenClass) ??
      _game.heroClass ??
      _d.classScore.recommended;

  _Page _class() {
    final score = _d.classScore;
    final picked = _pickedClass;
    return _Page(
      ask: 'Your class',
      help: score.reason,
      next: 'Become ${withArticle(picked.label)}',
      body: <Widget>[
        for (final cls in HeroClass.choices)
          _option(
            cls.label,
            '${cls.role} · ${cls.home.label} · ${cls.resource}',
            picked == cls,
            () => _d.chosenClass = cls.name,
            icon: classIcon(cls),
            tag: cls == score.recommended
                ? 'Recommended'
                : (cls == score.close ? 'Close' : null),
          ),
        _note(
          'Any class can wake any creature, and you can change it for nothing '
          'at the weekly Campfire.',
        ),
      ],
      onNext: () async {
        _d.chosenClass = picked.name;
        return true;
      },
    );
  }

  _Page _companion() {
    final c = _game.companion;
    final kind = _kind ?? c?.kind ?? CompanionKind.hound;
    final name = _field('companion', c?.name ?? '');
    return _Page(
      ask: 'Is ${_game.companionName} based on a real animal in your life?',
      body: <Widget>[
        _option('Yes', 'Their quests can be real care.', _d.realAnimal == true,
            () => _d.realAnimal = true),
        _option('No', 'A companion of the Vale only.', _d.realAnimal == false,
            () => _d.realAnimal = false),
        if (_d.realAnimal == true) ...<Widget>[
          _note('Check the name and the kind are right.'),
          _input('companion', name.text, 'Companion name', (_) {}),
          const SizedBox(height: 10),
          _chips(<Widget>[
            for (final k in CompanionKind.values)
              _pill(k.label, kind == k, () => _kind = k),
          ]),
        ],
      ],
      onNext: () async {
        final typed = name.text.trim();
        if (c != null &&
            _d.realAnimal == true &&
            typed.isNotEmpty &&
            (typed != c.name || kind != c.kind)) {
          await _game.changeCompanion(name: typed, kind: kind);
        }
        return true;
      },
    );
  }

  _Page _mirrorClass() {
    final c = _game.companion;
    final score = _d.classScore;
    return _Page(
      ask: 'Here’s what I heard',
      help: 'Tap a line to change it.',
      mirror: true,
      next: 'That’s right',
      body: <Widget>[
        _heard(
          'Class: ${_pickedClass.label}',
          <String>[score.reason],
          editAt: 'c5.class',
        ),
        if (c != null)
          _heard(
            'Companion: ${c.name}, the ${c.kind.label}',
            <String>[
              _d.realAnimal == true
                  ? 'Based on a real animal in your life.'
                  : c.kind.temperament,
            ],
            editAt: 'c5.companion',
          ),
      ],
    );
  }

  // Chapter 6.

  _Page _promise() {
    final on = _calendarOn;
    return _Page(
      ask: 'Your calendar',
      help: 'Valebound reads today’s events on this phone only. Nothing '
          'leaves the device. Event titles are never written to logs; you '
          'choose what becomes a quest.',
      next: on ? 'Next' : 'Connect the calendar',
      body: <Widget>[
        if (on)
          _note('It is connected.')
        else ...<Widget>[
          _note(
            'This is optional. Without it, calendar quests simply never '
            'appear.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: 'Not now',
              color: Palette.onDarkSoft,
              onPressed: () async {
                await _game.declineCalendar();
                if (!mounted) return;
                _go('c6.mirror');
              },
            ),
          ),
        ],
      ],
      onNext: () async {
        if (!on) await _game.connectCalendar();
        return true;
      },
    );
  }

  _Page _calendars() => _Page(
        ask: 'Which calendars count?',
        help: 'Switch off any that should never make a quest.',
        body: <Widget>[
          _card(
            Column(
              children: <Widget>[
                for (final cal in _game.calendars)
                  ToggleRow(
                    label: cal.name,
                    caption: cal.account.isEmpty ? null : cal.account,
                    value: !_game.settings.excludedCalendars.contains(cal.id),
                    onChanged: (on) async {
                      await _game.setCalendarExcluded(cal.id, excluded: !on);
                      if (mounted) setState(() => _series = null);
                    },
                  ),
                if (_game.calendars.isEmpty)
                  Text('No calendars found on this phone.', style: AppText.body),
              ],
            ),
          ),
        ],
      );

  Future<void> _loadSeries() async {
    if (_loadingSeries) return;
    _loadingSeries = true;
    final found = await _game.readSeries();
    _loadingSeries = false;
    if (!mounted) return;
    final plans = _matchable();
    setState(() {
      _series = found;
      final all = <HabitPlan>[for (final m in plans) m.$2];
      for (final s in found) {
        final fresh = !_picks.containsKey(s.key);
        final pick = _picks.putIfAbsent(s.key, () => _SeriesPick(s.proposed));
        pick.candidate = pick.plan;
        if (pick.plan != null || pick.kind == MappingKind.ignore) continue;
        // Words that match are switched on for the user to see; a match
        // by type alone is only offered.
        final sure = planByWords(s.title, all);
        final match = sure ?? planMatching(s.title, pick.kind, all);
        if (match == null) continue;
        pick.candidate = plans.firstWhere((m) => m.$2.id == match.id).$1;
        if (sure != null && fresh) pick.plan = pick.candidate;
      }
    });
  }

  /// The habits a recurring event could be: those already made, and those
  /// designed in this run, each with what a mapping would point at.
  List<(String, HabitPlan)> _matchable() {
    final out = <(String, HabitPlan)>[
      for (final p in _game.plans) (p.id, p),
    ];
    if (!_whole) return out;
    for (var g = 0; g < _d.goals.length; g++) {
      final goal = _d.goals[g];
      for (var p = 0; p < goal.plans.length; p++) {
        final plan = goal.plans[p];
        if (plan.isEmpty || plan.dropped) continue;
        out.add((
          'draft:$g.$p',
          planFrom(
            plan,
            Goal(id: '', domain: goal.domain, text: goal.title),
            id: 'draft:$g.$p',
            startDay: _game.day,
          ),
        ));
      }
    }
    return out;
  }

  _Page _seriesPage() {
    final series = _series;
    if (series == null) {
      _loadSeries();
      return const _Page(
        ask: 'Your recurring events',
        help: 'Looking at the next four weeks…',
        body: <Widget>[],
      );
    }
    final plans = <String, HabitPlan>{for (final m in _matchable()) m.$1: m.$2};
    return _Page(
      ask: 'Your recurring events',
      help: series.isEmpty
          ? 'Nothing comes round twice in the next four weeks. One-off events '
              'are still offered on the day, for you to accept or dismiss.'
          : 'Say what each one is, once. A mapped event becomes a quest on '
              'its days; Ignore keeps it out for good.',
      next: series.isEmpty ? 'Next' : 'Confirm all',
      body: <Widget>[
        for (final s in series)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.title, style: AppText.cardTitle),
                  Text(
                    '${s.when} · ${s.count} times in four weeks',
                    style: AppText.small.copyWith(color: Palette.slateSoft),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final k in MappingKind.values)
                        ChoicePill(
                          label: k.label,
                          selected: _picks[s.key]?.kind == k,
                          onTap: () {
                            Feel.tap();
                            setState(() {
                              final pick = _picks[s.key]!..kind = k;
                              if (k == MappingKind.ignore) pick.plan = null;
                            });
                          },
                        ),
                    ],
                  ),
                  if (_picks[s.key]?.kind != MappingKind.ignore) ...<Widget>[
                    if (plans[_picks[s.key]?.candidate] != null)
                      ToggleRow(
                        label: 'This is my habit',
                        caption: '${plans[_picks[s.key]!.candidate]!.target}. '
                            'They make one quest, not two.',
                        value: _picks[s.key]!.plan != null,
                        onChanged: (on) => setState(() {
                          final pick = _picks[s.key]!;
                          pick.plan = on ? pick.candidate : null;
                        }),
                      ),
                    ToggleRow(
                      label: 'It takes a lot out of me',
                      caption: 'Offer a small Prep before it and a '
                          'Follow-through after.',
                      value: _picks[s.key]?.heavy ?? false,
                      onChanged: (v) =>
                          setState(() => _picks[s.key]!.heavy = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
      onNext: () async {
        await _game.saveMappings(_mappings());
        return true;
      },
    );
  }

  _Page _mirrorCalendar() {
    final on = _calendarOn;
    final mapped =
        _picks.values.where((p) => p.kind != MappingKind.ignore).length;
    final ignored = _picks.length - mapped;
    return _Page(
      ask: 'Here’s what I heard',
      mirror: true,
      next: 'That’s right',
      body: <Widget>[
        if (!on)
          _heard('Calendar: not connected', const <String>[
            'Calendar quests will simply never appear. You can connect it '
                'later in Settings.',
          ])
        else
          _heard(
            'Calendar: connected',
            <String>[
              _picks.isEmpty
                  ? 'No recurring events mapped.'
                  : '$mapped recurring ${mapped == 1 ? 'event becomes' : 'events become'} '
                      'quests, $ignored ignored.',
              'One-off events are offered on the day. Event names stay out '
                  'of your exports unless you switch that on in Settings.',
            ],
            editAt: 'c6.series',
          ),
      ],
    );
  }

  // Chapter 7.

  _Page _week() {
    final week = weekPreview(_d, startDay: _game.day);
    final any = week.any((d) => d.$2.isNotEmpty);
    final rows = <Widget>[];
    for (final (day, entries) in week) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '${DayKey.weekdayLong[DayKey.weekday(day) - 1]}'
                    '${day == _game.day ? ' · today' : ''}'
                .toUpperCase(),
            style: AppText.label.copyWith(color: Palette.goldBright),
          ),
        ),
      );
      if (entries.isEmpty) {
        rows.add(_note('Nothing planned. The Campfire is always there.'));
      }
      for (final e in entries) {
        final id = '${e.goal}.${e.plan}';
        final rowId = '$day/$id';
        final plan = _d.goals[e.goal].plans[e.plan];
        final open = _openRow == rowId;
        final movable = plan.frequency == PlanFrequency.days ||
            plan.frequency == PlanFrequency.weekly;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ParchmentCard(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              onTap: () => setState(() => _openRow = open ? null : rowId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(e.text, style: AppText.cardTitle)),
                      if (e.size == QuestSize.tiny)
                        Text(
                          'TINY',
                          style: AppText.label.copyWith(color: Palette.goldDeep),
                        ),
                    ],
                  ),
                  Text(
                    e.forLine,
                    style: AppText.small.copyWith(color: Palette.slateSoft),
                  ),
                  if (open)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          ChoicePill(
                            label: 'Tiny only this week',
                            selected: plan.tinyOnly,
                            onTap: () {
                              setState(() => plan.tinyOnly = !plan.tinyOnly);
                              _save();
                            },
                          ),
                          if (movable)
                            ChoicePill(
                              label: 'Move to the next day',
                              selected: false,
                              onTap: () {
                                final from = DayKey.weekday(day);
                                var to = from % 7 + 1;
                                while (plan.weekdays.contains(to) && to != from) {
                                  to = to % 7 + 1;
                                }
                                setState(() {
                                  plan.weekdays
                                    ..remove(from)
                                    ..add(to);
                                  _openRow = null;
                                });
                                _save();
                              },
                            ),
                          ChoicePill(
                            label: 'Drop this habit',
                            selected: false,
                            onTap: () {
                              setState(() {
                                plan.dropped = true;
                                _openRow = null;
                              });
                              _save();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return _Page(
      ask: widget.newGoal ? 'Its first week' : 'Your first week',
      help: any
          ? 'Every quest says what it is for. Tap one to make it Tiny only '
              'this week, move its day, or drop it.'
          : 'No habits designed, so the week is the starter board. You can '
              'tell Valebound your goals any time from Settings.',
      next: widget.newGoal ? 'Raise the banner' : 'Next',
      body: any ? rows : const <Widget>[],
    );
  }

  _Page _existingPage() => _Page(
        ask: 'The quests you already have',
        help: 'Nothing is deleted. Pin each to a goal, keep it as it is, or '
            'archive it to the Quest Log.',
        body: <Widget>[
          for (final q in _existing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(q.name, style: AppText.cardTitle),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        ChoicePill(
                          label: 'Keep',
                          selected: (_d.existing[q.id] ?? 'keep') == 'keep',
                          onTap: () => _choose(q.id, 'keep'),
                        ),
                        for (var g = 0; g < _d.goals.length; g++)
                          ChoicePill(
                            label: 'For: ${_d.goals[g].title}',
                            selected: _d.existing[q.id] == 'goal:$g',
                            onTap: () => _choose(q.id, 'goal:$g'),
                          ),
                        ChoicePill(
                          label: 'Archive',
                          selected: _d.existing[q.id] == 'archive',
                          onTap: () => _choose(q.id, 'archive'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  void _choose(String questId, String choice) {
    Feel.tap();
    setState(() => _d.existing[questId] = choice);
    _save();
  }

  _Page _calibrate() => _Page(
        ask: 'Does this week look…',
        help: 'This only sets how long the timed habits run in the first '
            'week.',
        body: <Widget>[
          _option('Too light', 'Timed habits run a quarter longer this week.',
              _d.calibration == 125, () => _d.calibration = 125),
          _option('About right', 'As designed.', _d.calibration == 100,
              () => _d.calibration = 100),
          _option('Too much', 'Timed habits run a quarter shorter this week.',
              _d.calibration == 75, () => _d.calibration = 75),
        ],
      );

  _Page _camp() {
    final banners = <String>[
      for (final g in _d.goals)
        if (g.plans.any((p) => !p.isEmpty && !p.dropped) ||
            g.text.trim().isNotEmpty ||
            g.why.trim().isNotEmpty)
          g.title,
    ];
    return _Page(
      ask: 'The first camp',
      help: banners.isEmpty
          ? 'The road is open. Your board starts from the starter quests.'
          : 'Your banners are up. The board is made from them each dawn.',
      next: 'Begin',
      body: <Widget>[
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          child: CampScene(
            // The day has not been lived yet: the Campfire's own line
            // about the evening does not belong here.
            story: 'This is your camp. Whatever a day holds, it ends here, '
                'by this fire, with ${_game.companionName} beside you.',
          ),
        ),
        const SizedBox(height: 12),
        for (final b in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                const VIcon('banner', size: 20, color: Palette.goldBright),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b,
                    style: AppText.cardTitle.copyWith(color: Palette.onDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- The frame ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final page = _page(_at);
    final index = steps.indexOf(_at);
    final chapter = chapterOf(_at);
    final first = index <= 0;
    final last = index == steps.length - 1;

    final String label;
    if (widget.seriesOnly) {
      label = 'YOUR CALENDAR';
    } else if (widget.newGoal) {
      label = 'NEW GOAL · ${index + 1} OF ${steps.length}';
    } else {
      label = 'FIRST DAWN · CHAPTER $chapter OF $chapterCount';
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(color: Palette.goldBright),
              ),
            ),
            if (_whole && !page.mirror && !last)
              QuietButton(
                label: 'Skip chapter',
                color: Palette.onDarkSoft,
                onPressed: _skipChapter,
              ),
            RoundIconButton(
              icon: 'close',
              semanticLabel: 'Leave for now',
              size: 36,
              background: Palette.forestNight.withValues(alpha: 0.55),
              foreground: Palette.onDark,
              edge: Palette.onDark.withValues(alpha: 0.25),
              onPressed: _leave,
            ),
          ],
        ),
        if (_whole)
          Text(
            chapterTitles[chapter - 1],
            style: AppText.small.copyWith(color: Palette.onDarkSoft),
          ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: steps.length <= 1 ? 1 : (index + 1) / steps.length,
            minHeight: 4,
            backgroundColor: Palette.onDark.withValues(alpha: 0.12),
            color: Palette.goldBright,
          ),
        ),
      ],
    );

    final question = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          page.ask,
          style: AppText.display.copyWith(color: Palette.onDark, fontSize: 24),
        ),
        if (page.help != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            page.help!,
            style: AppText.small.copyWith(color: Palette.onDarkSoft),
          ),
        ],
      ],
    );

    final footer = Row(
      children: <Widget>[
        if (!first)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: QuietButton(
              label: 'Back',
              color: Palette.onDarkSoft,
              onPressed: _busy ? null : _back,
            ),
          ),
        Expanded(
          child: PrimaryButton(
            label: page.next,
            onPressed: _busy ? null : () => _next(page),
          ),
        ),
      ],
    );

    final Widget body;
    if (isExpanded(context)) {
      body = TwoPane(
        start: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          children: <Widget>[header, const SizedBox(height: 18), question],
        ),
        end: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ListView(
                  key: ValueKey<String>('answers-$_at'),
                  children: page.body,
                ),
              ),
              const SizedBox(height: 8),
              footer,
            ],
          ),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
            child: header,
          ),
          Expanded(
            child: ListView(
              key: ValueKey<String>('page-$_at'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: <Widget>[
                question,
                const SizedBox(height: 14),
                ...page.body,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: footer,
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (first) {
          _leave();
        } else {
          _back();
        }
      },
      child: Scaffold(
        backgroundColor: Palette.forestNight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Palette.forestDeep, Palette.forestNight],
            ),
          ),
          child: SafeArea(child: body),
        ),
      ),
    );
  }
}
