# Valebound (working title)

A habit adventure for Android: your real day is the game. Personal build for
one player on a Galaxy Z Fold. Fully offline: no accounts, no servers, no
analytics, no network calls.

- **Design (single source of truth):** [`docs/DESIGN.md`](docs/DESIGN.md)
- **Defaults chosen where the design is open or silent:** [`DECISIONS.md`](DECISIONS.md)
- **Art manifest and what is still needed:** [`ASSETS.md`](ASSETS.md)
- **Style sheet and the reusable style prompt:** [`docs/STYLE.md`](docs/STYLE.md)

## Status

Phase 1 (the playable day) is on the `phase-1` branch. Phases 2 and 3 follow
the order in the build brief.

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
| `lib/rules/` | The game rules in pure Dart: XP curve, awards, track splits, Bond, Paces, Discoveries, schedules, day rollover. No Flutter, no database. |
| `lib/data/` | Local SQLite storage (Drift): schema, seeded quests, the repository. |
| `lib/state/` | One controller that the screens listen to. |
| `lib/ui/` | Screens and widgets. `adaptive.dart` holds the fold-aware two-pane layout. |
| `lib/ui/art/` | Code-drawn stand-in art (see ASSETS.md). |
| `test/rules/` | Unit tests for every rule. |
| `test/data/` | Repository tests on an in-memory database, including persistence across restart and time away. |
| `test/ui/` | Screen flow tests: onboarding, completing quests, the quest creator. |
| `test/golden/` | Renders the screens at cover-screen and opened-Fold sizes and checks nothing sits on the crease. |
| `test/copy/` | Copy audit: no guilt language, no banned names, no network packages. |
| `.github/workflows/build.yml` | The build. Logs and screenshots are published to the `ci-results` branch. |

## Screen sizes

Layout follows window size classes, never device models: under 600dp wide is
one column with bottom navigation (the cover screen); 600dp and up is two
panes that meet at the display crease (the opened Fold).
