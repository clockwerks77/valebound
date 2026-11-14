/// Calendar suggestions (DESIGN §9.3): telling when two calendar entries are
/// one event, and when an event repeats a quest already on today's board.
/// Text and time only; nothing here touches the calendar.
library;

/// Small words that say nothing about what an event is.
const Set<String> _fillerWords = <String>{
  'a',
  'an',
  'and',
  'at',
  'for',
  'in',
  'my',
  'of',
  'on',
  'the',
  'to',
  'with',
};

/// The words of a title or quest name: lower case, letters and digits only.
List<String> titleWords(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true))
    .where((w) => w.isNotEmpty)
    .toList();

/// One key for "the same event": the same words in the title, the same start
/// and the same end. One event often sits in two calendars (your own and a
/// shared one), and should be offered once.
String eventKey({
  required String title,
  required DateTime begin,
  required DateTime end,
  required bool allDay,
}) =>
    '${titleWords(title).join(' ')}|${begin.millisecondsSinceEpoch}|'
    '${end.millisecondsSinceEpoch}|$allDay';

Set<String> _meaningWords(String text) =>
    titleWords(text).where((w) => !_fillerWords.contains(w)).toSet();

/// At least one word long enough to mean something by itself.
bool _telling(Set<String> words) => words.any((w) => w.length >= 4);

/// The first of [questNames] that an event titled [eventTitle] looks to be
/// about, or null.
///
/// They match when every meaningful word of one is among the words of the
/// other: "Mounjaro" and "Weekly Injection (Mounjaro)", or "Walk with Babs"
/// and "Walk Babs". This only ever feeds a hint on the suggestion card. It
/// never hides a suggestion and never decides anything.
String? questMatching(String eventTitle, Iterable<String> questNames) {
  final event = _meaningWords(eventTitle);
  if (!_telling(event)) return null;
  for (final name in questNames) {
    final quest = _meaningWords(name);
    if (!_telling(quest)) continue;
    if (quest.containsAll(event) || event.containsAll(quest)) return name;
  }
  return null;
}
