# The narrator, and a first polish pass: versions 0.5.0 and 0.5.1

Branch `phase-5` (built on `phase-4`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7). App version 0.5.1 (0.5.0 without the
new art).

This is what Adam asked for on 14 November 2026 after 0.4.0: Health Connect
read again while the app is open, something that puts the player into the
setting, and much more polish. He chose the narrator's voice, the release
build and the whole art list from options put to him. The narrator changes
the design, so it has a dated amendment in `docs/DESIGN.md` §7; the
decisions are D-74 to D-78 in `DECISIONS.md`.

Nothing here has been run on a phone yet.

## (a) What works now

- **Health Connect while the app is open.** Steps and glucose are read
  again every three minutes while the app is in front, and each time the
  Health Log opens. Reading stops when the app leaves the front. If
  midnight passes with the app open, the day turns over on the next tick.
- **A narrator.** An unnamed storyteller who speaks to you, in the present
  tense, in an italic of its own.
  - **Prologue**, once: five pages (the first three are the lines you
    picked), then the page that opens Chapter One. Skip is on every page
    but the last. If you are already in the Vale you are told it once on
    the first launch of this version, without the tour.
  - **Over the board:** the heading now says the part of the day and where
    your camp is ("Morning in Hearthmere"), and under the date is the
    narrator's line: one true thing about the Vale, then the place waiting
    to be woken. It is the same all day and different tomorrow. After days
    away it says only that the Vale has kept.
  - **At the Campfire:** a closing line built from the best thing the day
    held. A day with nothing done gets a line as warm as any.
  - **Chapters:** one to a region. When a region's last place wakes, a card
    closes its chapter and opens the next.
  - **Chronicle:** tap the narrator's line, or the book button on the Map.
    "Where things stand" (places awake, villagers home, the chapter, what
    is waking next, where the camp is, Discoveries), then the story so far
    with dates. The prologue can be read again from there.
  - The tour has a twelfth bubble for the narrator's line.
- **A release build.** The file to install is `Valebound-0.5.1.apk`:
  about 25 MB instead of 163 MB, compiled ahead of time, with no internet
  permission at all (CI checks the built file). The debug build is beside
  it as a fallback. Same signing key, so either installs over 0.4.0 and
  over each other, and your data stays.
- **Polish.**
  - The system launch screen is the app's deep green with its lantern; it
    was white.
  - The valley over the board follows the time of day: dawn, a blue
    afternoon, a rose dusk, a night with stars.
  - Every full screen arrives the same way, tabs fade into place, the main
    button gives under the thumb, and the narrator's line cross-fades when
    it changes.
  - Short haptics on finishing a quest, Undo, changing tab, turning a story
    page, and on a level, a Discovery or a place waking.
  - Motion is switched off when the phone asks for reduced motion.

## (b) How to try it

1. On the phone, open the repository's **Releases** page and the `latest`
   release (the old `latest-debug` page is gone). Download
   **`Valebound-0.5.1.apk`** and install it over the app you have.
2. Open it. The launch screen should be green with the lantern, then the
   prologue. Read it or Skip.
3. On the board, read the heading and the italic line under the date. Tap
   the line: the Chronicle opens.
4. Finish a quest: you should feel a short tick. Change tab: another.
5. Leave the app open on the board for a few minutes after a walk; the
   steps quest should fill by itself (if steps are connected).
6. Open the Campfire and read the line under the camp.
7. Try it again in the evening: the heading and the sky should have changed.

If the release build misbehaves in any way, install
`Valebound-0.5.1-debug.apk` from the same page over it. Nothing is lost
either way.

## (c) Screenshots

`docs/screenshots/phase-5/`, cover screen (416×657dp) and opened Fold
(816×616dp):

| What | Cover | Open |
|---|---|---|
| Board with the narrator's line | `01_board_cover.png` | `02_board_open.png` |
| Board in the afternoon, evening, night | `100_board_*_cover.png` | |
| Prologue, first page | `91_prologue_hill_cover.png` | `91_prologue_hill_open.png` |
| Prologue, the lantern | `93_prologue_lantern_cover.png` | `93_prologue_lantern_open.png` |
| Chapter One opens | `95_prologue_chapter_one_cover.png` | `95_prologue_chapter_one_open.png` |
| A chapter closes, the next opens | `96_chapter_wakes_cover.png`, `97_chapter_opens_cover.png` | `96_chapter_wakes_open.png`, `97_chapter_opens_open.png` |
| The Vale awake | `98_vale_awake_cover.png` | |
| Chronicle | `99_chronicle_cover.png`, `99b_chronicle_story_cover.png` | `99_chronicle_open.png` |
| Tour: the narrator's line | `90_tour_story_cover.png` | `90_tour_story_open.png` |
| A place wakes, with its picture and who came home (0.5.1) | `50_restoration_cover.png` | `65_restoration_open.png` |
| Places on the Map, asleep and awake (0.5.1) | `42_map_cover_places.png` | `60_map_open.png` |
| Gear in the Inventory (0.5.1) | `44_inventory_cover_companion.png` | `61_inventory_open.png` |

On the opened Fold the story pages put the picture on one pane and the
words on the other, and the Chronicle puts where things stand beside the
story; a test checks that no words or buttons sit on the crease.

## Added in 0.5.1: the first of the new art

All 96 pieces on the art list were generated in Firefly on 14 Nov 2026
(ASSETS.md section 6 lists every one with its Subject line). The 57 that
are shown small are in the app:

- **Villagers:** the villager who speaks on the board now has a face, and
  so does whoever comes home when a place wakes.
- **Places:** each place has its picture on the Map (grey while it sleeps),
  on the card when it wakes, and in the Chronicle.
- **The Still:** the day's creature is pictured on its row of the board.
- **Gear:** the Inventory shows each piece you have found.

The 38 that are shown large (Discovery cards, the scenes, the story
pictures, the map) are generated and waiting: they need the full-size
files, which need a folder on the PC connected to the chat.

## What is not done

- **Not run on a phone.** The release build, the haptics, the launch
  screen and the three-minute read are proven in tests and by reading the
  built file, not by hand.
- **The story pictures are still drawn in code.** The painted ones are
  being generated (see ASSETS.md) and need full-size files from the PC.
- **Large art.** 38 generated pieces are not in the app yet (see above).
- **The clockwork sprite** portrait is still the earlier one; two new
  takes came out glossy and three-dimensional.

## Tests

423 pass. New in these versions: `test/ui/art_test.dart` (every picture
exists under the key the rules use), `test/rules/narrator_test.dart` (the words
and which line is told when), `test/ui/phase5_flows_test.dart` (the read
while open, the prologue, the narrator's lines, chapters, the Chronicle),
`test/golden/phase5_golden_test.dart` (the screenshots above, with the
crease checks).
