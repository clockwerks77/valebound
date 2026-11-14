# ASSETS

What art exists, how each piece is made, and what is needed from Adam.
Follows DESIGN §13 "Asset & tool pipeline". Style reference: `docs/STYLE.md`.
Every illustrated asset uses the **style prompt in STYLE.md §6 verbatim**,
followed by its own `Subject:` line.

## Tool audit (what Claude's build environment actually has)

| Capability | Available? | Notes |
|---|---|---|
| Image generation (any model) | **No** | No image-generation tool or MCP is connected. |
| Blender / 3D | **No** | Not installed, not connected, not wanted (DESIGN §13). |
| Rive | **No** | Animation is done in Flutter. |
| Vector drawing in code | Yes | Flutter `CustomPaint`, SVG path data. |
| Code-painted raster | Yes | Python (Pillow), ImageMagick, rsvg. Good for textures, gradients, terrain and light. Not good enough for premium portraits or scenes. |
| Fonts | Yes | Fraunces and Figtree, SIL OFL 1.1, bundled. |
| Adam's PC and Chrome | With per-app / per-site approval | Nothing used for art so far. |
| Image connectors offered (Adobe, Hugging Face) | **Not connected** | Suggested to Adam on 13 Nov 2026. Either could generate the painted pieces; which image tools each exposes can only be confirmed once connected. |

**Consequence:** I can deliver everything vector, coded and animated myself.
I cannot produce the painterly raster illustration the design calls for.
Those assets are marked **needed-from-Adam** below with exact sizes, and
Phases 1 and 2 use clearly listed code-drawn stand-ins in their place.
Nothing in the app is a grey box: every stand-in is drawn, on-palette and
listed in section 2.

Status values: `generated` · `coded` · `placeholder` · `needed-from-Adam`.

## 1. Coded and vector (done by Claude)

| Asset | Where | Format | Status |
|---|---|---|---|
| Icon set, 68 icons (navigation, attributes, quest icons, rewards, places, gear, settings) | `lib/ui/widgets/v_icon.dart` | SVG path data, 24-unit grid | coded |
| Buttons, cards, pills, XP bars, roundels | `lib/ui/widgets/common.dart` | Flutter widgets | coded |
| Completion ring, reward chips, XP bar glide | `lib/ui/board/quest_actions.dart`, `lib/ui/celebrations.dart` | Flutter animation | coded |
| Hero level-up fanfare (rays, motes) | `lib/ui/celebrations.dart` | `CustomPaint` animation | coded |
| Companion level-up and Discovery cards | `lib/ui/celebrations.dart` | Flutter | coded |
| Restoration card ("a place wakes") | `lib/ui/celebrations.dart` | Flutter | coded |
| Map motion: fog lifting as a region wakes, the camp walking to its new spot, gold road dots | `lib/ui/map/vale_map.dart` | `CustomPaint` animation | coded |
| Journey road, Discovery lanterns, camp marker, place medallions, Scout marker | `lib/ui/map/vale_map.dart` | `CustomPaint` | coded (these stay coded on top of any painted map) |
| Undo ring (five-second countdown) | `lib/ui/board/quest_actions.dart` | `CustomPaint` animation | coded |
| Fonts: Fraunces SemiBold/Bold, Figtree Regular–Bold | `assets/fonts/` | TTF, OFL 1.1 | bundled |
| Launcher icon: gold lantern on forest green (adaptive + legacy) | `android/app/src/main/res/` | PNG rendered from SVG, 432×432 foreground | coded |

## 2. Stand-ins (code-drawn, to be replaced by painted art)

These are original and on-palette, but they are **not** the painterly
illustration in the design. Each has a matching entry in section 3.

| Stand-in | Where | Replaces | Since | Status |
|---|---|---|---|---|
| Hero crests ×4 (hooded figure medallions) | `lib/ui/art/crests.dart` | Hero portraits | Phase 1 | placeholder |
| Companion crests ×6 (Hound, Cat, Fox, Owl, Hare, Clockwork Sprite) | `lib/ui/art/crests.dart` | Companion portraits | Phase 1 | placeholder |
| Dawn valley vista (sky, sun, ridges, mist, lanterns) | `lib/ui/art/vista.dart` | Dawn header scene, onboarding scene | Phase 1 | placeholder |
| The Vale map: 86 hand-laid shapes on a 400×500 grid (peaks, ruins, river, hills, village, woods), each region draining to grey when asleep | `lib/ui/map/map_art.dart` | Painted map, asleep and awake | Phase 2 | placeholder |
| Fog banks over sleeping regions | `lib/ui/map/vale_map.dart` | Painted fog | Phase 2 | placeholder (may simply stay coded) |
| Place medallions ×20 (an icon in a ring, grey when asleep, gold-lit when restored) | `lib/ui/map/vale_map.dart` | Building art, asleep and restored | Phase 2 | placeholder |
| Villager medallions ×20 (the villager's icon on a green roundel) | `lib/ui/board/board_screen.dart` | Villager portraits | Phase 2 | placeholder |
| Campfire night scene (stars, ridges, fire glow) with the two crests | `lib/ui/campfire/campfire_screen.dart` | Campfire scene | Phase 2 | placeholder |
| Lantern roundel on the Discovery card (same for all 20) | `lib/ui/celebrations.dart` | Discovery scene art | Phase 1 | placeholder |
| Still creatures: a sleepy grey blob on the map, a small icon on the card (same for all 6) | `lib/ui/map/vale_map.dart`, `v_icon.dart` | Still creature art | Phase 2 | placeholder |
| Companion gear: a slot icon (collar, bell, cloak, blanket) as a badge on the portrait | `lib/ui/art/crests.dart` | Gear art per kind | Phase 2 | placeholder |
| Portrait frames: the portrait ring in a different colour | `lib/ui/art/crests.dart` | Frame art | Phase 2 | placeholder (may simply stay coded) |
| Village decorations: small flags, dots and lights on the map | `lib/ui/map/vale_map.dart` | Painted into the awake map | Phase 2 | placeholder |
| "Old Friends" scene: the two crests side by side | `lib/ui/party/party_sheet.dart` | Hero + companion portrait scene (companion L10) | Phase 2 | placeholder |

## 3. Illustrated raster assets (needed from Adam)

Deliver as **PNG or WebP, sRGB, no text baked in**, into
`assets/art/<folder>/` with the exact filenames below. Sizes are final pixel
sizes; anything larger at the same aspect ratio is fine and I will resize.
The largest on-screen use on the Fold 8 is noted so nothing ships oversized.

### Needed first: the reference board (STYLE.md §7)

| File | Size | Subject line to append to the style prompt | Status |
|---|---|---|---|
| `portraits/companion_hound.png` | 1024×1024 | `Subject: head-and-shoulders portrait of a friendly tricolour hound with soft drooping ears, looking toward the viewer, centred, plain soft-focus meadow background.` | needed-from-Adam |
| `portraits/hero_wayfarer.png` | 1024×1024 | `Subject: head-and-shoulders portrait of a traveller in a deep green hooded cloak with a small gold leaf clasp, calm expression, centred, plain soft-focus background.` | needed-from-Adam |
| `discoveries/standing_stone.png` | 1200×800 | `Subject: a tall weathered standing stone beside a country road at dawn, one side lit warm, wildflowers at its base.` | needed-from-Adam |

Once these three are approved they become the reference every later asset
is checked against.

### Portraits (shown up to 132dp; shipped at 512×512)

| File | Size | Subject | Status |
|---|---|---|---|
| `portraits/hero_lamplighter.png` | 1024×1024 | traveller in an amber cloak carrying a small glass lantern | needed-from-Adam |
| `portraits/hero_riverwarden.png` | 1024×1024 | traveller in a river-blue cloak with a reed-and-wave clasp | needed-from-Adam |
| `portraits/hero_emberkeeper.png` | 1024×1024 | traveller in a rust-red cloak warmed by firelight | needed-from-Adam |
| `portraits/companion_cat.png` | 1024×1024 | a composed grey cat with gold eyes | needed-from-Adam |
| `portraits/companion_fox.png` | 1024×1024 | a bright-eyed red fox with a white chest | needed-from-Adam |
| `portraits/companion_owl.png` | 1024×1024 | a small brown owl with large amber eyes | needed-from-Adam |
| `portraits/companion_hare.png` | 1024×1024 | a sandy-brown hare with tall ears | needed-from-Adam |
| `portraits/companion_clockwork_sprite.png` | 1024×1024 | a small brass clockwork sprite with a wind-up key, glass wings and gentle teal-lit eyes | needed-from-Adam |

### Scenes

| File | Size | Subject | Status |
|---|---|---|---|
| `scenes/dawn_header.png` | 1600×1100 | wide view down a sleeping valley at dawn: layered hills, a small village with a few lit lanterns, low sun, mist | needed-from-Adam |
| `scenes/campfire.png` | 1600×1000 | a small camp beside a country road at dusk: a fire, a bedroll, a lantern on a post; space left and right of the fire for two figures | needed-from-Adam |
| `scenes/old_friends.png` | 1600×1000 | a traveller and their animal companion sitting side by side on a hill at dusk, seen from behind, lanterns of a valley below | needed-from-Adam (companion L10; far off) |

### The map (portrait, 4:5, to match the coded layout)

The coded map is 400×500 units. Painted replacements must keep the same
composition so the road, lanterns, camp and place medallions (which stay
coded) land in the right spots: **peaks top-left, ruins top-right, river
across the middle, hills centre-right, village bottom-left.** A print of the
coded map (`docs/screenshots/phase-2/map-cover.png`) is the layout guide.

| File | Size | Subject | Status |
|---|---|---|---|
| `map/vale_asleep.png` | 1600×2000 | hand-drawn-feeling painted map of a valley seen from above: snowy peaks top-left, pale stone ruins top-right, a river crossing the middle, rolling hills centre-right, a village bottom-left; muted, grey, misted, asleep; no road, no labels | needed-from-Adam |
| `map/vale_awake.png` | 1600×2000 | the same map, same composition exactly, fully coloured and warmly lit | needed-from-Adam |

Regions wake one at a time, so the app will fade from the asleep painting to
the awake one inside each region's outline (the outlines are already in
`map_art.dart`). Two paintings are enough; no per-region files are needed.

### Discoveries (20 scenes, shown on a card up to 360dp wide)

1200×800 each, `discoveries/<key>.png`. Keys, titles and one-line
descriptions are in `lib/rules/journey.dart`; the Subject line is the
description there. Keys: standing_stone, hot_spring, merchant_cart,
lantern_tree, beehive_wall, wind_chimes, shepherd_hut, mile_marker,
stepping_stones, reed_flute, star_pool, otter_slide, cloud_bench, watchtower,
echo_stone, snowbell, garden_gate, sundial, glass_stair, first_lantern.
Status: needed-from-Adam (all 20; `standing_stone` is on the reference board).

### Places (20, shown as a medallion on the map and on the restoration card)

512×512 each, `places/<key>.png`, one **restored** painting per place (the
asleep state is the same painting drained to grey in code, as the map
does). Keys and names are in `lib/rules/world.dart`: gate_lantern,
village_well, bakehouse, moot_hall, sheepfold, larkdown_mill, hill_beacon,
orchard, heron_bridge, wheelhouse, boathouse, ford_bell, waystation, ropeway,
star_loft, summit_cairn, great_arch, reading_room, glasshouse, lanternhall.
Subject: the place by name, small and centred, in its region's setting.
Status: needed-from-Adam.

### Villagers (20, shown at 40dp on the board and at the Campfire)

512×512 each, `villagers/<key>.png`, head-and-shoulders. Names and roles are
in `lib/rules/world.dart` (Wick the lamplighter, Marla the well-keeper, Bryn
the baker, …). Status: needed-from-Adam. Low priority: at 40dp the coded
medallion reads well.

### The Still (6 creatures)

512×512 each, transparent background, `still/<key>.png`: drowsel, mistling,
hushmoth, yawnstone, dozewisp, fogfinch. Subject: a small, round, grey,
sleepy creature, soft and harmless, eyes closed. Never frightening.
Status: needed-from-Adam.

### Companion gear (11 pieces)

256×256 each, transparent background, `gear/<key>.png`: moss_neckerchief,
brass_bell, hearth_blanket, trail_cloak, lantern_charm, silver_bell,
star_blanket, dawn_cloak, golden_tag, song_bell, old_road_cloak. One
painting per piece, shown beside the portrait. DESIGN §7A.3 asks for
variants per companion kind (66 paintings); that is a later pass if wanted.
Status: needed-from-Adam.

### App icon

| File | Size | Notes | Status |
|---|---|---|---|
| `icon/launcher_foreground.png` | 432×432, transparent, subject inside the centre 264×264 | a gold lantern, or the hound's head | optional: a coded lantern icon ships now |
| Background | solid `#12352C` | set in code | coded |

## 4. Ways to get the illustrated assets

1. **A connector generates them.** Adobe or Hugging Face, connected to
   Claude (offered 13 Nov 2026). I would generate the three reference-board
   pieces first, show them, and only roll out the rest once the look is
   approved. Images are bundled at build time; the app stays offline.
2. **You generate them** in whatever image tool you use, pasting the style
   prompt and each Subject line, and drop the files into the repo.
3. **I drive an image tool you are signed in to**, in your Chrome, if you
   name it and say go. It would use your account and any credits it charges.
4. **Stay code-drawn.** Consistent and free, but it reads as stylised
   vector, not painterly.

Swapping is a contained change whichever you choose: every portrait, scene
and medallion is drawn by one widget each (`HeroPortrait`,
`CompanionPortrait`, `Vista`, `ValeMap`, `CampScene`), so raster art replaces
the stand-in in one place. That swap is not built yet; it comes with the
first delivered files.

## 5. Suggested order

Reference board (3) → remaining portraits (8) → the two map paintings →
Campfire and Dawn scenes → Discoveries (19 more) → places (20) → the Still
(6) → gear (11) → villagers (20).
