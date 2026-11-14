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
- **Phase 3, real life connects:** built and tested, version 0.3.0
  ([report](docs/PHASE-3.md), [acceptance checklist](docs/ACCEPTANCE.md)).
  Branch `phase-3`. The calendar, Health Connect steps and the reminder
  need their first run on a real phone.

## Getting the app

Every push is analysed and tested on GitHub Actions. A debug APK is built
when a commit message contains `[apk]`, or when the workflow is run by hand
from the Actions tab.

- **Latest build:** the `latest-debug` release on this repository's Releases
  page. Open it on the phone (signed in to GitHub), download
  `app-debug.apk`, and allow installation from your browser when Android
  asks.
- The same file is attached to that workflow run as the `app-debug-apk`
  artifact.

Debug builds are large (about 150 MB) because they carry every CPU
architecture and Flutter's debug engine. That is expected for v1.

Builds are signed with a fixed key kept in this private repository
(`android/app/personal-debug.p12`), so each one installs over the last and
keeps the data on the phone. Builds made before Phase 2 used throwaway keys
and have to be uninstalled once first.

A commit message containing `[apk-check]` builds the APK to prove it
compiles without replacing the release.

## Building it yourself

Requires Flutter 3.47.x (stable) and a JDK 17+.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code
flutter test                                               # all tests
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

Install on a connected device: `flutter install` or
`adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

## How the project is laid out

| Path | What lives there |
|---|---|
| `lib/rules/` | The game rules in pure Dart: XP curve, awards, track splits, Bond, Paces, Discoveries, the Vale and its restoration, gear, the Still, schedules, day rollover, the comeback quest, the weekly Delve, reminders, Health Log fields. No Flutter, no database. |
| `lib/data/` | Local SQLite storage (Drift): schema and its migrations, seeded quests, the repository, the JSON backup. |
| `lib/export/` | The Markdown export: the three documents as pure text builders, the queue, and the door to the vault folder. |
| `android/app/src/main/kotlin/` | The Android side of that door: folder picker, writing files, Share, backup save and open. Storage Access Framework only. Also the device door: reading the calendar, reading steps from Health Connect, and the one local reminder. |
| `lib/device/` | The app's side of the device door, with a do-nothing version so the app is whole without any of it. |
| `lib/state/` | One controller that the screens listen to. |
| `lib/ui/` | Screens and widgets. `adaptive.dart` holds the fold-aware two-pane layout. |
| `lib/ui/art/` | Code-drawn stand-in art, and the widgets that show the illustrated pieces (see ASSETS.md). |
| `assets/art/` | The illustrated pieces: ten portraits and the first Discovery card. |
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
