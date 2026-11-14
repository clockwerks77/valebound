# Valebound (working title)

A habit adventure for Android: your real day is the game. Personal build for
one player on a Galaxy Z Fold. Fully offline: no accounts, no servers, no
analytics, no network calls.

- **Design (single source of truth):** [`docs/DESIGN.md`](docs/DESIGN.md)
- **Defaults chosen where the design is open or silent:** [`DECISIONS.md`](DECISIONS.md)
- **Art manifest and what is still needed:** [`ASSETS.md`](ASSETS.md)
- **Style sheet and the reusable style prompt:** [`docs/STYLE.md`](docs/STYLE.md)

## Status

- **Phase 1, the playable day:** done and confirmed on the Fold
  ([report](docs/PHASE-1.md)). Branch `phase-1`.
- **Phase 2, the world, the journey and the vault:** done; the vault export
  and backup were confirmed on the Fold ([report](docs/PHASE-2.md),
  [sample export files](docs/samples)). Branch `phase-2`. Share… and
  restoring from a backup have not been tried on a phone yet.
- **Phase 3, real life connects:** built, tested and run on the Fold,
  version 0.3.1 ([report](docs/PHASE-3.md),
  [acceptance checklist](docs/ACCEPTANCE.md)). Branch `phase-3`. The
  calendar, the reminder and the Health Log were confirmed on the Fold on
  14 Nov 2026; a real step count from Health Connect is the one check
  still open.
- **After the first run, version 0.4.0:** a daily Still creature to wake,
  the day's average glucose from Health Connect, and a first-run tour, all
  asked for by Adam after using 0.3.0 ([report](docs/PHASE-4.md)). Branch
  `phase-4`. Built and tested; not yet run on a phone.
- **The narrator and a first polish pass, version 0.5.0:** a storyteller
  who says where you are (prologue, a line over the board, a line at the
  Campfire, chapters, a Chronicle), Health Connect read again every few
  minutes while the app is open, a release build, and motion, haptics and a
  launch screen that belong to the app ([report](docs/PHASE-5.md)). Branch
  `phase-5`. Built and tested; not yet run on a phone.
- **Classes, the daily encounter and real stakes, version 0.7.0:** four
  classes fed by the day's quests, a turn-based fight each day that can be
  lost (never anything already earned), and a weekly boss whose HP carries
  over, to Amendment v0.3 in
  [`docs/AMENDMENTS_v0.3_v0.4.md`](docs/AMENDMENTS_v0.3_v0.4.md)
  ([report, with the balance numbers](docs/PHASE-7.md)). Branch `phase-7`.
  Built and tested; not yet run on a phone. Part B of the amendments
  (the questionnaire and quest generation) is the next build.

## Getting the app

Every push is analysed and tested on GitHub Actions. The APKs are built when
a commit message contains `[apk]`, or when the workflow is run by hand from
the Actions tab.

- **Latest build:** the `latest` release on this repository's Releases page.
  Open it on the phone (signed in to GitHub), download
  **`Valebound-<version>.apk`**, and allow installation from your browser
  when Android asks. This is the release build: about 24 MB, for arm64
  phones, with no internet permission at all.
- **Fallback:** `Valebound-<version>-debug.apk` on the same page is the same
  app as a debug build (about 160 MB). If the release build misbehaves,
  install this one over it.
- Both files are also attached to the workflow run as the `valebound-apks`
  artifact.

Both are signed with a fixed key kept in this private repository
(`android/app/personal-debug.p12`), so either installs over the other, and
over any build since Phase 2, and keeps the data on the phone. Builds made
before Phase 2 used throwaway keys and have to be uninstalled once first.

CI reads the permissions out of the release file and fails the build if it
ever declares `INTERNET` (`logs/apk_permissions.txt` on the `ci-results`
branch).

A commit message containing `[apk-check]` builds both files to prove they
compile without replacing the release.

## Building it yourself

Requires Flutter 3.47.x (stable) and a JDK 17+.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code
flutter test                                               # all tests
flutter build apk --release --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-release.apk`
(`flutter build apk --debug` for the debug build).

Install on a connected device:
`adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## How the project is laid out

| Path | What lives there |
|---|---|
| `lib/rules/` | The game rules in pure Dart: XP curve, awards, track splits, Bond, Paces, Discoveries, the Vale and its restoration, gear, the Still and the day's creature, schedules, day rollover, the comeback quest, the weekly Delve, reminders, Health Log fields, calendar suggestions, and the narrator's words (`narrator.dart`). No Flutter, no database. |
| `lib/data/` | Local SQLite storage (Drift): schema and its migrations, seeded quests, the repository, the JSON backup. |
| `lib/export/` | The Markdown export: the three documents as pure text builders, the queue, and the door to the vault folder. |
| `android/app/src/main/kotlin/` | The Android side of that door: folder picker, writing files, Share, backup save and open. Storage Access Framework only. Also the device door: reading the calendar, reading steps and glucose from Health Connect, and the one local reminder. |
| `lib/device/` | The app's side of the device door, with a do-nothing version so the app is whole without any of it. |
| `lib/state/` | One controller that the screens listen to. |
| `lib/ui/` | Screens and widgets. `adaptive.dart` holds the fold-aware two-pane layout; `tour/` holds the first-run tour and the one-time screen hints; `story/` holds the prologue, the chapter pages and the Chronicle; `motion.dart` and `feel.dart` hold the app's motion and haptics. |
| `lib/ui/art/` | Code-drawn stand-in art, and the widgets that show the illustrated pieces (see ASSETS.md). |
| `assets/art/` | The illustrated pieces: ten portraits; since 0.5.1 the 20 places, 20 villagers, six Still creatures and 11 pieces of gear; since 0.5.2 all 20 Discovery cards, the 15 story pictures, the valley behind the Today board (in four lights) and the camp. |
| `tool/sim/` | The combat rules a second time, in Python, used to tune the numbers. The Dart engine is tested against it fight for fight. |
| `test/rules/` | Unit tests for every rule. |
| `test/data/` | Repository tests on an in-memory database, including persistence across restart, time away, the backup, and the upgrades from the Phase 1 and Phase 2 databases. |
| `test/export/` | The Markdown contract field by field, the export queue, and the generator for `docs/samples`. |
| `test/ui/` | Screen flow tests: onboarding, completing quests, Undo, the quest creator, Map, Inventory, Campfire, Settings, calendar suggestions, steps, the Health Log, the Delve, the reminder. |
| `test/acceptance/` | A quest of each completion type, created and completed (DESIGN §15). |
| `test/golden/` | Renders the screens at cover-screen and opened-Fold sizes and checks nothing sits on the crease. |
| `test/copy/` | Copy audit: no guilt language, no banned names, no network packages. |
| `.github/workflows/build.yml` | The build. Logs and screenshots are published to the `ci-results` branch. |

## Screen sizes

Layout follows window size classes, never device models: under 600dp wide is
one column with bottom navigation (the cover screen); 600dp and up is two
panes that meet at the display crease (the opened Fold).
