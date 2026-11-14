# Phase 1 report: the playable day

Branch `phase-1`. Built and tested on GitHub Actions with Flutter 3.47.9
(Dart 3.13.7).

## (a) What works now

- **Onboarding.** Name the hero, pick one of four portraits, choose a
  companion from all six kinds (Hound, Cat, Fox, Owl, Hare, Clockwork
  Sprite) with free naming, or take the one-tap "A hound named Babs" preset.
  Five-Minute Reset can be switched on here.
- **Dawn / Quest Board.** Today's quests grouped Now / Later / Done, the
  "With Babs" section with its own smaller cards and accent, hero and
  companion levels with XP bars, and a slim journey strip.
- **Completion types.** Tap, Count (stepper, completes at target) and Timer
  (start/pause, manual minutes, "count it anyway", completes itself at
  target; keeps counting if the app is closed).
- **Progression.** XP and the DESIGN §5.1 level curve for hero, companion
  and attributes; difficulties 10 / 25 / 60 / 150; track splits exactly per
  §7A.2 (Shared = full Companion XP + half hero XP rounded up); Bond that
  only rises; Paces; a Discovery every 10 Paces; gold and materials.
- **Moments.** Reward chips on every completion, a full-screen hero level-up
  with title, a smaller companion level-up with the trick learned, and a
  Discovery card.
- **Quest Log.** Create, edit, archive and restore. A new quest needs a name,
  one attribute tap and Save; the Hero / Companion / Shared picker and its
  one-sentence explanation are on the first screen. A plain history of past
  days.
- **Party Sheet.** Hero: portrait, title, level, six attributes with the
  companion's favourite starred, totals, titles. Companion: portrait by
  kind, level, Companion XP, Bond meter, tricks, the road and discoveries.
- **Foldable layout.** One column with bottom navigation under 600dp; two
  panes that meet at the crease at 600dp and up (Board + Vale, hero +
  companion, Log list + detail). Dialogs and the quest detail stay inside
  one pane.
- **Failure rules.** No streaks, nothing is ever removed, an undone quest
  simply expires, and no guilt copy (checked by a test).
- **Storage.** On-device SQLite via Drift, UUID keys, no network.

Not in Phase 1 by design (see DECISIONS.md): the illustrated World Map and
restoration, the full Campfire and Markdown export, calendar, Health Connect,
the Delve, the comeback quest's screen, reminders, Settings.

## (b) How to try it

1. On the Fold, open the repository's **Releases** page and download
   `app-debug.apk` from **Latest debug build** (`latest-debug`).
2. Open the file and allow installation from your browser when asked.
3. Walk through onboarding, then complete Walk Babs from the cover screen and
   open the Fold to see the two-pane layout.

Or from a computer with Flutter: `flutter build apk --debug`, output at
`build/app/outputs/flutter-apk/app-debug.apk`.

## (c) Screenshots

Rendered by the test suite at Galaxy Z Fold 8 panel sizes (cover 416×657dp,
inner 816×616dp with a centre fold, 3× density). Half-size copies:

| | Cover screen (compact) | Opened Fold (expanded) |
|---|---|---|
| Board | [top](screenshots/phase-1/board-cover.png), [companion section](screenshots/phase-1/board-cover-companion-section.png) | [top](screenshots/phase-1/board-open.png), [companion section](screenshots/phase-1/board-open-companion-section.png) |
| Party Sheet | [hero](screenshots/phase-1/party-sheet-cover-hero.png), [companion](screenshots/phase-1/party-sheet-cover-companion.png) | [hero and companion](screenshots/phase-1/party-sheet-open.png) |
| Quest Log / creator | [new quest](screenshots/phase-1/new-quest-cover.png) | [list + detail](screenshots/phase-1/quest-log-open.png), [quest detail](screenshots/phase-1/quest-detail-open.png) |
| Onboarding | [companion choice](screenshots/phase-1/onboarding-cover-companion.png) | [companion choice](screenshots/phase-1/onboarding-open-companion.png) |
| Level-up | [hero](screenshots/phase-1/level-up-cover.png) | |

## On a real Android runtime

**Confirmed on the Galaxy Z Fold 8 by Adam, 13 November 2026:** installed
the APK, went through onboarding to the board, completed Walk Babs, swiped
the app away and reopened it to find the quest still under Done; then moved
around the app on the cover screen and with the Fold open.

On the CI emulator (Android 14), one run also showed the APK installing,
starting, surviving a force-stop and starting again with no crash in the
device log, laid out as one column at phone and cover size and as two panes
at the inner size
([phone](screenshots/phase-1/emulator-first-launch.png),
[cover size](screenshots/phase-1/emulator-cover-size.png),
[inner size](screenshots/phase-1/emulator-open-size.png)).
In two later runs the hosted emulator stopped responding about 30 seconds
after the app launched, with nothing in the logs to say why, so that job now
runs only on demand. The phone is the proof.

## Evidence

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 109 tests, all passing |
| `flutter build apk --debug` | Succeeds; `build/app/outputs/flutter-apk/app-debug.apk` |
| Installs, runs offline, data persists across restart | Confirmed on the Fold |
| XP curve matches the formula for every level, and the worked examples (100, 280, 520, 800, 2,700) | `test/rules/xp_curve_test.dart` |
| Difficulty awards, track splits, Bond, Paces, Discovery every 10 Paces, Sniff Out, nothing ever decreases | `test/rules/awards_test.dart` |
| Schedules, day rollover, comeback trigger | `test/rules/schedule_and_day_test.dart` |
| Seeds, completions, time away changes nothing, persistence after close and reopen | `test/data/repository_test.dart` |
| Onboarding, Tap / Count / Timer on the board, quest creator | `test/ui/flows_test.dart` |
| Nothing critical on the crease, hero left and companion right of it | `test/golden/screens_golden_test.dart` |
| No guilt copy, no banned names, no network packages | `test/copy/copy_audit_test.dart` |
