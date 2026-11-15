/// The Sunday Check-In (Amendment v0.4 §6): two questions, and at most one
/// proposed change that the user accepts or declines. Nothing here changes
/// a habit by itself, and nothing is a grade: counts are information.
library;

import 'dart:convert';

import 'goals.dart';

/// "This week's quests felt…"
enum Felt {
  light('Too light'),
  right('About right'),
  heavy('Too heavy');

  const Felt(this.label);
  final String label;

  static Felt? byName(String? name) {
    for (final f in Felt.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// How many times a habit was done at each size.
class SizeCounts {
  const SizeCounts({this.tiny = 0, this.target = 0, this.stretch = 0});
  final int tiny;
  final int target;
  final int stretch;

  int get total => tiny + target + stretch;

  SizeCounts plus(QuestSize size) => SizeCounts(
        tiny: tiny + (size == QuestSize.tiny ? 1 : 0),
        target: target + (size == QuestSize.target ? 1 : 0),
        stretch: stretch + (size == QuestSize.stretch ? 1 : 0),
      );

  SizeCounts operator +(SizeCounts other) => SizeCounts(
        tiny: tiny + other.tiny,
        target: target + other.target,
        stretch: stretch + other.stretch,
      );

  /// e.g. `2 Tiny · 3 Target · 0 Stretch`.
  String get label => '$tiny Tiny · $target Target · $stretch Stretch';
}

enum ProposalKind { shrinkTarget, tinyAsTarget, growTarget, stretchAsTarget, weekdaysOnly }

/// One change the app may put to the user. It is only ever applied by the
/// user accepting it.
class Proposal {
  const Proposal({
    required this.kind,
    required this.planId,
    required this.ask,
    required this.changed,
    this.param = 0,
  });

  final ProposalKind kind;
  final String planId;

  /// The question, with the counts it rests on.
  final String ask;

  /// The plan as it would be if accepted.
  final HabitPlan changed;
  final int param;

  /// What remembers this exact suggestion, so that one declined is never
  /// put again.
  String get key => '${kind.name}:$planId:$param';
}

int _roundToFive(num value) {
  final r = ((value + 2.5) ~/ 5) * 5;
  return r < 5 ? 5 : r;
}

String _short(String text) =>
    text.length <= 34 ? text : '${text.substring(0, 33).trimRight()}…';

/// Every change the counts could suggest, most useful first.
List<Proposal> _candidates({
  required List<HabitPlan> plans,
  required Map<String, SizeCounts> counts,
  required Felt felt,
}) {
  final out = <Proposal>[];
  final live = <HabitPlan>[for (final p in plans) if (p.active) p];

  // A habit kept alive at its Tiny, never at its Target: offer a Target
  // nearer to what is actually happening.
  for (final p in live) {
    final c = counts[p.id] ?? const SizeCounts();
    if (c.tiny < 3 || c.target + c.stretch > 0) continue;
    final minutes = p.minutes;
    final basis = '${_short(p.target)}: ${c.tiny} Tiny, 0 Target in two weeks.';
    if (minutes != null && minutes > 10) {
      final smaller = _roundToFive(minutes * 2 / 3);
      if (smaller < minutes) {
        out.add(
          Proposal(
            kind: ProposalKind.shrinkTarget,
            planId: p.id,
            param: smaller,
            ask: '$basis Shrink the Target to $smaller minutes?',
            changed: p.copyWith(
              target: withMinutes(p.target, smaller),
              stretch: withMinutes(p.stretch, stretchMinutes(smaller)),
              minutes: smaller,
            ),
          ),
        );
        continue;
      }
    }
    out.add(
      Proposal(
        kind: ProposalKind.tinyAsTarget,
        planId: p.id,
        ask: '$basis Make the Tiny the Target for now, and keep the old '
            'Target as the Stretch?',
        changed: p.copyWith(
          target: p.tiny,
          stretch: p.target,
          clearMinutes: true,
        ),
      ),
    );
  }

  // A week that felt too heavy: the habit that comes round most often
  // could rest at the weekend.
  if (felt == Felt.heavy) {
    for (final p in live) {
      if (p.frequency != PlanFrequency.daily) continue;
      out.add(
        Proposal(
          kind: ProposalKind.weekdaysOnly,
          planId: p.id,
          ask: '${_short(p.target)} comes round every day. Try it on weekdays '
              'only?',
          changed: p.copyWith(frequency: PlanFrequency.weekdays),
        ),
      );
    }
  }

  // A habit that keeps being done at its Stretch, or a week that felt too
  // light: offer a bigger Target.
  for (final p in live) {
    final c = counts[p.id] ?? const SizeCounts();
    final outgrown = c.stretch >= 3 && c.tiny == 0;
    if (!outgrown && !(felt == Felt.light && c.target + c.stretch >= 3)) {
      continue;
    }
    final basis = '${_short(p.target)}: ${c.target} Target, ${c.stretch} '
        'Stretch in two weeks.';
    final minutes = p.minutes;
    if (minutes != null) {
      final bigger = _roundToFive(minutes * 1.25);
      if (bigger > minutes) {
        out.add(
          Proposal(
            kind: ProposalKind.growTarget,
            planId: p.id,
            param: bigger,
            ask: '$basis Grow the Target to $bigger minutes?',
            changed: p.copyWith(
              target: withMinutes(p.target, bigger),
              stretch: withMinutes(p.stretch, stretchMinutes(bigger)),
              minutes: bigger,
            ),
          ),
        );
        continue;
      }
    }
    if (outgrown) {
      out.add(
        Proposal(
          kind: ProposalKind.stretchAsTarget,
          planId: p.id,
          ask: '$basis Make the Stretch the Target?',
          changed: p.copyWith(target: p.stretch, clearMinutes: true),
        ),
      );
    }
  }
  return out;
}

/// The one change to put to the user this week, or null. A suggestion
/// whose key is in [declined] is never returned again.
Proposal? proposeChange({
  required List<HabitPlan> plans,
  required Map<String, SizeCounts> counts,
  required Felt felt,
  required Set<String> declined,
}) {
  for (final p in _candidates(plans: plans, counts: counts, felt: felt)) {
    if (!declined.contains(p.key)) return p;
  }
  return null;
}

/// What the check-ins have recorded: the answer for each week, and every
/// suggestion declined or accepted.
class CheckIns {
  const CheckIns({
    this.felt = const <String, String>{},
    this.declined = const <String>{},
    this.accepted = const <String>{},
  });

  factory CheckIns.decode(String? source) {
    if (source == null || source.isEmpty) return const CheckIns();
    try {
      final raw = jsonDecode(source);
      if (raw is! Map<String, dynamic>) return const CheckIns();
      Set<String> strings(Object? list) => <String>{
            for (final v in (list as List<dynamic>? ?? const <dynamic>[])) '$v',
          };
      return CheckIns(
        felt: <String, String>{
          for (final e
              in (raw['felt'] as Map<String, dynamic>? ?? const <String, dynamic>{})
                  .entries)
            e.key: '${e.value}',
        },
        declined: strings(raw['declined']),
        accepted: strings(raw['accepted']),
      );
    } on FormatException {
      return const CheckIns();
    }
  }

  /// The answer given on each check-in day.
  final Map<String, String> felt;
  final Set<String> declined;
  final Set<String> accepted;

  Felt? feltOn(String day) => Felt.byName(felt[day]);

  CheckIns withFelt(String day, Felt answer) => CheckIns(
        felt: <String, String>{...felt, day: answer.name},
        declined: declined,
        accepted: accepted,
      );

  CheckIns withDeclined(String key) => CheckIns(
        felt: felt,
        declined: <String>{...declined, key},
        accepted: accepted,
      );

  CheckIns withAccepted(String key) => CheckIns(
        felt: felt,
        declined: declined,
        accepted: <String>{...accepted, key},
      );

  String encode() => jsonEncode(<String, dynamic>{
        'felt': felt,
        'declined': declined.toList()..sort(),
        'accepted': accepted.toList()..sort(),
      });
}
