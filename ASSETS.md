# ASSETS

What art exists, how each piece is made, and what is needed from Adam.
Follows DESIGN §13 "Asset & tool pipeline". Style reference: `docs/STYLE.md`.
Every illustrated asset uses the **style prompt in STYLE.md §6 verbatim**,
followed by its own `Subject:` line.

## Tool audit (what Claude's build environment actually has)

| Capability | Available? | Notes |
|---|---|---|
| Image generation | **Yes, through Adam's Chrome** | Adobe Firefly on the web, model Firefly Image 5, in Adam's Adobe account (Creative Cloud Pro trial from 13 Nov 2026). 10 credits a piece. Nothing in Claude's own environment generates images. |
| Blender / 3D | **No** | Not installed, not connected, not wanted (DESIGN §13). |
| Rive | **No** | Animation is done in Flutter. |
| Vector drawing in code | Yes | Flutter `CustomPaint`, SVG path data. |
| Code-painted raster | Yes | Python (Pillow), ImageMagick, rsvg. Good for textures, gradients, terrain and light. Not good enough for premium portraits or scenes. |
| Fonts | Yes | Fraunces and Figtree, SIL OFL 1.1, bundled. |
| Adam's PC and Chrome | With per-app / per-site approval | Chrome is used to run Firefly, with Adam's go-ahead. No folder on the PC is connected, so files cannot be fetched from it. |
| Adobe connector | Connected 13 Nov 2026 | Finds Firefly generations, previews them (up to 600 pixels), crops, resizes, grades, removes backgrounds. **Cannot generate.** |
| Hugging Face connector | Connected 13 Nov 2026 | Browsing only; running a model is switched off in the built-in connector. Not used. |

**Consequence:** I deliver everything vector, coded and animated myself, and
the illustrated pieces are generated in Firefly with the style prompt in
STYLE.md §6, one at a time, each checked against the reference board. Until a
piece exists the app shows its code-drawn stand-in (section 2). Nothing in
the app is a grey box.

**Getting files into the project.** The cloud workspace cannot reach Adobe's
servers. Portraits come through the connector's preview (600 pixels, shipped
at 512×512). Anything larger needs the full-size file from Adam's PC: a
folder connected to the session in the Claude desktop app, or the files
attached in chat.

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
| Fonts: Fraunces SemiBold/Bold and Italic (the narrator), Figtree Regular–Bold | `assets/fonts/` | TTF, OFL 1.1 | bundled |
| Launcher icon: gold lantern on forest green (adaptive + legacy) | `android/app/src/main/res/` | PNG rendered from SVG, 432×432 foreground | coded |

## 2. Stand-ins (code-drawn, to be replaced by painted art)

These are original and on-palette, but they are **not** the illustration
the design asks for. Each has a matching entry in section 3.

| Stand-in | Where | Replaces | Since | Status |
|---|---|---|---|---|
| Hero crests ×4 (hooded figure medallions) | `lib/ui/art/crests.dart` | Hero portraits | Phase 1 | replaced 14 Nov 2026 by the four illustrated portraits; the crest stays in the code as the fallback if a picture cannot be shown |
| Companion crests ×6 (Hound, Cat, Fox, Owl, Hare, Clockwork Sprite) | `lib/ui/art/crests.dart` | Companion portraits | Phase 1 | replaced 14 Nov 2026 by the six illustrated portraits; the crest stays in the code as the fallback |
| Dawn valley vista (sky, sun, ridges, mist, lanterns) | `lib/ui/art/vista.dart` | Dawn header scene, onboarding scene | Phase 1 | replaced 14 Nov 2026 behind the Today board by the painted valley (section 7); the coded vista stays for the welcome screen and as the stand-in if a painting cannot be shown |
| The Vale map: 86 hand-laid shapes on a 400×500 grid (peaks, ruins, river, hills, village, woods), each region draining to grey when asleep | `lib/ui/map/map_art.dart` | Painted map, asleep and awake | Phase 2 | placeholder |
| Fog banks over sleeping regions | `lib/ui/map/vale_map.dart` | Painted fog | Phase 2 | placeholder (may simply stay coded) |
| Place medallions ×20 (an icon in a ring, grey when asleep, gold-lit when restored) | `lib/ui/map/vale_map.dart` | Building art, asleep and restored | Phase 2 | replaced 14 Nov 2026 by the 20 place pictures where a place is shown in a list or on a card (section 6); the markers on the map itself stay coded |
| Villager medallions ×20 (the villager's icon on a green roundel) | `lib/ui/board/board_screen.dart` | Villager portraits | Phase 2 | replaced 14 Nov 2026 by the 20 villager pictures (section 6) |
| Campfire night scene (stars, ridges, fire glow) with the two portraits | `lib/ui/campfire/campfire_screen.dart` | Campfire scene | Phase 2 | replaced 14 Nov 2026 by the painted camp (section 7); the coded night stays as the stand-in |
| Lantern roundel on the Discovery card (the same for the 19 scenes not yet illustrated) | `lib/ui/celebrations.dart` | Discovery scene art | Phase 1 | replaced 14 Nov 2026: all 20 Discoveries show a painting (section 7) |
| Still creatures: a sleepy grey blob on the map, a small icon on the card (same for all 6) | `lib/ui/map/vale_map.dart`, `v_icon.dart` | Still creature art | Phase 2 | the board row shows the six pictures since 14 Nov 2026 (section 6); the blob on the map stays coded |
| Companion gear: a slot icon (collar, bell, cloak, blanket) as a badge on the portrait | `lib/ui/art/crests.dart` | Gear art per kind | Phase 2 | the Inventory shows the 11 pictures since 14 Nov 2026 (section 6); the badge on the portrait stays a coded icon |
| Portrait frames: the portrait ring in a different colour | `lib/ui/art/crests.dart` | Frame art | Phase 2 | placeholder (may simply stay coded) |
| Village decorations: small flags, dots and lights on the map | `lib/ui/map/vale_map.dart` | Painted into the awake map | Phase 2 | placeholder |
| "Old Friends" scene: the two portraits side by side | `lib/ui/party/party_sheet.dart` | Hero + companion portrait scene (companion L10) | Phase 2 | placeholder |

## 3. Illustrated raster assets

Generated in Firefly (section 4). Files go into `assets/art/<folder>/` with
the filenames below, sRGB, no text baked in. Sizes are final pixel sizes.
The largest on-screen use on the Fold 8 is noted so nothing ships oversized.
A status of `needed-from-Adam` below now means "not made yet": the piece is
waiting its turn, and anything larger than a portrait is also waiting on a
way to bring the full-size file over (section 4).

### Needed first: the reference board (STYLE.md §7)

| File | Size | Subject line to append to the style prompt | Status |
|---|---|---|---|
| `assets/art/portraits/companion_hound.jpg` | 512×512 | `Subject: a friendly tricolour hound with a black saddle, tan head and ears, and a white muzzle and chest, soft drooping ears, shown from the chest up, looking toward the viewer, centred, simple meadow background.` | in the app; generated 14 Nov 2026, look approved by Adam |
| `assets/art/portraits/hero_wayfarer.jpg` | 512×512 | `Subject: a traveller in a deep green hooded cloak with a small gold leaf clasp, calm friendly expression, shown from the chest up, centred, simple soft background.` | in the app; generated 14 Nov 2026, approved by Adam |
| `assets/art/discoveries/standing_stone.jpg` | 600×466 working copy; 1200×900 wanted | `Subject: a tall weathered standing stone beside a country road at dawn, one side lit warm, wildflowers at its base.` | generated 14 Nov 2026; full-size file still to come from Adam's PC |

Once these three are approved they become the reference every later asset
is checked against.

### Portraits (shown up to 132dp; shipped at 512×512)

All ten portraits (four heroes, six companions) are in the app as of version
0.3.0. Adam approved the hound, the wayfarer and the cat by eye and said to
carry on with the rest; the other seven are in the app for him to judge on
the Fold.

| File | Size | Subject | Status |
|---|---|---|---|
| `assets/art/portraits/hero_lamplighter.jpg` | 512×512 | `Subject: an older woman traveller with silver hair tied back and a kind lined face, wearing an amber hooded cloak fastened at the neck over a high-collared tunic, holding up a small lit glass lantern, shown from the chest up, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026 (second try) |
| `assets/art/portraits/hero_riverwarden.jpg` | 512×512 | `Subject: a young woman traveller with dark braided hair and warm brown skin in a river-blue hooded cloak with a small silver wave clasp, calm friendly expression, shown from the chest up, centred, simple soft background.` | generated 14 Nov 2026 |
| `assets/art/portraits/hero_emberkeeper.jpg` | 512×512 | `Subject: a broad-shouldered traveller with a short red-brown beard and a warm smile, wearing a rust-red hooded cloak fastened at the neck over a cream tunic, shown from the chest up, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026 (second try) |
| `assets/art/portraits/companion_cat.jpg` | 512×512 | `Subject: a composed grey cat with gold eyes, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026 (second try; the first came out too dark) |
| `assets/art/portraits/companion_fox.jpg` | 512×512 | `Subject: a bright-eyed red fox with a white chest, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026 |
| `assets/art/portraits/companion_owl.jpg` | 512×512 | `Subject: a small brown owl with large amber eyes, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026; cropped in a little |
| `assets/art/portraits/companion_hare.jpg` | 512×512 | `Subject: a sandy-brown hare with tall ears, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026 |
| `assets/art/portraits/companion_clockwork_sprite.jpg` | 512×512 | `Subject: a small friendly brass clockwork sprite with a wind-up key on its back, glass wings and gentle teal-lit eyes, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | generated 14 Nov 2026; shading is glossier than the rest, a candidate to redo |

### Scenes

| File | Size | Subject | Status |
|---|---|---|---|
| `scenes/dawn_header.png` | 1600×1100 | wide view down a sleeping valley at dawn: layered hills, a small village with a few lit lanterns, low sun, mist | in the app since 0.5.2 as `assets/art/scenes/dawn_<part of day>.jpg`, 1152×896, four lights from the one painting (section 7) |
| `scenes/campfire.png` | 1600×1000 | a small camp beside a country road at dusk: a fire, a bedroll, a lantern on a post; space left and right of the fire for two figures | in the app since 0.5.2 as `assets/art/scenes/campfire.jpg`, 1152×896 (section 7) |
| `scenes/old_friends.png` | 1600×1000 | a traveller and their animal companion sitting side by side on a hill at dusk, seen from behind, lanterns of a valley below | generated 14 Nov 2026 (section 6); a first look, not in the app: the take shows one traveller, without a companion |

### The map (portrait, 4:5, to match the coded layout)

The coded map is 400×500 units. Painted replacements must keep the same
composition so the road, lanterns, camp and place medallions (which stay
coded) land in the right spots: **peaks top-left, ruins top-right, river
across the middle, hills centre-right, village bottom-left.** A print of the
coded map (`docs/screenshots/phase-2/map-cover.png`) is the layout guide.

| File | Size | Subject | Status |
|---|---|---|---|
| `map/vale_asleep.png` | 1600×2000 | hand-drawn-feeling painted map of a valley seen from above: snowy peaks top-left, pale stone ruins top-right, a river crossing the middle, rolling hills centre-right, a village bottom-left; muted, grey, misted, asleep; no road, no labels | not needed: the sleeping state will be the awake painting drained in code (section 6) |
| `map/vale_awake.png` | 1600×2000 | the same map, same composition exactly, fully coloured and warmly lit | a first look was generated 14 Nov 2026 (section 6); not in the app (section 7) |

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
Status: the other 19 were generated 14 Nov 2026 and wait for full-size files (section 6); `standing_stone` is in the app as a working copy.

### Places (20, shown as a medallion on the map and on the restoration card)

512×512 each, `places/<key>.png`, one **restored** painting per place (the
asleep state is the same painting drained to grey in code, as the map
does). Keys and names are in `lib/rules/world.dart`: gate_lantern,
village_well, bakehouse, moot_hall, sheepfold, larkdown_mill, hill_beacon,
orchard, heron_bridge, wheelhouse, boathouse, ford_bell, waystation, ropeway,
star_loft, summit_cairn, great_arch, reading_room, glasshouse, lanternhall.
Subject: the place by name, small and centred, in its region's setting.
Status: all 20 in the app since 0.5.1, at 384×384 (section 6).

### Villagers (20, shown at 40dp on the board and at the Campfire)

512×512 each, `villagers/<key>.png`, head-and-shoulders. Names and roles are
in `lib/rules/world.dart` (Wick the lamplighter, Marla the well-keeper, Bryn
the baker, …). Status: all 20 in the app since 0.5.1, at 256×256 (section 6).

### The Still (6 creatures)

512×512 each, transparent background, `still/<key>.png`: drowsel, mistling,
hushmoth, yawnstone, dozewisp, fogfinch. Subject: a small, round, grey,
sleepy creature, soft and harmless, eyes closed. Never frightening.
Status: all six in the app since 0.5.1, at 320×320 on a cream ground and
shown as medallions, so no transparency was needed (section 6).

### Companion gear (11 pieces)

256×256 each, transparent background, `gear/<key>.png`: moss_neckerchief,
brass_bell, hearth_blanket, trail_cloak, lantern_charm, silver_bell,
star_blanket, dawn_cloak, golden_tag, song_bell, old_road_cloak. One
painting per piece, shown beside the portrait. DESIGN §7A.3 asks for
variants per companion kind (66 paintings); that is a later pass if wanted.
Status: all 11 in the app since 0.5.1, on a cream ground (section 6).

### App icon

| File | Size | Notes | Status |
|---|---|---|---|
| `icon/launcher_foreground.png` | 432×432, transparent, subject inside the centre 264×264 | a gold lantern, or the hound's head | optional: a coded lantern icon ships now |
| Background | solid `#12352C` | set in code | coded |

## 4. How the illustrated assets are made

Decided 14 November 2026 (DECISIONS.md D-48 to D-50): Claude drives Adobe
Firefly in Adam's Chrome, with his go-ahead, using Adobe's own Firefly Image
5 model, the style prompt from STYLE.md §6 word for word and one Subject
line per piece. Each piece costs 10 of Adam's Firefly credits. Images are
bundled at build time; the app stays offline.

**How the larger pieces come across.** A portrait is small enough to come
through the Adobe connector's 600-pixel preview. Discovery cards, scenes,
story pictures and the map are shown larger than that, so they need the
full-size file. The route that works (used on 14 Nov 2026, section 7): the
originals are fetched in Adam's Chrome, packed into one zip, and Adam moves
that zip into a folder on his PC that he has connected to the chat in the
Claude desktop app (`Downloads\Valebound Downloads`). Attaching the files in
chat would also do.

**Showing them.** Every portrait is drawn by one widget (`HeroPortrait`,
`CompanionPortrait`) and every Discovery picture by another
(`DiscoveryPicture`), all listed in `lib/ui/art/painted.dart`. A piece that
has no file yet falls back to its code-drawn stand-in, so adding one is a
file and one line. Places, villagers, the Still and gear are shown through
`ArtMedallion`, and the story pages through `StoryPicture`. The valley
behind the Today board is `PaintedVista` (`lib/ui/art/vista.dart`) and the
camp is in `CampScene` (`lib/ui/campfire/campfire_screen.dart`); every large
painting is drawn by `ArtPicture`, which fades it in. The map has no
painted version yet.

## 5. Order

Done: the reference board (3), the remaining portraits (8), and on 14 Nov
2026 the whole list generated (section 6), with the 57 small pieces in the
app.

Done in 0.5.2 (section 7): the story pictures (15), the Discovery cards
(19), and the Dawn and Campfire scenes.

Still open: the map (the first look does not line up with the coded road
and markers, section 7), the "old friends" scene (the take has no
companion in it), and the clockwork sprite portrait, which wants a third
try.

## 6. The full run of 14 Nov 2026 (version 0.5.1)

Adam asked for "everything on the list" on 14 Nov 2026. Every piece below
was generated in Adobe Firefly (Firefly Image 5, 1K) in Adam's Chrome, with
the style prompt from `docs/STYLE.md` §6 **verbatim** and the one Subject
line shown. 99 generations, 10 credits each (96 pieces and three second
takes). Every generation is still in his Firefly history.

**What is in the app and what is waiting.** Pieces that are shown small
came in through the Adobe connector's preview, which is capped at 600
pixels: enough for a medallion, so those are in the app now. Pieces shown
large (Discovery cards, scenes, story pictures, the map) need the full-size
file. Those came across later the same day, once Adam had connected a
folder on his PC, and went into version 0.5.2 (section 7).

Nothing here is drawn "in the style of" anyone, and none of it carries
names, lettering or symbols from anyone else's work. Two first takes showed
a cross on a roof (the Moot Hall and the Lanternhall, which are a village
hall and a lantern-makers' hall); both were generated again without one.

### Places, 20 (in the app)

Shown as round medallions: on the Map beside each place, on the card when a
place wakes, and in the Chronicle. One picture serves both states: a place
that is still asleep is drained to grey in code (`asleepFilter` in
`lib/ui/art/painted.dart`).

| File | Size | Subject | Status |
|---|---|---|---|
| `assets/art/places/gate_lantern.jpg` | 384×384 | `Subject: a tall glass lantern burning warm gold on a timber post beside an open village gate of weathered stone, small and centred, simple misty green background.` | In the app. |
| `assets/art/places/village_well.jpg` | 384×384 | `Subject: a round stone village well with a small timber roof and a wooden bucket on a rope, clear water glinting inside, small and centred, on a village green.` | In the app. |
| `assets/art/places/bakehouse.jpg` | 384×384 | `Subject: a small stone bakehouse with a round chimney trailing smoke, a warm lit window and fresh loaves on the sill, small and centred, on a village green.` | In the app. |
| `assets/art/places/moot_hall.jpg` | 384×384 | `Subject: a timber-framed village meeting hall with a plain gabled roof and a small weathervane, its arched double doors standing open and two long banners hanging beside them, small and centred, on a village green.` | In the app. Second take: the first had a cross on its roof. |
| `assets/art/places/sheepfold.jpg` | 384×384 | `Subject: a round dry-stone sheepfold with a wooden gate standing ajar and three woolly sheep inside, small and centred, on a green hillside.` | In the app. |
| `assets/art/places/larkdown_mill.jpg` | 384×384 | `Subject: a small stone windmill with four white canvas sails on a green hilltop, small and centred, with long views beyond.` | In the app. |
| `assets/art/places/hill_beacon.jpg` | 384×384 | `Subject: a round stone beacon tower on a green hilltop with a steady golden fire burning in an iron basket at its top, small and centred, green hills beyond.` | In the app. |
| `assets/art/places/orchard.jpg` | 384×384 | `Subject: three old apple trees in pink and white blossom with woven baskets set out underneath, small and centred, on a green hillside.` | In the app. |
| `assets/art/places/heron_bridge.jpg` | 384×384 | `Subject: a small arched wooden footbridge with new pale planks over a bright clear river, a grey heron standing in the shallows, small and centred.` | In the app. |
| `assets/art/places/wheelhouse.jpg` | 384×384 | `Subject: a stone mill house beside a river with a great wooden water wheel turning and water spilling from it, small and centred.` | In the app. |
| `assets/art/places/boathouse.jpg` | 384×384 | `Subject: a timber boathouse on a calm river with three small rowing boats moored in front, painted red, blue and yellow, small and centred.` | In the app. |
| `assets/art/places/ford_bell.jpg` | 384×384 | `Subject: a bronze bell hanging in a small stone and timber frame beside a shallow river ford with stepping stones, small and centred.` | In the app. |
| `assets/art/places/waystation.jpg` | 384×384 | `Subject: a small sturdy stone waystation hut on a mountain road with a warmly lit window and a kettle steaming on a stove by the door, small and centred, peaks beyond.` | In the app. |
| `assets/art/places/ropeway.jpg` | 384×384 | `Subject: a wooden ropeway tower on a mountain crag with a wicker basket gliding along a rope between two crags, small and centred.` | In the app. |
| `assets/art/places/star_loft.jpg` | 384×384 | `Subject: a small round stone observatory tower on a mountain with its domed roof slid open and a brass telescope pointing at the sky, small and centred.` | In the app. |
| `assets/art/places/summit_cairn.jpg` | 384×384 | `Subject: a tall neat cairn of stacked stones on a mountain summit above a sea of cloud, a small banner tied at its top, small and centred.` | In the app. |
| `assets/art/places/great_arch.jpg` | 384×384 | `Subject: a great old stone archway standing whole among pale ruins with a road running under it, ivy on one side, small and centred.` | In the app. |
| `assets/art/places/reading_room.jpg` | 384×384 | `Subject: a cosy old stone reading room seen through its open arched doorway, shelves of books and a glowing glass lamp on a desk, small and centred.` | In the app. |
| `assets/art/places/glasshouse.jpg` | 384×384 | `Subject: a small glasshouse of clear panes in a pale stone frame, full of green leafy plants pressing against the glass, small and centred, among pale ruins.` | In the app. |
| `assets/art/places/lanternhall.jpg` | 384×384 | `Subject: a grand old stone guildhall among pale ruins with a plain steep roof topped by a large glass lantern, tall arched windows all glowing with golden lantern light and glass lanterns hanging along its front, small and centred.` | In the app. Second take: the first had a cross on its roof. |

### Villagers, 20 (in the app)

Cropped to head and shoulders. Shown beside the villager's line on the
board and at the shoulder of their place when it wakes.

| File | Size | Subject | Status |
|---|---|---|---|
| `assets/art/villagers/wick.jpg` | 256×256 | `Subject: a lean older man with a grey moustache and a flat brown cap, a lamplighter, wearing a dark green coat with brass buttons and holding up a small lit glass lantern, kind smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/marla.jpg` | 256×256 | `Subject: a cheerful middle-aged woman with warm brown skin and a blue headscarf, a well-keeper, wearing a cream blouse with rolled sleeves and a slate-blue apron, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/bryn.jpg` | 256×256 | `Subject: a round-faced young man with flour on his cheek, a baker, wearing a white cap and a cream apron over a rust-red shirt, warm grin, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/tamsin.jpg` | 256×256 | `Subject: an elderly woman with long white braided hair and deep brown skin, a village elder, wearing a forest-green robe with a gold-embroidered collar, calm wise expression, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/hob.jpg` | 256×256 | `Subject: a weathered man with a short grey beard and a wide straw hat, a shepherd, wearing an undyed wool cloak, a wooden crook over his shoulder, gentle smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/anwen.jpg` | 256×256 | `Subject: a strong young woman with freckles and red hair tied in a green kerchief, a miller, wearing a flour-dusted tan apron over a green dress, bright smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/corin.jpg` | 256×256 | `Subject: a tall young man with dark brown skin and short curly hair, a beacon-keeper, wearing a deep red hooded cloak, steady friendly expression, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/pell.jpg` | 256×256 | `Subject: a small elderly man with round spectacles and a white beard, an orchard-keeper, wearing a moss-green waistcoat and holding a red apple, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/ness.jpg` | 256×256 | `Subject: a sturdy woman with short black hair and a calm smile, a bridge-warden, wearing a slate-blue coat with a small silver bird badge, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/dunstan.jpg` | 256×256 | `Subject: a big gentle man with a bushy brown beard, a wheelwright, wearing a leather apron over a cream shirt, a wooden mallet resting on his shoulder, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/mira.jpg` | 256×256 | `Subject: a young woman with a long dark plait and tan skin, a boatwright, wearing a paint-spattered yellow smock, a paintbrush tucked behind her ear, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/fenn.jpg` | 256×256 | `Subject: a slight young man with sandy hair, a bell-ringer, wearing a blue-grey tunic with a small bronze bell on a cord round his neck, shy smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/greta.jpg` | 256×256 | `Subject: a broad-shouldered older woman with a grey braid, a road-warden, wearing a thick brown coat with a fur collar and a red scarf, hearty smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/tobin.jpg` | 256×256 | `Subject: a wiry man with a dark beard and a knitted orange cap, a rigger, wearing a blue wool jumper with a coil of rope over his shoulder, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/edda.jpg` | 256×256 | `Subject: an elderly woman with silver hair in a bun and small round spectacles, a stargazer, wearing a midnight-blue shawl with tiny gold stars, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/orrin.jpg` | 256×256 | `Subject: a quiet stocky man with a shaved head and brown skin, a cairn-builder, wearing a grey wool cloak and holding a flat stone in both hands, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/hal.jpg` | 256×256 | `Subject: a middle-aged man with stone dust in his dark hair, a mason, wearing a tan leather apron over a pale shirt, a chisel in his hand, easy smile, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/quill.jpg` | 256×256 | `Subject: a thin older man with a neat white beard and a plum-coloured cap, an archivist, wearing a plum robe and holding an open book, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/sorrel.jpg` | 256×256 | `Subject: a young woman with brown skin and a green headwrap, a gardener, wearing a cream smock, a sprig of leaves tucked behind her ear, a trowel in her hand, shown from the chest up, centred, simple soft background.` | In the app. |
| `assets/art/villagers/maren.jpg` | 256×256 | `Subject: a stately older woman with silver-streaked black hair, the keeper of a great hall, wearing a deep green robe with a gold lantern clasp and holding a tall lit lantern, shown from the chest up, centred, simple soft background.` | In the app. |

### The Still, 6 (in the app)

On a plain cream ground and shown as medallions, so no cut-out is needed.
Shown on the board's row for the day's creature.

| File | Size | Subject | Status |
|---|---|---|---|
| `assets/art/still/drowsel.jpg` | 320×320 | `Subject: a small round grey sleepy creature like a plump dormouse made of soft fog, curled up asleep with its eyes closed and a faint smile, soft and harmless, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/still/mistling.jpg` | 320×320 | `Subject: a small round grey sleepy creature like a curl of mist with a tiny face, rolled into a ball with its eyes closed, soft and harmless, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/still/hushmoth.jpg` | 320×320 | `Subject: a small round grey sleepy moth creature with soft dusty folded wings and feathery antennae, eyes closed, soft and harmless, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/still/yawnstone.jpg` | 320×320 | `Subject: a small round grey sleepy creature like a smooth river stone with a tiny yawning mouth, closed eyes and a tuft of moss on top, soft and harmless, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/still/dozewisp.jpg` | 320×320 | `Subject: a small round grey sleepy creature like a soft ball of mist with a wispy curl on top and a short trailing tail, eyes closed, a faint warm glow inside, floating just above the ground, soft and harmless, by itself, centred, plain pale cream background.` | In the app. Second take: the first read as a speech bubble. |
| `assets/art/still/fogfinch.jpg` | 320×320 | `Subject: a small round grey sleepy finch with puffed-up feathers, head tucked down and eyes closed, asleep, soft and harmless, by itself, centred, plain pale cream background.` | In the app. |

### Companion gear, 11 (in the app)

Shown in the Inventory once a piece has been found.

| File | Size | Subject | Status |
|---|---|---|---|
| `assets/art/gear/moss_neckerchief.jpg` | 256×256 | `Subject: a folded moss-green neckerchief with a small leaf pattern, tied in a loose knot, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/brass_bell.jpg` | 256×256 | `Subject: a small round brass bell on a brown leather loop, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/hearth_blanket.jpg` | 256×256 | `Subject: a neatly folded warm woollen blanket in rust red with a cream stripe, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/trail_cloak.jpg` | 256×256 | `Subject: a small forest-green travelling cloak with a hood and a wooden toggle, laid out flat, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/lantern_charm.jpg` | 256×256 | `Subject: a tiny gold lantern charm with a warm glow, hanging on a short cord, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/silver_bell.jpg` | 256×256 | `Subject: a small round silver bell on a slate-blue ribbon, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/star_blanket.jpg` | 256×256 | `Subject: a neatly folded midnight-blue blanket scattered with small gold stars, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/dawn_cloak.jpg` | 256×256 | `Subject: a small hooded cloak in dawn colours, peach fading to rose, with a gold clasp, laid out flat, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/golden_tag.jpg` | 256×256 | `Subject: a round golden name tag with a plain polished face on a green collar loop, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/song_bell.jpg` | 256×256 | `Subject: a small bronze bell engraved with a songbird, on a red braided cord, by itself, centred, plain pale cream background.` | In the app. |
| `assets/art/gear/old_road_cloak.jpg` | 256×256 | `Subject: a small well-worn travelling cloak in weathered brown with neat patches and a brass leaf pin, laid out flat, by itself, centred, plain pale cream background.` | In the app. |

### Discovery cards, 19 (in the app since 0.5.2)

| Key | Aspect | Subject | Status |
|---|---|---|---|
| `hot_spring` | 4:3 | `Subject: a small hot spring in a ring of mossy rocks beside a country road, soft steam rising in the dawn light.` | In the app since 0.5.2 (section 7). |
| `merchant_cart` | 4:3 | `Subject: an old travelling merchant’s cart resting beside a country road, wheels deep in clover, small brass bells hanging from its canopy.` | In the app since 0.5.2 (section 7). |
| `lantern_tree` | 4:3 | `Subject: a great old oak beside a country road with glass lanterns hung in its branches, one of them glowing warm gold.` | In the app since 0.5.2 (section 7). |
| `beehive_wall` | 4:3 | `Subject: an old dry-stone field wall with bees drifting in and out of a gap between the stones, wildflowers along its foot.` | In the app since 0.5.2 (section 7). |
| `wind_chimes` | 4:3 | `Subject: a grassy hollow in green hills where strings of sea shells hang from a bent hawthorn tree, swaying in the wind.` | In the app since 0.5.2 (section 7). |
| `shepherd_hut` | 4:3 | `Subject: a round stone shepherd’s hut with a turf roof on a green hillside, an iron kettle hook beside its small arched door.` | In the app since 0.5.2 (section 7). |
| `mile_marker` | 4:3 | `Subject: an old stone milestone painted faded blue beside a country road, a small carved arrow on it, tall grass around.` | In the app since 0.5.2 (section 7). |
| `stepping_stones` | 4:3 | `Subject: flat stepping stones across a clear shallow river, each stone carved with a small bird, reeds on the far bank.` | In the app since 0.5.2 (section 7). |
| `reed_flute` | 4:3 | `Subject: a stand of tall river reeds bending in the wind at the edge of a calm river, dragonflies above the water.` | In the app since 0.5.2 (section 7). |
| `star_pool` | 4:3 | `Subject: a small still pool among river stones in daylight, its surface showing a deep blue night sky full of stars.` | In the app since 0.5.2 (section 7). |
| `otter_slide` | 4:3 | `Subject: a smooth muddy slide worn into a grassy river bank, two otters playing at the water’s edge.` | In the app since 0.5.2 (section 7). |
| `cloud_bench` | 4:3 | `Subject: a simple stone bench on a high mountain pass, facing out over a wide valley filled with low cloud.` | In the app since 0.5.2 (section 7). |
| `watchtower` | 4:3 | `Subject: a broken old stone watchtower on a mountainside with swallows wheeling around it and nesting in its windows.` | In the app since 0.5.2 (section 7). |
| `echo_stone` | 4:3 | `Subject: a great rounded boulder on a mountain path, facing a far cliff across a deep valley, a small cairn beside it.` | In the app since 0.5.2 (section 7). |
| `snowbell` | 4:3 | `Subject: a ring of small white bell-shaped flowers around a patch of old snow in a high mountain meadow.` | In the app since 0.5.2 (section 7). |
| `garden_gate` | 4:3 | `Subject: a wooden garden gate standing ajar by itself in a meadow, no fence either side, among pale ruins and wildflowers.` | In the app since 0.5.2 (section 7). |
| `sundial` | 4:3 | `Subject: an old stone sundial in a small paved courtyard among pale ruins, its shadow lying across the dial, ivy on the walls.` | In the app since 0.5.2 (section 7). |
| `glass_stair` | 4:3 | `Subject: seven broad steps made of thick old glass, each a different soft colour, climbing between pale ruined walls.` | In the app since 0.5.2 (section 7). |
| `first_lantern` | 4:3 | `Subject: a small plain glass lantern on a low stone plinth in a ruined hall, just kindling with a first warm glow.` | In the app since 0.5.2 (section 7). |

### Scenes, 3 (two in the app since 0.5.2, one a first look)

| Key | Aspect | Subject | Status |
|---|---|---|---|
| `dawn_header` | 4:3 | `Subject: a wide view down a sleeping valley at dawn: layered hills, a small village with a few lit lanterns, a low sun and mist between the ridges, no people.` | In the app since 0.5.2, behind the Today board, in four lights (section 7). |
| `campfire` | 4:3 | `Subject: a small camp beside a country road at dusk: a campfire, a bedroll and a lantern on a post, open ground to the left and right of the fire, no people.` | In the app since 0.5.2, behind the Campfire (section 7). |
| `old_friends` | 4:3 | `Subject: a traveller in a green hooded cloak sitting on a hilltop at dusk, seen from behind, the lanterns of a valley glowing far below.` | Not in the app. The take shows a traveller alone, with no companion, and a face and hair that are not the player's chosen hero. A first look for Adam; the full-size file is kept with the others. |

### Story pictures, 15 (in the app since 0.5.2)

New with the narrator (DECISIONS D-76): one for each page of the prologue,
and each region asleep and awake for the chapter pages. Portrait, because
the story pages are. They are shown by `StoryPicture` in
`lib/ui/story/story.dart`, listed in `storyArt`; a key with no painting
shows a valley painted in code.

| Key | Aspect | Subject | Status |
|---|---|---|---|
| `lastHill` | 3:4 | `Subject: a narrow footpath running over the crest of a grassy hill at first light, a wide valley opening beyond and below, seen from the path, no people.` | In the app since 0.5.2 (section 7). |
| `sleepingVale` | 3:4 | `Subject: a wide valley seen from a hilltop at dawn: a small village, a winding river and far peaks, everything muted grey under mist and very still, no lights anywhere, no people.` | In the app since 0.5.2 (section 7). |
| `gateLantern` | 3:4 | `Subject: a single glass lantern burning low and gold on a timber post beside a closed village gate of weathered stone, everything around it grey, misted and asleep, no people.` | In the app since 0.5.2 (section 7). |
| `stillness` | 3:4 | `Subject: a quiet village lane with shuttered windows and closed arched doors, soft grey mist lying over everything, a small round grey sleepy creature dozing on a doorstep, no people.` | In the app since 0.5.2 (section 7). |
| `road` | 3:4 | `Subject: a country road winding away from a village gate through green hills toward far peaks at sunrise, a row of lanterns on posts along it, the nearest one glowing gold, no people.` | In the app since 0.5.2 (section 7). |
| `hearthmere_asleep` | 3:4 | `Subject: a small village of stone and timber houses at the mouth of a valley, shutters closed and chimneys cold, muted grey under mist, no lights, no people.` | In the app since 0.5.2 (section 7). |
| `hearthmere_awake` | 3:4 | `Subject: a small village of stone and timber houses at the mouth of a valley in morning sun, windows lit, lanterns glowing, banners out and smoke rising from one chimney, no people.` | In the app since 0.5.2 (section 7). |
| `larkdown_asleep` | 3:4 | `Subject: rolling hills with a windmill whose sails hang still and a dry-stone sheepfold, muted grey under mist, very still, no people.` | In the app since 0.5.2 (section 7). |
| `larkdown_awake` | 3:4 | `Subject: rolling green hills in morning sun with a windmill turning, a golden beacon fire on a far hilltop, sheep on the slopes and an orchard in blossom, no people.` | In the app since 0.5.2 (section 7). |
| `silverrun_asleep` | 3:4 | `Subject: a slow glassy river through a valley with a water wheel standing still and a footbridge down to its posts, a heron asleep on one leg, muted grey under mist, no people.` | In the app since 0.5.2 (section 7). |
| `silverrun_awake` | 3:4 | `Subject: a bright river through a valley in morning sun with a water wheel turning, painted rowing boats on the water and a new wooden footbridge, no people.` | In the app since 0.5.2 (section 7). |
| `highcairn_asleep` | 3:4 | `Subject: a stone road climbing between grey mountain peaks with a small stone hut whose door stands open on a dark room, muted grey and very still, no people.` | In the app since 0.5.2 (section 7). |
| `highcairn_awake` | 3:4 | `Subject: a stone road climbing between sunlit mountain peaks with a small stone hut with a lit window, a ropeway basket crossing between crags and a tall cairn on the summit, no people.` | In the app since 0.5.2 (section 7). |
| `lanternhall_asleep` | 3:4 | `Subject: pale stone ruins in a high valley with a fallen archway and a great hall with dark empty windows, muted grey under mist, very still, no people.` | In the app since 0.5.2 (section 7). |
| `lanternhall_awake` | 3:4 | `Subject: pale stone ruins in a high valley in morning sun with a great archway standing whole and a great hall with every window glowing gold with lantern light, no people.` | In the app since 0.5.2 (section 7). |

### The map, 1 (generated, for review)

| Key | Aspect | Subject | Status |
|---|---|---|---|
| `vale_awake` | 3:4 | `Subject: a hand-drawn map of a valley seen from directly above: snowy peaks in the top left, pale stone ruins in the top right, a river crossing the middle from left to right, rolling green hills centre right, a small village bottom left; fully coloured and warmly lit, no road, no labels.` | Not in the app; the full-size file is with Adam for a look. A painted map has to line up with the coded road and markers, so this one is a first look to choose a direction from, not a finished piece. One painting (awake) is planned, with the sleeping state drained in code as for the places; that replaces the two paintings listed above. |

### One that is still not right

| Key | Subject | Status |
|---|---|---|
| `companion_clockwork_sprite` | `Subject: a small friendly clockwork sprite made of flat brass plates with a round head, a wind-up key on its back, two simple glass wings and gentle teal-lit eyes, shown from the chest up, looking toward the viewer, centred, simple sunlit green meadow background at dawn.` | Came out glossy and three-dimensional again, as it did on 13 Nov. The earlier portrait stays in the app. |

## 7. The large pieces come in (version 0.5.2, 14 Nov 2026)

The 38 pieces that are shown large were generated in section 6. This is how
they reached the app.

**The route.** Adam connected `Downloads\Valebound Downloads` on his PC to
the chat. The 38 originals were fetched in his Chrome from his own Firefly
history (PNG, 1152×896 for the 4:3 pieces and 896×1152 for the 3:4 ones)
and packed into one file, `valebound-art-large.zip` (48 MB), which he moved
into that folder. The zip stays there as the full-size masters, named by
piece. Nothing was regenerated and no credits were used.

**In the app (36 pieces, 41 files, 5.4 MB).**

| Set | Files | Size | What was done |
|---|---|---|---|
| Story pictures, 15 | `assets/art/story/<key>.jpg` | 896×1152 | As painted, except the sleeping ones (below). |
| Discovery cards, 19 | `assets/art/discoveries/<key>.jpg` | 960×747 | Scaled down from 1152×896. With the standing stone that makes all 20. |
| The valley behind the Today board | `assets/art/scenes/dawn_morning.jpg`, `dawn_afternoon.jpg`, `dawn_evening.jpg`, `dawn_night.jpg` | 1152×896 | One painting (`dawn_header`) in four lights (below). |
| The camp behind the Campfire | `assets/art/scenes/campfire.jpg` | 1152×896 | As painted. |

**Two kinds of grading, both done once, offline, on the files.** No art is
changed while the app runs, and nothing was repainted or added by another
generator.

- *The sleeping pictures.* The narrator calls the sleeping Vale grey, and
  several takes came out greener or warmer than that. `sleepingVale`,
  `gateLantern`, `stillness` and the five `<region>_asleep` pictures were
  drawn part of the way toward the same grey the app uses for a sleeping
  place (`asleepFilter`), by between 30% and 70% depending on the take. In
  `gateLantern` the flame and its glow were left as painted, so it is the
  one warm thing on the page.
- *The valley in four lights.* The Today board's header follows the hour
  (DECISIONS D-77). The morning file is the painting as it came. For the
  other three the sky (a flat cream field, so it separates cleanly) was
  replaced with a plain graded sky for that hour, the land was cooled or
  darkened to match, and the lit windows and lanterns were kept warm, with
  a soft glow at evening and night. The night sky has small stars.

**Not in the app.**

- `old_friends`: the take shows a traveller alone. The scene is meant to be
  the hero and their companion together, and the hero is whichever of the
  four portraits the player chose, so a painted figure with its own face
  does not fit. A first look for Adam.
- `vale_awake` (the map): painted as a picture of the valley, seen at an
  angle, with a lake where the coded map has the river crossing. The coded
  map's road, markers and regions would not sit on it. A first look for
  Adam; a painted map would need a take made to the coded map's layout.
