/// The Markdown export contract, DESIGN §11.
///
/// Pure text building: no database, no files. Three documents, each UTF-8
/// with LF line endings and YAML frontmatter:
///
///  * `Character Sheet.md`: overwritten on every export.
///  * `Daily/YYYY-MM-DD.md`: one per day.
///  * `Quests.md`: overwritten on every export.
///
/// The `type:` values are part of the contract with the vault and stay as
/// the design gives them, whatever the app is called.
library;

import '../rules/day_key.dart';
import '../rules/enums.dart';

const String characterSheetFile = 'Character Sheet.md';
const String questsFile = 'Quests.md';
const String dailyFolder = 'Daily';

String dailyFile(String day) => '$dailyFolder/$day.md';

const String typeCharacter = 'valebound-character';
const String typeDay = 'valebound-day';
const String typeQuests = 'valebound-quests';

/// A YAML double-quoted scalar, safe for any free text.
String yamlString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ');
  return '"$escaped"';
}

/// Text made safe for one Markdown table cell.
String tableCell(String value) => value
    .replaceAll('|', r'\|')
    .replaceAll('\r', ' ')
    .replaceAll('\n', ' ')
    .trim();

/// `2026-11-14T21:04:07`, local time, no zone: what Obsidian reads as a date.
String isoLocal(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 7412 → `7,412`.
String thousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String _materials(Map<MaterialKind, int> m) => <String>[
      for (final k in MaterialKind.values) '${k.label} ${m[k] ?? 0}',
    ].join(', ');

String _lines(List<String> lines) => '${lines.join('\n')}\n';

/// ` mmol/L`, but `%` sits against its number.
String _unit(String unit) {
  if (unit.isEmpty) return '';
  return unit == '%' ? '%' : ' $unit';
}

// ---- Character Sheet.md --------------------------------------------------

class AttributeLine {
  const AttributeLine(this.attribute, this.level, this.xp);
  final Attribute attribute;
  final int level;
  final int xp;
}

/// What the current restoration still asks for.
class TargetNeed {
  const TargetNeed(this.kind, this.have, this.need);
  final MaterialKind kind;
  final int have;
  final int need;
}

class SheetData {
  const SheetData({
    required this.updated,
    required this.heroName,
    required this.heroLevel,
    required this.heroTotalXp,
    required this.title,
    required this.attributes,
    required this.questsCompleted,
    required this.gold,
    required this.stores,
    required this.gathered,
    required this.daysVisited,
    required this.companionName,
    required this.companionKind,
    required this.companionLevel,
    required this.companionXp,
    required this.bond,
    required this.tricks,
    required this.gear,
    required this.paces,
    required this.discoveries,
    required this.placesRestored,
    required this.placesDrafted,
    required this.restoredByRegion,
    required this.nextTarget,
    required this.nextNeeds,
  });

  final DateTime updated;
  final String heroName;
  final int heroLevel;
  final int heroTotalXp;
  final String title;
  final List<AttributeLine> attributes;
  final int questsCompleted;
  final int gold;
  final Map<MaterialKind, int> stores;
  final Map<MaterialKind, int> gathered;
  final int daysVisited;
  final String companionName;
  final String companionKind;
  final int companionLevel;
  final int companionXp;
  final int bond;
  final List<String> tricks;
  final List<String> gear;
  final int paces;
  final List<String> discoveries;
  final int placesRestored;
  final int placesDrafted;

  /// Region name to the places restored there, in waking order.
  final Map<String, List<String>> restoredByRegion;
  final String nextTarget;
  final List<TargetNeed> nextNeeds;
}

String characterSheetMarkdown(SheetData d) {
  final discoveries = d.discoveries.isEmpty
      ? '0'
      : '${d.discoveries.length} (${d.discoveries.join(', ')})';
  final needs = <String>[
    for (final n in d.nextNeeds)
      if (n.need > 0) '${n.kind.label} ${n.have} of ${n.need}',
  ].join(', ');
  return _lines(<String>[
    '---',
    'type: $typeCharacter',
    'updated: ${isoLocal(d.updated)}',
    'level: ${d.heroLevel}',
    'total_xp: ${d.heroTotalXp}',
    'companion_name: ${yamlString(d.companionName)}',
    'companion_kind: ${yamlString(d.companionKind)}',
    'companion_level: ${d.companionLevel}',
    'bond: ${d.bond}',
    '---',
    '',
    '# Character Sheet',
    '',
    '- Hero: ${d.heroName}',
    '- Level: ${d.heroLevel}',
    '- Title: ${d.title}',
    '',
    '## Attributes',
    '',
    '| Attribute | Level | XP |',
    '|---|---|---|',
    for (final a in d.attributes)
      '| ${a.attribute.label} | ${a.level} | ${a.xp} |',
    '',
    '## Totals',
    '',
    '- Total XP: ${d.heroTotalXp}',
    '- Quests completed: ${d.questsCompleted}',
    '- Gold: ${d.gold}',
    '- Materials in the stores: ${_materials(d.stores)}',
    '- Materials gathered in all: ${_materials(d.gathered)}',
    '- Days visited the Vale: ${d.daysVisited}',
    '',
    '## Companion',
    '',
    '- Kind: ${d.companionKind}',
    '- Name: ${d.companionName}',
    '- Level: ${d.companionLevel}',
    '- Companion XP: ${d.companionXp}',
    '- Bond: ${d.bond}',
    '- Tricks: ${d.tricks.isEmpty ? 'none yet' : d.tricks.join(', ')}',
    '- Gear: ${d.gear.isEmpty ? 'none yet' : d.gear.join(', ')}',
    '- Paces: ${d.paces}',
    '- Discoveries: $discoveries',
    '',
    '## World',
    '',
    '- Places restored: ${d.placesRestored} of ${d.placesDrafted}',
    for (final e in d.restoredByRegion.entries)
      '- ${e.key}: ${e.value.join(', ')}',
    '- Working toward: ${d.nextTarget} ($needs)',
  ]);
}

// ---- Daily/YYYY-MM-DD.md -------------------------------------------------

class DayQuestLine {
  const DayQuestLine({
    required this.completedAt,
    required this.quest,
    required this.track,
    required this.attribute,
    required this.difficulty,
    required this.heroXp,
    required this.companionXp,
  });
  final DateTime completedAt;
  final String quest;
  final Track track;
  final Attribute attribute;
  final Difficulty difficulty;
  final int heroXp;
  final int companionXp;

  /// Hero XP and/or Companion XP, as awarded (DESIGN §7A.2).
  String get xp {
    final parts = <String>[
      if (heroXp > 0) '$heroXp XP',
      if (companionXp > 0) '$companionXp Companion XP',
    ];
    return parts.isEmpty ? '0 XP' : parts.join(' + ');
  }
}

class HealthLine {
  const HealthLine(this.label, this.value, this.unit);
  final String label;
  final String value;
  final String unit;
}

class DayData {
  const DayData({
    required this.day,
    required this.heroLevel,
    required this.xpEarned,
    required this.companionXpEarned,
    required this.paces,
    required this.questsTotal,
    required this.quests,
    required this.pacesTotal,
    required this.campRegion,
    required this.pacesToNextDiscovery,
    this.steps,
    this.discoveries = const <String>[],
    this.health = const <HealthLine>[],
    this.restorations = const <String>[],
    this.note = '',
  });

  final String day;

  /// Hero level at the end of the day.
  final int heroLevel;
  final int xpEarned;
  final int companionXpEarned;

  /// Paces earned that day.
  final int paces;
  final int questsTotal;
  final List<DayQuestLine> quests;

  /// Paces walked in all by the end of the day: the camp position.
  final int pacesTotal;
  final String campRegion;
  final int pacesToNextDiscovery;
  final int? steps;

  /// Titles of the Discoveries unlocked that day.
  final List<String> discoveries;
  final List<HealthLine> health;

  /// e.g. `The Bakehouse (Hearthmere)`.
  final List<String> restorations;
  final String note;
}

String dailyMarkdown(DayData d) {
  final note = d.note.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final hasJourney = d.paces > 0 || d.discoveries.isNotEmpty;
  final total =
      d.questsTotal < d.quests.length ? d.quests.length : d.questsTotal;
  return _lines(<String>[
    '---',
    'type: $typeDay',
    'date: ${d.day}',
    'level: ${d.heroLevel}',
    'xp_earned: ${d.xpEarned}',
    'companion_xp_earned: ${d.companionXpEarned}',
    'paces: ${d.paces}',
    'quests_completed: ${d.quests.length}',
    'quests_total: $total',
    if (d.steps != null) 'steps: ${d.steps}',
    '---',
    '',
    '# ${DayKey.friendly(d.day)} ${d.day.substring(0, 4)}',
    '',
    '## Quests Completed',
    '',
    if (d.quests.isEmpty)
      'A quiet day in the Vale.'
    else ...<String>[
      '| Time | Quest | Track | Attribute | Difficulty | XP |',
      '|---|---|---|---|---|---|',
      for (final q in d.quests)
        '| ${_clock(q.completedAt)} | ${tableCell(q.quest)} | '
            '${q.track.label} | ${q.attribute.label} | '
            '${q.difficulty.label} | ${q.xp} |',
    ],
    if (hasJourney) ...<String>[
      '',
      '## Journey',
      '',
      '- Paces today: ${d.paces}',
      for (final title in d.discoveries) '- Discovery: $title',
      '- Camp: ${d.pacesTotal} ${d.pacesTotal == 1 ? 'Pace' : 'Paces'} along '
          'the road, in ${d.campRegion}. ${d.pacesToNextDiscovery} to the '
          'next discovery.',
    ],
    if (d.health.isNotEmpty) ...<String>[
      '',
      '## Health',
      '',
      for (final h in d.health)
        '- ${h.label}: ${h.value}${_unit(h.unit)}',
    ],
    '',
    '## World',
    '',
    if (d.restorations.isEmpty)
      'The Vale rests.'
    else
      for (final r in d.restorations) '- Restored: $r',
    if (note.trim().isNotEmpty) ...<String>[
      '',
      '## Notes',
      '',
      note,
    ],
  ]);
}

// ---- Quests.md -----------------------------------------------------------

class QuestLine {
  const QuestLine({
    required this.name,
    required this.attribute,
    required this.difficulty,
    required this.schedule,
    required this.type,
    required this.track,
  });
  final String name;
  final Attribute attribute;
  final Difficulty difficulty;

  /// e.g. `Daily`, `Sat, Sun`, `Every 3 days`.
  final String schedule;

  /// e.g. `Tap`, `Timer, 10 min`, `Count to 8`.
  final String type;
  final Track track;
}

class QuestsData {
  const QuestsData({
    required this.updated,
    required this.companionName,
    required this.quests,
  });
  final DateTime updated;
  final String companionName;
  final List<QuestLine> quests;
}

String questsMarkdown(QuestsData d) {
  String line(QuestLine q) => '- **${q.name}** · ${q.attribute.label} · '
      '${q.difficulty.label} · ${q.schedule} · ${q.type}'
      '${q.track == Track.hero ? '' : ' · ${q.track.label} track'}';
  final hero = d.quests.where((q) => q.track == Track.hero).toList();
  final companion = d.quests.where((q) => q.track != Track.hero).toList();
  return _lines(<String>[
    '---',
    'type: $typeQuests',
    'updated: ${isoLocal(d.updated)}',
    'active_quests: ${d.quests.length}',
    '---',
    '',
    '# Quests',
    '',
    'Each line reads: name · attribute · difficulty · schedule · type.',
    '',
    '## Hero',
    '',
    if (hero.isEmpty) 'No hero quests at the moment.',
    for (final q in hero) line(q),
    '',
    '## With ${d.companionName}',
    '',
    if (companion.isEmpty) 'No companion quests at the moment.',
    for (final q in companion) line(q),
  ]);
}

/// How a completion type reads in `Quests.md`.
String describeType(CompletionType type, int? target) => switch (type) {
      CompletionType.tap => 'Tap',
      CompletionType.count =>
        target == null ? 'Count' : 'Count to ${thousands(target)}',
      CompletionType.timer => target == null ? 'Timer' : 'Timer, $target min',
      CompletionType.auto =>
        target == null ? 'Auto' : 'Auto, ${thousands(target)} steps',
      CompletionType.confirm => 'Confirm',
    };

/// A readable label for a free-form health field key.
String healthLabel(String fieldKey) {
  const known = <String, String>{
    'steps': 'Steps',
    'glucose': 'Glucose',
    'glucose_average': 'Average glucose',
    'time_in_range': 'Time in range',
    'weight': 'Weight',
    'injection': 'Weekly injection',
  };
  final preset = known[fieldKey];
  if (preset != null) return preset;
  final words = fieldKey.replaceAll('_', ' ').trim();
  if (words.isEmpty) return fieldKey;
  return words[0].toUpperCase() + words.substring(1);
}
