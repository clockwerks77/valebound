/// The narrator (DESIGN §7, amendment of 14 Nov 2026; DECISIONS D-76).
///
/// An unnamed storyteller who speaks to the player in the second person and
/// the present tense: calm, plain, a little lyrical. The narrator says where
/// the player is and what is happening around them. The villagers keep
/// their own one-line voices (see `world.dart`).
///
/// Everything here is words worked out from what has already happened.
/// Nothing is stored, nothing is scored, and no line depends on the player
/// having been there to read an earlier one.
library;

import 'day_key.dart';
import 'journey.dart';
import 'world.dart';

// ---- The prologue ---------------------------------------------------------

/// What a story page is about, so the right picture can sit above it.
enum StoryScene { lastHill, sleepingVale, gateLantern, stillness, road }

class StoryPage {
  const StoryPage(this.scene, this.text);
  final StoryScene scene;
  final String text;
}

/// How many of the prologue's pages are the arrival itself. The rest say
/// what the Vale is and what the player's days do for it.
const int prologueArrivalPages = 3;

/// Told once, on the first run, before the tour of the board.
List<StoryPage> prologuePages(String companionName) => <StoryPage>[
      StoryPage(
        StoryScene.lastHill,
        'You come over the last hill at first light, and $companionName is '
        'already ahead of you.',
      ),
      const StoryPage(
        StoryScene.sleepingVale,
        'Below lies the Vale. It should be full of lantern light. It is '
        'grey, and very quiet.',
      ),
      const StoryPage(
        StoryScene.gateLantern,
        'One lantern still burns, at the gate.',
      ),
      const StoryPage(
        StoryScene.stillness,
        'Nobody has gone away. They are asleep, and the Vale with them, '
        'under a grey stillness. It will wake the way you do: a little at a '
        'time.',
      ),
      StoryPage(
        StoryScene.road,
        'Whatever you finish in your own day comes back here as timber, '
        'stone and light. Whatever you do with $companionName carries you '
        'both along the road. Begin at the gate.',
      ),
    ];

// ---- Chapters -------------------------------------------------------------

/// One chapter to a region, in the order the regions wake.
class Chapter {
  const Chapter({
    required this.number,
    required this.numeral,
    required this.region,
    required this.opens,
    required this.wakes,
  });

  final int number;

  /// The number as a word: "One".
  final String numeral;

  /// Key of the region this chapter wakes.
  final String region;

  /// Told as the work turns to this region, while it is still asleep.
  final String opens;

  /// Told when its last place wakes.
  final String wakes;

  String get regionName => regionByKey(region).name;

  /// "Chapter One".
  String get label => 'Chapter $numeral';

  /// "Chapter One · Hearthmere".
  String get heading => '$label · $regionName';
}

const List<Chapter> chapters = <Chapter>[
  Chapter(
    number: 1,
    numeral: 'One',
    region: 'hearthmere',
    opens: 'Hearthmere, the village at the valley mouth. The doors are shut '
        'and the chimneys are cold. At the gate, one lantern burns low.',
    wakes: 'Hearthmere is awake. There is light at the gate, water in the '
        'well, bread in the oven and talk in the Moot Hall. From the green, '
        'the road climbs toward the hills.',
  ),
  Chapter(
    number: 2,
    numeral: 'Two',
    region: 'larkdown',
    opens: 'The road climbs out of the village into Larkdown: green hills, '
        'long views, and not a sound on them. Mist lies in the fold. The '
        'mill sails hang still.',
    wakes: 'Larkdown is awake. The sails turn, the beacon answers the Gate '
        'Lantern, and the orchard is loud with bees. Below the hills a '
        'river lies still and silver, waiting.',
  ),
  Chapter(
    number: 3,
    numeral: 'Three',
    region: 'silverrun',
    opens: 'The Silverrun runs through the heart of the Vale, slow as '
        'glass. The footbridge is down to its posts. The great wheel '
        'stands still. Even the herons are asleep on one leg.',
    wakes: 'The Silverrun is awake. The wheel turns, boats knock at their '
        'moorings, and the Ford Bell rings travellers across. Upstream, '
        'the water comes down cold from the peaks.',
  ),
  Chapter(
    number: 4,
    numeral: 'Four',
    region: 'highcairn',
    opens: 'The high road. Highcairn is stone and sky, and the stillness '
        'lies deep here, like snow that never fell. The Waystation door '
        'stands open on a cold hearth.',
    wakes: 'Highcairn is awake. There is a kettle on at the Waystation, the '
        'Ropeway hums, and from the Summit Cairn you can count every '
        'lantern you have lit. Beyond the pass, one valley is dark.',
  ),
  Chapter(
    number: 5,
    numeral: 'Five',
    region: 'lanternhall',
    opens: 'Beyond the pass lies Old Lanternhall, where the lanterns of the '
        'Vale were first made. The arch is down. The glass is dull. The '
        'grey lies thickest here, and this is the last of it.',
    wakes: 'Old Lanternhall is awake, and the Vale with it. Light runs from '
        'the gate to the peaks, and there is somebody home at every door. '
        'The road goes on. There is always one more lantern to light.',
  ),
];

/// True once every drafted place is awake.
bool valeIsAwake(int restored) => restored >= restorationTargets.length;

/// The chapter being told once [restored] places are awake. After the last
/// drafted place it stays the last chapter.
Chapter chapterAt(int restored) {
  if (restored <= 0) return chapters.first;
  if (valeIsAwake(restored)) return chapters.last;
  final region = restorationTargets[restored].region;
  return chapters.firstWhere(
    (c) => c.region == region,
    orElse: () => chapters.first,
  );
}

/// The chapter that ends when the place at [index] wakes, or null when
/// that place is not the last of its region.
Chapter? chapterClosedBy(int index) {
  if (index < 0 || index >= restorationTargets.length) return null;
  final region = restorationTargets[index].region;
  final last = index == restorationTargets.length - 1 ||
      restorationTargets[index + 1].region != region;
  if (!last) return null;
  for (final c in chapters) {
    if (c.region == region) return c;
  }
  return null;
}

/// The chapter after [chapter], or null after the last.
Chapter? chapterAfter(Chapter chapter) =>
    chapter.number < chapters.length ? chapters[chapter.number] : null;

/// Places of [chapter]'s region that are awake, of how many.
({int awake, int of}) chapterProgress(Chapter chapter, int restored) {
  var total = 0;
  var awake = 0;
  for (var i = 0; i < restorationTargets.length; i++) {
    if (restorationTargets[i].region != chapter.region) continue;
    total++;
    if (i < restored) awake++;
  }
  return (awake: awake, of: total);
}

/// The line over the story: "Chapter Two · Larkdown", or the afterword's.
String storyHeading(int restored) =>
    valeIsAwake(restored) ? 'The Vale awake' : chapterAt(restored).heading;

// ---- The Dawn line --------------------------------------------------------

enum PartOfDay {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening'),
  night('Night');

  const PartOfDay(this.label);
  final String label;
}

PartOfDay partOfDay(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return PartOfDay.morning;
  if (h >= 12 && h < 17) return PartOfDay.afternoon;
  if (h >= 17 && h < 22) return PartOfDay.evening;
  return PartOfDay.night;
}

/// "in Hearthmere", "on the Silverrun".
const Map<String, String> _where = <String, String>{
  'hearthmere': 'in Hearthmere',
  'larkdown': 'in Larkdown',
  'silverrun': 'on the Silverrun',
  'highcairn': 'in Highcairn',
  'lanternhall': 'in Old Lanternhall',
};

/// What the air is like, three ways to a region. True at any hour and
/// whether the region is asleep or awake.
const Map<String, List<String>> _air = <String, List<String>>{
  'hearthmere': <String>[
    'Mist lies on the green.',
    'The lane is quiet and gold with light.',
    'Swallows stitch the air above the roofs.',
  ],
  'larkdown': <String>[
    'Wind runs silver through the long grass.',
    'Cloud shadows cross the hills, slow as sheep.',
    'The air smells of thyme and rain.',
  ],
  'silverrun': <String>[
    'Mist stands on the water.',
    'The river is the colour of the sky.',
    'Reeds lean and whisper along the bank.',
  ],
  'highcairn': <String>[
    'The air is thin and very clear.',
    'Cloud lies in the valleys below like wool.',
    'Frost glitters along the high road.',
  ],
  'lanternhall': <String>[
    'Light falls through the open roofs in long bars.',
    'Ivy stirs on the old walls.',
    'Dust hangs gold in the quiet halls.',
  ],
};

/// What the companion is up to. Written to suit every kind of companion.
const List<String> _companionLines = <String>[
  '{c} is up before you, watching the road.',
  '{c} has found the warm side of the wall.',
  '{c} keeps close today.',
  '{c} has found something worth a second look by the road.',
];

/// How each place is once it is awake, and while it waits its turn.
const Map<String, ({String lit, String waiting})> _places =
    <String, ({String lit, String waiting})>{
  'gate_lantern': (
    lit: 'The Gate Lantern is burning.',
    waiting: 'The Gate Lantern burns low, and waits.',
  ),
  'village_well': (
    lit: 'The well is full.',
    waiting: 'The well is waiting.',
  ),
  'bakehouse': (
    lit: 'There is bread in the Bakehouse.',
    waiting: 'The Bakehouse oven is cold, and waiting.',
  ),
  'moot_hall': (
    lit: 'The Moot Hall doors stand open.',
    waiting: 'The Moot Hall is shuttered, and waiting.',
  ),
  'sheepfold': (
    lit: 'The Sheepfold gate is swinging.',
    waiting: 'The Sheepfold walls are down, and waiting.',
  ),
  'larkdown_mill': (
    lit: 'The sails of Larkdown Mill are turning.',
    waiting: 'The sails of Larkdown Mill hang still, waiting for a wind.',
  ),
  'hill_beacon': (
    lit: 'The Hill Beacon is alight.',
    waiting: 'The Hill Beacon is dark, and waiting.',
  ),
  'orchard': (
    lit: 'The Orchard is in blossom.',
    waiting: 'The Orchard is bare, and waiting.',
  ),
  'heron_bridge': (
    lit: 'The Heron Footbridge is whole again.',
    waiting: 'The Heron Footbridge is down to its posts, and waiting.',
  ),
  'wheelhouse': (
    lit: 'The great wheel of the Wheelhouse is turning.',
    waiting: 'The great wheel of the Wheelhouse stands still, and waits.',
  ),
  'boathouse': (
    lit: 'There are boats out from the Boathouse.',
    waiting: 'The Boathouse doors are shut, and waiting.',
  ),
  'ford_bell': (
    lit: 'The Ford Bell is ringing travellers across.',
    waiting: 'The Ford Bell hangs silent, and waits.',
  ),
  'waystation': (
    lit: 'There is a light in the Waystation window.',
    waiting: 'The Waystation hearth is cold, and waiting.',
  ),
  'ropeway': (
    lit: 'The Ropeway is running.',
    waiting: 'The Ropeway baskets hang still, waiting.',
  ),
  'star_loft': (
    lit: 'The Star Loft roof stands open to the sky.',
    waiting: 'The Star Loft is shut tight, and waiting.',
  ),
  'summit_cairn': (
    lit: 'The Summit Cairn stands above the cloud.',
    waiting: 'The Summit Cairn is a scatter of stones, waiting.',
  ),
  'great_arch': (
    lit: 'The Great Arch is standing.',
    waiting: 'The Great Arch lies in pieces, waiting.',
  ),
  'reading_room': (
    lit: 'There is a lamp on every desk in the Reading Room.',
    waiting: 'The Reading Room is dark, and waiting.',
  ),
  'glasshouse': (
    lit: 'The Glasshouse is green to the roof.',
    waiting: 'The Glasshouse panes are dull, and waiting.',
  ),
  'lanternhall': (
    lit: 'Every lantern in the Lanternhall is lit.',
    waiting: 'The Lanternhall itself is waiting.',
  ),
};

/// How the place at [target] is now that it is awake.
String placeLit(RestorationTarget target) =>
    _places[target.key]?.lit ?? 'The Vale is awake from the gate to the hall.';

/// How the place at [target] is while it waits to be woken.
String placeWaiting(RestorationTarget target) =>
    _places[target.key]?.waiting ?? 'One more lantern waits along the road.';

/// "in Hearthmere" for the region stored under [regionKey].
String whereIn(String regionKey) => _where[regionKey] ?? 'in the Vale';

const List<String> _numberWords = <String>[
  'No',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
  'Twenty',
];

/// A count as the narrator says it: a word up to twenty, figures after.
String numberWord(int n) =>
    (n >= 0 && n < _numberWords.length) ? _numberWords[n] : '$n';

int _dayIndex(String day) {
  final i = DayKey.daysBetween('2026-01-01', day);
  return i < 0 ? -i : i;
}

/// What the narrator says over the board.
class Narration {
  const Narration(this.setting, this.line);

  /// When and where: "Morning in Hearthmere".
  final String setting;

  /// What is happening: "The Gate Lantern is burning. The well is waiting."
  final String line;

  String get full => '$setting. $line';
}

/// The narrator's line for the board (DECISIONS D-76).
///
/// The setting follows the clock and the camp: the part of the day, and the
/// region the road has reached ([paces]). The line says something true of
/// the Vale as it stands, then names the place that is waiting to be woken.
/// It is the same all day and turns with the calendar, so two mornings in a
/// row do not read alike.
///
/// [returning] is for the first board after days away: the narrator says
/// only that the Vale has kept (DESIGN §4.3).
Narration dawnNarration({
  required DateTime now,
  required String day,
  required int restored,
  required int paces,
  required String companionName,
  bool returning = false,
}) {
  final camp = regions[regionIndexForPaces(paces)];
  final setting = '${partOfDay(now).label} ${whereIn(camp.key)}';
  final waiting = placeWaiting(targetAt(restored));
  final i = _dayIndex(day);
  final String first;
  if (returning) {
    first = 'The Vale has kept, just as you left it.';
  } else {
    switch (i % 4) {
      case 0:
        final airs = _air[camp.key] ?? _air['hearthmere']!;
        first = airs[(i ~/ 4) % airs.length];
      case 2:
        first = _companionLines[(i ~/ 4) % _companionLines.length]
            .replaceAll('{c}', companionName);
      case 3:
        first = _awakeCount(restored);
      default:
        first = restored <= 0
            ? 'Every door is shut.'
            : placeLit(targetAt(restored - 1));
    }
  }
  return Narration(setting, '$first $waiting');
}

String _awakeCount(int restored) {
  if (restored <= 0) return 'Every door is shut.';
  if (valeIsAwake(restored)) return 'Every place in the Vale is awake.';
  if (restored == 1) return 'One place is awake in the Vale.';
  return '${numberWord(restored)} places are awake in the Vale.';
}

// ---- The Campfire line ----------------------------------------------------

String _names(List<String> names) {
  if (names.length == 1) return names.first;
  final head = names.sublist(0, names.length - 1).join(', ');
  return '$head and ${names.last}';
}

/// What the narrator says at the Campfire (DECISIONS D-76).
///
/// It names the best thing the day held: a place that woke, the day's
/// creature waking, or simply the quests done. A day with nothing done gets
/// a line as warm as any other; the narrator never counts what was not done
/// (DESIGN §6.4).
String campfireNarration({
  required String day,
  required int questsDone,
  required List<RestorationTarget> wokeToday,
  required String? creatureWoke,
  required String companionName,
  required RestorationTarget next,
}) {
  final String first;
  if (wokeToday.isNotEmpty) {
    final only = wokeToday.length == 1 ? wokeToday.first : null;
    final villager = only?.villager;
    if (only != null && villager != null) {
      first = 'The fire is lit. ${only.name} woke today, and '
          '${villager.name} is home.';
    } else if (only != null) {
      first = 'The fire is lit. One more lantern burns along the road '
          'tonight.';
    } else {
      first = 'The fire is lit. '
          '${_names(<String>[for (final t in wokeToday) t.name])} woke '
          'today.';
    }
  } else if (creatureWoke != null) {
    first = 'The fire is lit. The $creatureWoke woke today and wandered '
        'off into the evening.';
  } else if (questsDone > 0) {
    first = '${numberWord(questsDone)} '
        '${questsDone == 1 ? 'quest' : 'quests'} done, and the fire is '
        'warm.';
  } else {
    first = 'The fire is lit all the same. The Vale keeps, and so does the '
        'road.';
  }
  final String second;
  switch (_dayIndex(day) % 3) {
    case 0:
      second = '$companionName is asleep before the kettle boils.';
    case 1:
      second = '${next.name} will be there in the morning.';
    default:
      second = 'It is quiet in the Vale tonight, the good kind of quiet.';
  }
  return '$first $second';
}

// ---- The Chronicle --------------------------------------------------------

enum ChronicleKind { arrival, chapterOpens, placeWakes, chapterWakes, lanterns }

/// One entry in the story so far.
class ChronicleEntry {
  const ChronicleEntry({
    required this.kind,
    required this.title,
    required this.text,
    this.day,
    this.chapter,
    this.icon,
  });

  final ChronicleKind kind;
  final String title;
  final String text;

  /// The day it happened, where that is on record.
  final String? day;
  final Chapter? chapter;
  final String? icon;
}

/// The story so far, oldest first: the arrival, each chapter as it opened,
/// each place as it woke and who came home, each chapter as it closed.
///
/// Worked out from the record of what has been restored and when
/// ([restoredOn]: place key to day); nothing extra is kept for it.
List<ChronicleEntry> chronicle({
  required String arrivedOn,
  required String companionName,
  required int restored,
  required Map<String, String> restoredOn,
}) {
  final pages = prologuePages(companionName);
  final out = <ChronicleEntry>[
    ChronicleEntry(
      kind: ChronicleKind.arrival,
      title: 'The last hill',
      text: <String>[
        for (var i = 0; i < prologueArrivalPages; i++) pages[i].text,
      ].join(' '),
      day: arrivedOn,
      icon: 'sun',
    ),
    ChronicleEntry(
      kind: ChronicleKind.chapterOpens,
      title: chapters.first.heading,
      text: chapters.first.opens,
      day: arrivedOn,
      chapter: chapters.first,
    ),
  ];
  final drafted = restorationTargets.length;
  for (var i = 0; i < restored && i < drafted; i++) {
    final target = restorationTargets[i];
    final day = restoredOn[target.key];
    final villager = target.villager;
    out.add(
      ChronicleEntry(
        kind: ChronicleKind.placeWakes,
        title: target.name,
        text: villager == null
            ? target.wakes
            : '${target.wakes} ${villager.name} the '
                '${villager.role.toLowerCase()} has come home.',
        day: day,
        chapter: chapterAt(i),
        icon: villager?.icon ?? 'lantern',
      ),
    );
    final closed = chapterClosedBy(i);
    if (closed == null) continue;
    out.add(
      ChronicleEntry(
        kind: ChronicleKind.chapterWakes,
        title: '${closed.regionName} wakes',
        text: closed.wakes,
        day: day,
        chapter: closed,
        icon: 'sun',
      ),
    );
    final next = chapterAfter(closed);
    if (next != null) {
      out.add(
        ChronicleEntry(
          kind: ChronicleKind.chapterOpens,
          title: next.heading,
          text: next.opens,
          day: day,
          chapter: next,
        ),
      );
    }
  }
  final more = restored - drafted;
  if (more > 0) {
    out.add(
      ChronicleEntry(
        kind: ChronicleKind.lanterns,
        title: 'Along the road',
        text: more == 1
            ? 'One more lantern has been lit along the road.'
            : '${numberWord(more)} more lanterns have been lit along the '
                'road.',
        icon: 'lantern',
      ),
    );
  }
  return out;
}
