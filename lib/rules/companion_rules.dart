/// Companion tricks, Bond milestones and hero titles.
library;

import 'day_key.dart';
import 'enums.dart';

/// DESIGN §7A.3: tricks unlock at companion levels 2, 4, 6, 8 and 10.
/// They are deterministic and never withhold anything.
class Trick {
  const Trick(this.key, this.name, this.level, this.description);
  final String key;
  final String name;
  final int level;
  final String description;
}

const List<Trick> companionTricks = <Trick>[
  Trick(
    'sniff_out',
    'Sniff Out',
    2,
    'On days a companion quest is done, your companion finds one bonus '
        'material.',
  ),
  Trick(
    'fetch',
    'Fetch',
    4,
    'The first companion quest each day also carries one material to the '
        'current restoration.',
  ),
  Trick(
    'scout',
    'Scout',
    6,
    'The Journey road shows the next discovery as a silhouette.',
  ),
  Trick(
    'comfort',
    'Comfort',
    8,
    'After time away, your companion keeps the camp warm and welcomes you '
        'home.',
  ),
  Trick(
    'old_friend',
    'Old Friend',
    10,
    'A portrait of the two of you for the Party Sheet and the Campfire.',
  ),
];

/// Tricks whose effect is live in this build. Comfort unlocks on schedule
/// and comes into play with the comeback quest (DECISIONS.md D-28).
const Set<String> tricksInPlay = <String>{
  'sniff_out',
  'fetch',
  'scout',
  'old_friend',
};

/// Companion levels at which each trick is learned (DESIGN §7A.3).
const int sniffOutLevel = 2;
const int fetchLevel = 4;
const int scoutLevel = 6;
const int comfortLevel = 8;
const int oldFriendLevel = 10;

/// Sniff Out finds one bonus material on a day a companion quest is done.
/// The kind rotates by calendar day, so it is the same however the day goes.
MaterialKind sniffOutMaterial(String day) {
  const kinds = MaterialKind.values;
  final index = DayKey.daysBetween('2026-01-01', day) % kinds.length;
  return kinds[index < 0 ? index + kinds.length : index];
}

/// Keys of the tricks a companion of [level] has unlocked, in order.
List<String> tricksUnlockedAt(int level) => <String>[
      for (final t in companionTricks)
        if (level >= t.level) t.key,
    ];

/// Bond values at which a Companion Gift unlocks: a piece of gear
/// (see `gear.dart`).
const List<int> bondMilestones = <int>[10, 25, 50, 100, 175, 275, 400];

/// The next milestone above [bond], or null once all are reached.
int? nextBondMilestone(int bond) {
  for (final m in bondMilestones) {
    if (bond < m) return m;
  }
  return null;
}

/// The milestone most recently reached, or 0.
int previousBondMilestone(int bond) {
  var prev = 0;
  for (final m in bondMilestones) {
    if (bond >= m) prev = m;
  }
  return prev;
}

/// Hero titles by level (DESIGN §5.3; "Vale Walker" at L5 is from the
/// design, the rest are drafted in the same warm tone).
class HeroTitle {
  const HeroTitle(this.level, this.title);
  final int level;
  final String title;
}

const List<HeroTitle> heroTitles = <HeroTitle>[
  HeroTitle(1, 'Newcomer to the Vale'),
  HeroTitle(2, 'Lantern Bearer'),
  HeroTitle(3, 'Path Finder'),
  HeroTitle(5, 'Vale Walker'),
  HeroTitle(7, 'Hearth Keeper'),
  HeroTitle(10, 'Friend of the Waking Vale'),
  HeroTitle(13, 'Bridge Mender'),
  HeroTitle(16, 'Keeper of Lanterns'),
  HeroTitle(20, 'Warden of the Vale'),
  HeroTitle(25, 'Dawnbringer'),
];

/// The title held at [level].
String titleForLevel(int level) {
  var current = heroTitles.first.title;
  for (final t in heroTitles) {
    if (level >= t.level) current = t.title;
  }
  return current;
}

/// The title newly earned on reaching exactly [level], if any.
String? titleUnlockedAt(int level) {
  for (final t in heroTitles) {
    if (t.level == level) return t.title;
  }
  return null;
}

/// All titles earned up to [level], oldest first.
List<String> titlesEarned(int level) => <String>[
      for (final t in heroTitles)
        if (level >= t.level) t.title,
    ];
