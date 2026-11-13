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

**Consequence:** I can deliver everything vector, coded and animated myself.
I cannot produce the painterly raster illustration the design calls for.
Those assets are marked **needed-from-Adam** below with exact sizes, and
Phase 1 uses clearly listed code-drawn stand-ins in their place.

Status values: `generated` · `coded` · `placeholder` · `needed-from-Adam`.

## 1. Coded and vector (done by Claude)

| Asset | Where | Format | Status |
|---|---|---|---|
| Icon set, 45 icons (navigation, attributes, quest icons, rewards) | `lib/ui/widgets/v_icon.dart` | SVG path data, 24-unit grid | coded |
| Buttons, cards, pills, XP bars, roundels | `lib/ui/widgets/common.dart` | Flutter widgets | coded |
| Completion ring, reward chips, XP bar glide | `lib/ui/board/quest_actions.dart`, `lib/ui/celebrations.dart` | Flutter animation | coded |
| Hero level-up fanfare (rays, motes) | `lib/ui/celebrations.dart` | `CustomPaint` animation | coded |
| Companion level-up and Discovery cards | `lib/ui/celebrations.dart` | Flutter | coded |
| Fonts: Fraunces SemiBold/Bold, Figtree Regular–Bold | `assets/fonts/` | TTF, OFL 1.1 | bundled |

## 2. Phase 1 stand-ins (code-drawn, to be replaced)

These are original and on-palette, but they are **not** the painterly
illustration in the design. Each has a matching entry in section 3.

| Stand-in | Where | Replaces | Status |
|---|---|---|---|
| Hero crests ×4 (hooded figure medallions) | `lib/ui/art/crests.dart` | Hero portraits | placeholder |
| Companion crests ×6 (Hound, Cat, Fox, Owl, Hare, Clockwork Sprite) | `lib/ui/art/crests.dart` | Companion portraits | placeholder |
| Dawn valley vista (sky, sun, ridges, mist, lanterns) | `lib/ui/art/vista.dart` | Dawn header scene, Vale view, onboarding scene | placeholder |
| Lantern roundel on the Discovery card | `lib/ui/celebrations.dart` | Discovery scene art | placeholder |
| Launcher icon | Flutter default | App icon | placeholder |

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

### Scenes (Phase 2, listed now so they can be made in one sitting)

| File | Size | Subject | Status |
|---|---|---|---|
| `scenes/dawn_header.png` | 1600×1100 | wide view down a sleeping valley at dawn: layered hills, a small village with a few lit lanterns, low sun, mist | needed-from-Adam (coded stand-in works meanwhile) |
| `scenes/campfire.png` | 1600×1000 | a small camp beside a country road at dusk: a fire, a bedroll, a lantern on a post; space left and right of the fire for two figures | needed-from-Adam |
| `map/vale_asleep.png` | 2448×1848 | hand-drawn-feeling painted map of a valley seen from above at an angle: a village, hills, a river, peaks and ruins joined by one winding road; muted, misted, asleep | needed-from-Adam |
| `map/vale_awake.png` | 2448×1848 | the same map, same composition, fully coloured and lit | needed-from-Adam |
| `discoveries/<key>.png` ×11 | 1200×800 each | one per scene in `lib/rules/journey.dart`: hot_spring, merchant_cart, lantern_tree, stepping_stones, beehive_wall, wind_chimes, shepherd_hut, star_pool, mile_marker, watchtower, garden_gate | needed-from-Adam |

Building asleep/restored pairs, NPC portraits, Still obstacles and companion
gear variants will be added here with sizes when Phase 2 fixes the list of
regions and buildings.

### App icon

| File | Size | Notes | Status |
|---|---|---|---|
| `icon/launcher_foreground.png` | 432×432, transparent, subject inside the centre 264×264 | a gold lantern, or the hound's head | needed-from-Adam (I can ship a coded crest icon instead) |
| Background | solid `#12352C` | set in code | coded |

## 4. Three ways to get the illustrated assets

1. **You generate them** in whatever image tool you use, pasting the style
   prompt and each Subject line, and drop the files into the repo (or send
   them to me). Most control; my recommendation.
2. **I drive an image tool you are signed in to**, in your Chrome, if you
   name it and say go. It would use your account and any credits it charges.
3. **Stay code-drawn.** I extend the crest and vista approach to every asset.
   Consistent and free, but it will read as stylised vector, not painterly.

Swapping is a contained change whichever you choose: every portrait and scene
is drawn by one widget (`HeroPortrait`, `CompanionPortrait`, `Vista`), so
raster art replaces the stand-in in one place each. That swap is not built
yet; it comes with the first delivered files.
