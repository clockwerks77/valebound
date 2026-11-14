/// Companion gear and hero cosmetics (DESIGN §5.3, §7A.3).
///
/// Cosmetic only. Nothing here has stats and nothing gates a function.
/// Everything unlocks from a level, a Bond milestone or a count of restored
/// places, so what is unlocked is a pure function of progress that only
/// ever grows.
library;

enum GearSlot {
  collar('Collar'),
  bell('Bell'),
  cloak('Cloak'),
  blanket('Blanket');

  const GearSlot(this.label);
  final String label;
}

class GearItem {
  const GearItem({
    required this.key,
    required this.name,
    required this.slot,
    required this.line,
    this.bond,
    this.level,
  });
  final String key;
  final String name;
  final GearSlot slot;
  final String line;

  /// Unlocks at this Bond milestone (a Companion Gift), or
  final int? bond;

  /// at this companion level.
  final int? level;

  String get icon => switch (slot) {
        GearSlot.collar => 'collar',
        GearSlot.bell => 'bell',
        GearSlot.cloak => 'cloak',
        GearSlot.blanket => 'blanket',
      };

  /// e.g. "Bond 25" or "Level 5".
  String get unlocksAt => bond != null ? 'Bond $bond' : 'Level $level';
}

/// Gifts arrive at each Bond milestone; the odd companion levels between
/// tricks bring a piece of gear too. Names suit any kind of companion.
const List<GearItem> companionGear = <GearItem>[
  GearItem(
    key: 'moss_neckerchief',
    name: 'Moss Neckerchief',
    slot: GearSlot.collar,
    line: 'Soft green cloth, knotted for the road.',
    bond: 10,
  ),
  GearItem(
    key: 'brass_bell',
    name: 'Brass Bell',
    slot: GearSlot.bell,
    line: 'A small bright note at every step.',
    level: 3,
  ),
  GearItem(
    key: 'hearth_blanket',
    name: 'Hearth Blanket',
    slot: GearSlot.blanket,
    line: 'Warm from the fire, and theirs alone.',
    bond: 25,
  ),
  GearItem(
    key: 'trail_cloak',
    name: 'Trail Cloak',
    slot: GearSlot.cloak,
    line: 'Keeps off the drizzle on long stretches.',
    level: 5,
  ),
  GearItem(
    key: 'lantern_charm',
    name: 'Lantern Charm',
    slot: GearSlot.collar,
    line: 'A thumb-sized lantern that glows at dusk.',
    bond: 50,
  ),
  GearItem(
    key: 'silver_bell',
    name: 'Silver Bell',
    slot: GearSlot.bell,
    line: 'Rings clear as the Silverrun.',
    level: 7,
  ),
  GearItem(
    key: 'star_blanket',
    name: 'Star-stitched Blanket',
    slot: GearSlot.blanket,
    line: 'Every stitch a small constellation.',
    bond: 100,
  ),
  GearItem(
    key: 'dawn_cloak',
    name: 'Dawn Cloak',
    slot: GearSlot.cloak,
    line: 'The colour of first light over Larkdown.',
    level: 9,
  ),
  GearItem(
    key: 'golden_tag',
    name: 'Golden Name Tag',
    slot: GearSlot.collar,
    line: 'Their name, engraved by Hal at the Great Arch.',
    bond: 175,
  ),
  GearItem(
    key: 'song_bell',
    name: 'Song Bell',
    slot: GearSlot.bell,
    line: 'It hums a little tune when the wind turns.',
    bond: 275,
  ),
  GearItem(
    key: 'old_road_cloak',
    name: 'Cloak of the Old Road',
    slot: GearSlot.cloak,
    line: 'Worn soft by every Pace you have walked together.',
    bond: 400,
  ),
];

GearItem? gearByKey(String? key) {
  if (key == null) return null;
  for (final g in companionGear) {
    if (g.key == key) return g;
  }
  return null;
}

/// Keys of the gear unlocked at [level] and [bond], in list order.
List<String> gearUnlockedAt({required int level, required int bond}) =>
    <String>[
      for (final g in companionGear)
        if ((g.bond != null && bond >= g.bond!) ||
            (g.level != null && level >= g.level!))
          g.key,
    ];

enum CosmeticKind {
  frame('Portrait frames'),
  banner('Banner colours'),
  decoration('Village decorations');

  const CosmeticKind(this.label);
  final String label;
}

class Cosmetic {
  const Cosmetic({
    required this.key,
    required this.kind,
    required this.name,
    required this.line,
    this.heroLevel,
    this.restored,
  });
  final String key;
  final CosmeticKind kind;
  final String name;
  final String line;

  /// Unlocks at this hero level, or
  final int? heroLevel;

  /// once this many places are restored.
  final int? restored;

  String get unlocksAt => heroLevel != null
      ? 'Level $heroLevel'
      : '$restored ${restored == 1 ? 'place' : 'places'} restored';
}

const String defaultFrame = 'traveller';
const String defaultBanner = 'forest';

const List<Cosmetic> heroCosmetics = <Cosmetic>[
  // Portrait frames
  Cosmetic(
    key: 'traveller',
    kind: CosmeticKind.frame,
    name: 'Traveller’s Ring',
    line: 'Plain gold, the way everyone starts.',
    heroLevel: 1,
  ),
  Cosmetic(
    key: 'oak',
    kind: CosmeticKind.frame,
    name: 'Oak Frame',
    line: 'Carved with leaves from the Lantern Oak.',
    heroLevel: 3,
  ),
  Cosmetic(
    key: 'riverstone',
    kind: CosmeticKind.frame,
    name: 'Riverstone Frame',
    line: 'Smooth grey-blue stone from the Silverrun.',
    heroLevel: 6,
  ),
  Cosmetic(
    key: 'gilded',
    kind: CosmeticKind.frame,
    name: 'Gilded Frame',
    line: 'Bright as the hall banners.',
    heroLevel: 10,
  ),
  Cosmetic(
    key: 'starlit',
    kind: CosmeticKind.frame,
    name: 'Starlit Frame',
    line: 'Set with shards that catch the evening.',
    heroLevel: 15,
  ),
  // Banner colours
  Cosmetic(
    key: 'forest',
    kind: CosmeticKind.banner,
    name: 'Forest Banner',
    line: 'Deep green, the colour of the Vale.',
    heroLevel: 1,
  ),
  Cosmetic(
    key: 'dawn',
    kind: CosmeticKind.banner,
    name: 'Dawn Banner',
    line: 'Peach and rose, like first light.',
    heroLevel: 2,
  ),
  Cosmetic(
    key: 'river',
    kind: CosmeticKind.banner,
    name: 'River Banner',
    line: 'Silver-blue, for long steady days.',
    heroLevel: 4,
  ),
  Cosmetic(
    key: 'ember',
    kind: CosmeticKind.banner,
    name: 'Ember Banner',
    line: 'Warm as the campfire.',
    heroLevel: 8,
  ),
  Cosmetic(
    key: 'gold',
    kind: CosmeticKind.banner,
    name: 'Gold Banner',
    line: 'For a friend of the waking Vale.',
    heroLevel: 12,
  ),
  // Village decorations, drawn on the map as the Vale wakes
  Cosmetic(
    key: 'bunting',
    kind: CosmeticKind.decoration,
    name: 'Bunting on the Green',
    line: 'Little flags strung across Hearthmere.',
    restored: 2,
  ),
  Cosmetic(
    key: 'flower_boxes',
    kind: CosmeticKind.decoration,
    name: 'Flower Boxes',
    line: 'Every sill in the village in bloom.',
    restored: 5,
  ),
  Cosmetic(
    key: 'market_awnings',
    kind: CosmeticKind.decoration,
    name: 'Market Awnings',
    line: 'Striped cloth over the market stalls.',
    restored: 9,
  ),
  Cosmetic(
    key: 'lantern_strings',
    kind: CosmeticKind.decoration,
    name: 'Lantern Strings',
    line: 'Small lights along the river road.',
    restored: 14,
  ),
  Cosmetic(
    key: 'great_banner',
    kind: CosmeticKind.decoration,
    name: 'The Great Banner',
    line: 'Flown from Old Lanternhall for the whole Vale to see.',
    restored: 20,
  ),
];

Cosmetic? cosmeticByKey(String? key) {
  if (key == null) return null;
  for (final c in heroCosmetics) {
    if (c.key == key) return c;
  }
  return null;
}

/// Keys of the cosmetics unlocked at [heroLevel] with [restored] places
/// awake, in list order.
List<String> cosmeticsUnlockedAt({
  required int heroLevel,
  required int restored,
}) =>
    <String>[
      for (final c in heroCosmetics)
        if ((c.heroLevel != null && heroLevel >= c.heroLevel!) ||
            (c.restored != null && restored >= c.restored!))
          c.key,
    ];
