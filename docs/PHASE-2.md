# Phase 2 report: the world, the journey and the vault

Branch `phase-2` (built on `phase-1`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7). App version 0.2.0.

## (a) What works now

- **World Map.** The Vale in five regions: Hearthmere (village), Larkdown
  (hills), The Silverrun (river), Highcairn (peaks) and Old Lanternhall
  (ruins). Twenty places wake in order, four to a region. Each asks for some
  Timber, Stone and Star Shards; when everything it asks for has been
  gathered it wakes by itself, the fog lifts from its region and the colour
  comes back. Nothing ever goes back to sleep.
- **Next restoration and its cost.** On the Map and in a slim strip on the
  Board: the place being worked toward and how much of each material is in.
- **Journey road.** One road through all five regions, 200 Paces long. The
  walked stretch turns gold, the camp sits where your total Paces put it,
  and each Discovery is a small lit lantern on the road. Twenty Discovery
  scenes, four to a region.
- **Villagers.** Each restored place brings someone home. One of them greets
  the Dawn board each day and one says goodnight at the Campfire.
- **The Still.** A Heroic or Boss quest has a sleepy grey creature sitting
  on it, on its card and on the map. Finishing the quest wakes it and it
  wanders off.
- **Tricks.** Sniff Out (L2) and Fetch (L4) are live once a day; Scout (L6)
  shows the next Discovery as a silhouette with a one-line hint; Old Friend
  (L10) adds a scene of the two of you. Comfort (L8) unlocks on schedule and
  acts on the comeback quest, which is Phase 3.
- **Companion gear.** Eleven pieces: a gift at each Bond milestone and one at
  companion levels 3, 5, 7 and 9. One can be worn, shown as a badge on the
  portrait. No stats.
- **Inventory.** Gold, materials in the stores and gathered in all, portrait
  frames, banner colours, village decorations, companion gear and tricks.
  Frames, banners and gear can be put to use with one tap.
- **Campfire.** Hero and companion at tonight's camp, what was completed, XP
  gained, level progress, what changed in the Vale, a villager's goodnight,
  the day note, and the export status. "Close the day" completes the
  Campfire Review and triggers the export. The note can still be changed
  afterwards.
- **Markdown export (DESIGN §11).** `Character Sheet.md`, `Quests.md` and
  `Daily/YYYY-MM-DD.md`, written into a folder picked once through Android's
  folder picker, with the permission kept. Today's file is rewritten on each
  completion and at the Campfire. If the folder is away the export waits
  quietly and catches up later. Settings also has **Share…** for the same
  files.
- **Backup.** Save everything as one JSON file, or restore from one, in
  Settings.
- **Settings.** Vault folder and export controls, rename the hero, change
  the companion's name and kind ("a new chapter"; all progress stays), the
  backup, and an About note saying the app is offline and original.
- **Undo.** A quest you tap done waits five seconds, with an Undo on its
  card, before anything is awarded.
- **Storage upgrade.** The database moved to schema 2 with a migration; a
  Phase 1 database opens with every row intact.
- **A fixed signing key**, so from this build on each new APK installs over
  the last and keeps your data.

Not in Phase 2 by design: calendar suggestions, Health Connect, the Health
Log form, the weekly Delve, the comeback quest and the reminder (Phase 3).

## (b) How to try it

**One time only:** uninstall the Phase 1 app before installing this one.
Phase 1 builds were signed with a throwaway key, so Android will not install
this build over them. Uninstalling clears the Phase 1 test data. From this
build on, updates install over the top and keep everything.

1. On the Fold, open the repository's **Releases** page and download
   `app-debug.apk` from **Latest debug build** (`latest-debug`). Install it.
2. Go through onboarding. Tap a quest done and watch the five-second Undo
   ring; let it run out.
3. **Settings** (the slider icon at the top right of the Board) → **Choose
   vault folder** → pick or create a `Quest Log` folder inside your vault.
4. Complete another quest, then look in that folder: `Character Sheet.md`,
   `Quests.md` and `Daily/<today>.md` should be there.
5. Open the **Campfire** from the card at the foot of the Board, write a
   note, **Close the day**. The note should appear under `## Notes` in
   today's file.
6. Open the Fold: Board beside the Map; Character → Inventory; the Campfire
   and Settings each in two panes.
7. In Settings try **Share…** and **Save a backup**.

Steps 3, 4, 5 and 7 are the ones only your phone can prove (see "What has
and has not been verified").

From a computer with Flutter: `flutter build apk --debug`, output at
`build/app/outputs/flutter-apk/app-debug.apk`.

## (c) Screenshots

Rendered by the test suite at Galaxy Z Fold 8 panel sizes (cover 416×657dp,
inner 816×616dp with a centre fold, 3× density). Half-size copies:

| | Cover screen (compact) | Opened Fold (expanded) |
|---|---|---|
| World Map | [map](screenshots/phase-2/map-cover.png), [target and road](screenshots/phase-2/map-cover-target-and-road.png), [places](screenshots/phase-2/map-cover-places.png) | [map + details](screenshots/phase-2/map-open.png) |
| Board | [top](screenshots/phase-2/board-cover.png), [Undo and the Still](screenshots/phase-2/board-cover-undo.png) | [Board + Map](screenshots/phase-2/board-and-map-open.png) |
| Inventory | [hero's](screenshots/phase-2/inventory-cover-hero.png), [companion's](screenshots/phase-2/inventory-cover-companion.png) | [both panes](screenshots/phase-2/inventory-open.png) |
| Party Sheet | | [hero and companion](screenshots/phase-2/party-sheet-open.png) |
| Campfire | [camp](screenshots/phase-2/campfire-cover-scene.png), [review](screenshots/phase-2/campfire-cover-review.png), [note](screenshots/phase-2/campfire-cover-note.png) | [camp + review](screenshots/phase-2/campfire-open.png), [note](screenshots/phase-2/campfire-open-note.png) |
| Settings | [vault and party](screenshots/phase-2/settings-cover.png), [backup and about](screenshots/phase-2/settings-cover-more.png) | [both panes](screenshots/phase-2/settings-open.png) |
| A place is restored | [card](screenshots/phase-2/restoration-cover.png) | [card, clear of the crease](screenshots/phase-2/restoration-open.png) |

All art in these is code-drawn stand-in art, listed in `ASSETS.md`.

## Sample Markdown files

Generated by the app's own export from a scripted fortnight of play (31
October to 14 November 2026, with one day away), not written by hand:

- [`samples/Character Sheet.md`](samples/Character%20Sheet.md)
- [`samples/Daily/2026-11-14.md`](samples/Daily/2026-11-14.md)
- [`samples/Quests.md`](samples/Quests.md)

A test regenerates them on every run and compares them with these copies,
so the format cannot drift without the change being made here on purpose.

### Checked against DESIGN §11

**`Character Sheet.md`**

| §11 asks for | In the sample |
|---|---|
| Overwritten on every export | Same path each time; written with truncate |
| `type: valebound-character` | `type: valebound-character` |
| `updated` | `updated: 2026-11-14T21:30:00` |
| `level` | `level: 4` |
| `total_xp` | `total_xp: 1122` |
| `companion_name` | `companion_name: "Babs"` |
| `companion_kind` | `companion_kind: "Hound"` |
| `companion_level` | `companion_level: 3` |
| `bond` | `bond: 36` |
| Hero attribute table | `## Attributes`, six rows: level and XP |
| Totals | `## Totals`: XP, quests, gold, materials, days visited |
| Current title | `- Title: Path Finder` |
| `## Companion`: kind, name, level, Companion XP, Bond | All five lines present |
| …tricks, gear | `Tricks: Sniff Out`; `Gear:` three pieces |
| …total Paces and Discoveries | `Paces: 30`; `Discoveries: 3 (…)` |
| World restoration summary | `## World`: 6 of 20, by region, and the next place with its cost |

**`Daily/2026-11-14.md`**

| §11 asks for | In the sample |
|---|---|
| One per day, `Daily/YYYY-MM-DD.md` | `Daily/2026-11-14.md` |
| `type: valebound-day` | present |
| `date` | `date: 2026-11-14` |
| `level` | `level: 4` |
| `xp_earned` | `xp_earned: 128` (10+13+10+60+25+10) |
| `companion_xp_earned` | `companion_xp_earned: 35` (25+10) |
| `paces` | `paces: 2` |
| `quests_completed` | `quests_completed: 7` |
| `quests_total` | `quests_total: 8` |
| `steps` (if known) | `steps: 8214`; left out when there is no figure |
| `## Quests Completed` table: Time, Quest, Track, Attribute, Difficulty, XP | Seven rows, those six columns in that order |
| XP column shows hero and/or Companion XP as awarded | `10 XP`, `13 XP + 25 Companion XP`, `10 Companion XP` |
| `## Journey`: Paces today, any Discovery, camp position | `Paces today: 2`, `Discovery: The Quiet Cart`, `Camp: 30 Paces…` |
| Journey omitted only if zero Paces and no Discovery | Covered by a test |
| `## Health`: only what was logged, a simple list; omitted if empty | Three lines; omission covered by a test |
| `## World`: that day's restorations, or "The Vale rests." | `Restored: Larkdown Mill (Larkdown)`; the other wording covered by a test |
| `## Notes`: the Campfire note verbatim; omitted if empty | The note with its blank line kept; omission covered by a test |
| Sections in that order | Quests Completed, Journey, Health, World, Notes |

**`Quests.md`**

| §11 asks for | In the sample |
|---|---|
| Overwritten on export | Same path each time |
| YAML frontmatter | `type: valebound-quests`, `updated`, `active_quests` |
| Active quest definitions as a readable list | Eight quests, under Hero and With Babs |
| Name, attribute, difficulty, schedule, type | e.g. `**Painting / Craft Block** · Craft · Heroic · Sat, Sun · Timer, 60 min` |

**Rules**

| §11 rule | How it is met |
|---|---|
| UTF-8, LF | Written as UTF-8 bytes; a test checks there is no CR |
| One-way; never read, parse or delete vault files | The app lists a folder only to find a same-named file to overwrite; it opens nothing for reading and deletes nothing |
| Never write outside the picked folder | Paths are built under the picked folder only; `.` and `..` segments are dropped |
| Folder unavailable → queue silently, calm line, no dialogs | Settings and the Campfire show "Export waiting for vault folder"; the queue is covered by tests |
| Share… fallback | Settings → Share… |

## What has and has not been verified

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 219 tests, all passing |
| `flutter build apk --debug` | Succeeds; the APK carries the fixed key (certificate SHA-256 `8dcf398e…7a3b61`, checked in CI) |
| World rules: restoration order and cost, stores, Fetch, gear, cosmetics, the road, the Still | `test/rules/world_test.dart` |
| Restoration on record, Campfire, export queue stamps, new chapter, backup round trip, wrong files turned away | `test/data/phase2_test.dart` |
| **A Phase 1 database opens under this build with every row intact** | `test/data/phase2_test.dart`, on a database built from the Phase 1 table definitions |
| Markdown format, field by field | `test/export/markdown_test.dart` |
| Export queue: waits while the folder is away, catches up, rewrites only what changed | `test/export/export_service_test.dart` |
| Undo, Map, Inventory, Campfire, Settings flows | `test/ui/phase2_flows_test.dart` |
| Both postures; nothing critical on the crease; dialogs in one pane | `test/golden/screens_golden_test.dart` |
| No guilt copy, no banned names, no network packages | `test/copy/copy_audit_test.dart` |

**Not yet verified on a real device:** the folder picker, writing into a
real vault folder, the Share sheet, and saving or opening a backup file.
These go through Android's own pickers, which no automated test here can
drive. The Android code for them compiles and the logic above it is tested
against a stand-in folder, but until you run steps 3, 4, 5 and 7 on the Fold
I cannot say they work there. If one does not, tell me what you saw and I
will fix it.

Also worth knowing:

- The Still's "clear" is a line in the reward chips and the creature leaving
  the map, not a dedicated animation of its own.
- Nothing is painted yet. Every stand-in is listed in `ASSETS.md` with what
  would replace it.
