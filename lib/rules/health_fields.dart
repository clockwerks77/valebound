/// The Health Log's quick-entry fields (DESIGN §9.3).
///
/// The user chooses which appear. The app stores exactly what is typed,
/// shows no advice, no targets and no judgement, and includes the entries in
/// the Markdown export only.
library;

import 'dart:convert';

enum HealthFieldKind {
  /// A number, typed.
  number,

  /// Any short text.
  text,

  /// A tick, with an optional note (e.g. an injection and its dose).
  check,
}

class HealthField {
  const HealthField({
    required this.key,
    required this.label,
    this.unit = '',
    this.kind = HealthFieldKind.number,
  });

  /// Stored with each entry. Free-form, so new fields need no migration.
  final String key;
  final String label;
  final String unit;
  final HealthFieldKind kind;

  HealthField withUnit(String newUnit) =>
      HealthField(key: key, label: label, unit: newUnit, kind: kind);

  Map<String, Object> toJson() => <String, Object>{
        'key': key,
        'label': label,
        'unit': unit,
        'kind': kind.name,
      };

  static HealthField? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final key = raw['key'];
    final label = raw['label'];
    if (key is! String || label is! String || key.isEmpty) return null;
    return HealthField(
      key: key,
      label: label,
      unit: raw['unit'] is String ? raw['unit'] as String : '',
      kind: HealthFieldKind.values.firstWhere(
        (k) => k.name == raw['kind'],
        orElse: () => HealthFieldKind.number,
      ),
    );
  }
}

const String stepsFieldKey = 'steps';
const String injectionFieldKey = 'injection';

/// Presets offered in Settings (DESIGN §9.3 examples, plus steps).
const List<HealthField> healthPresets = <HealthField>[
  HealthField(key: stepsFieldKey, label: 'Steps'),
  HealthField(key: 'glucose', label: 'Glucose', unit: 'mmol/L'),
  HealthField(key: 'time_in_range', label: 'Time in range', unit: '%'),
  HealthField(key: 'weight', label: 'Weight', unit: 'kg'),
  HealthField(
    key: injectionFieldKey,
    label: 'Weekly injection',
    kind: HealthFieldKind.check,
  ),
];

/// DESIGN §14: the default is steps plus the presets, all optional.
List<HealthField> defaultHealthFields() => List<HealthField>.of(healthPresets);

String encodeHealthFields(List<HealthField> fields) =>
    jsonEncode(<Map<String, Object>>[for (final f in fields) f.toJson()]);

List<HealthField> decodeHealthFields(String? json) {
  if (json == null || json.isEmpty) return defaultHealthFields();
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return defaultHealthFields();
  }
  if (raw is! List) return defaultHealthFields();
  return <HealthField>[
    for (final item in raw)
      if (HealthField.fromJson(item) != null) HealthField.fromJson(item)!,
  ];
}

/// A storage key for a field the user names themselves: lower-case words
/// joined by underscores, never clashing with one already in use.
String healthKeyFor(String label, Iterable<String> taken) {
  final words = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final base = words.isEmpty ? 'field' : words.join('_');
  var key = base;
  var n = 2;
  while (taken.contains(key)) {
    key = '${base}_$n';
    n++;
  }
  return key;
}

/// How a ticked check field is stored: the tick, and the note if one was
/// typed (e.g. a dose).
const String checkDone = 'Done';

String encodeCheck(String note) {
  final text = note.trim();
  return text.isEmpty ? checkDone : '$checkDone ($text)';
}

/// The note inside a stored check value; empty when there was none.
String decodeCheck(String value) {
  final text = value.trim();
  if (text == checkDone) return '';
  if (text.startsWith('$checkDone (') && text.endsWith(')')) {
    return text.substring(checkDone.length + 2, text.length - 1);
  }
  return text;
}
