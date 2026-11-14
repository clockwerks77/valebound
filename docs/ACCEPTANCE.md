# Acceptance checklist (DESIGN §15)

Run by Claude on 14 November 2026 against version 0.3.0, commit `de85a1a`
on branch `phase-3`, GitHub Actions run 43565195441 (Flutter 3.47.9).

**How it was run.** Claude's workspace cannot build Flutter, so the build,
the analyser and all 304 tests ran on GitHub Actions and the results were
read back from the `ci-results` branch. Claude has no phone. Anything that
needs a real device is marked **needs the Fold** and is not counted as a
pass; where Adam has already confirmed something on his Fold, that is said,
with the date and the version it was confirmed on.

## Result

| | |
|---|---|
| Items passing in full | 9 of 12 (items 1, 3, 4, 5, 6, 7, 8, 11, 12) |
| Items passing in everything that can be run here, with a device check still open | 3 of 12 (items 2, 9, 10) |
| Items failing | 0 |

So by the checklist's own rule ("not done until all are true") the build is
**not yet done**: three items wait on a short session with the Fold. The
steps are in [`PHASE-3.md`](PHASE-3.md), section (b), and the open checks
are listed at the foot of this page.

## The twelve items

### 1. `flutter build apk --debug` succeeds; APK path printed — **Pass**

- Build log (`logs/build_apk.txt` on `ci-results`):
  `✓ Built build/app/outputs/flutter-apk/app-debug.apk`
- 162,879,239 bytes, SHA-256
  `19a3f5c1accdc4e36382d013a6c87a8f48d9c5920fb29837bf7ee9d7d1da6523`.
- Signed with the project's fixed key (certificate SHA-256
  `8dcf398e…7a3b61`, the same as the Phase 2 build), so it installs over the
  top and keeps the data.
- Published as `app-debug.apk` on the `latest-debug` release.

### 2. App installs and runs fully offline; data persists across restart — **Pass in tests; needs the Fold for this version**

- **Offline, pass.** No network package is bundled and no file in `lib/`
  imports `dart:io`, uses `HttpClient` or contains a web address:
  `test/copy/copy_audit_test.dart`, "the app makes no network calls and
  bundles no network package". The app's own Android manifest declares no
  internet permission.
- **One thing to know.** The installable file is a debug build, which
  DESIGN §9 allows. Flutter's debug builds add Android's internet
  permission for the developer tools, so it is listed for the installed
  app even though nothing in the app uses it. A release build would not
  list it. Logged as D-65 for Adam to decide.
- **Persistence, pass.** `test/data/repository_test.dart`, "progress is
  still there after the database is closed and reopened". Upgrades keep
  every row: Phase 1 to 2 in `test/data/phase2_test.dart`, Phase 2 to 3 in
  `test/data/phase3_test.dart` ("opens, keeps every row, and gains what
  Phase 3 adds").
- **Installs and runs: needs the Fold.** The Phase 1 and Phase 2 builds
  were installed and used on the Galaxy Z Fold 8 by Adam on 13 November
  2026. Version 0.3.0 has not been installed on any device yet.

### 3. Board is usable one-handed on compact width and uses two panes when open; nothing critical sits on the crease — **Pass**

- One column with bottom navigation under 600dp, two panes at 600dp and
  up: `test/ui/flows_test.dart`, "compact uses bottom navigation: Board,
  Map, Character, Log" and "one column under 600dp, two panes at 600dp and
  up".
- Crease: every opened-Fold screenshot run calls `expectCreaseClear`, which
  measures every button, completion ring, XP bar and text field on screen
  and fails if one overlaps the fold. It runs on onboarding, the Board, Party
  Sheet, Map, Inventory, Campfire, Settings, Health Log, Delve, quest
  detail and quest editor (`test/golden/screens_golden_test.dart`,
  `test/golden/phase3_golden_test.dart`).
- One-handed: each quest completes from a 48dp ring at the right edge of
  its card, navigation is along the bottom, and the new-quest button sits
  bottom centre. Screenshots:
  [cover](screenshots/phase-3/board-calendar-cover.png),
  [open](screenshots/phase-3/board-calendar-open.png).
- Adam used the Board on the Fold on 13 November 2026 (the Phase 1 and
  Phase 2 builds). "Usable one-handed" is in the end his thumb's call;
  nothing measured here argues against it.

### 4. A quest of each completion type can be created and completed — **Pass**

- `test/acceptance/completion_types_test.dart`, eight tests: Tap, Count,
  Timer (timed and typed in), Auto (by steps, and by tap when steps are
  refused) and Confirm are each created through the same call the quest
  editor makes and completed the way their screen completes them.
- On screen: Tap, Count and Timer in `test/ui/flows_test.dart`; Auto and
  Confirm in `test/ui/phase3_flows_test.dart`; the editor offers all five
  ("setting one in the quest editor asks for notifications then").

### 5. Companion onboarding offers all §7A.1 kinds + free naming (incl. the Babs preset); working Party Sheet pane; Companion XP/levels on the same curve; Bond that only rises; tricks at L2/4/6/8/10 — **Pass**

- Onboarding: `test/ui/flows_test.dart`, "offers every kind, free naming
  and the Babs preset" and "a different kind and name are kept".
- Party Sheet pane: rendered and crease-checked in both postures
  (`test/golden/screens_golden_test.dart`, "Party Sheet").
- Same curve: `test/rules/xp_curve_test.dart`, "equal XP gives equal
  levels on both tracks" and "the companion reaches level 2 at exactly 100
  Companion XP".
- Bond only rises: `test/rules/awards_test.dart`, the Bond group and
  "every total only grows over 2,000 random completions".
- Tricks: `test/rules/schedule_and_day_test.dart`, "tricks unlock at
  companion levels 2, 4, 6, 8 and 10". All five now act in the game;
  Comfort arrived with the comeback quest in this phase.

### 6. Track splits are correct; Paces accumulate and a Discovery fires every 10 Paces — **Pass**

- `test/rules/awards_test.dart`: "Companion quests award Companion XP only,
  at the same values", "Shared quests award full Companion XP + half hero
  XP, rounded up", "half is always rounded up", "exactly one Discovery
  every 10 Paces, in order, none skipped".
- Through storage: `test/data/repository_test.dart`, "Walk Babs: full
  Companion XP + half hero Care XP, Bond and a Pace" and "ten Paces unlock
  the first Discovery, in order".
- In a file the app wrote: the sample day note shows Walk Babs as
  `13 XP + 25 Companion XP`.

### 7. XP, level-up (incl. the L1→2 = 100 XP step), and attribute XP are correct — **Pass**

- `test/rules/xp_curve_test.dart`: "matches the worked examples in the
  design", "level boundaries, including the L1→2 = 100 XP step".
- `test/rules/awards_test.dart`: "XP values are fixed by the design", "four
  Standard hero quests make level 2 (L1→2 = 100 XP)", "attribute XP levels
  on the same curve".
- `test/data/repository_test.dart`: "level-up at 100 XP, with the title
  list kept current".

### 8. Missing a day changes nothing except that day; the comeback quest appears after 2+ days away — **Pass**

- `test/data/repository_test.dart`, "missing days changes nothing except
  those days": every total, level, Bond and Pace is compared before and
  after.
- `test/rules/schedule_and_day_test.dart`: "one day away is just a new
  day", "the comeback quest is due after 2+ days away".
- `test/data/phase3_test.dart`, the comeback group: one quest beside
  today's ordinary board, 25 XP, the same single quest each time, simply
  gone if left alone.
- On screen: `test/ui/phase3_flows_test.dart`, "after days away the board
  offers one welcome". Screenshots:
  [cover](screenshots/phase-3/board-comeback-cover.png),
  [open](screenshots/phase-3/board-comeback-open.png).

### 9. Calendar suggestions appear (with permission) and are ignorable; Health Connect steps fill the Auto quest, manual fallback works without permission — **Pass in tests; needs the Fold**

- **App behaviour, pass**, against a stand-in calendar and step counter:
  - `test/ui/phase3_flows_test.dart`: "asked for on the board, then offered
    as Accept or Dismiss", "Not now leaves the board alone and is not asked
    again", "a refused calendar changes nothing", "an excluded calendar is
    left out".
  - `test/data/phase3_test.dart`: "it is never completed for you",
    "dismissing one records the choice and nothing else".
  - Steps: "connected, the day’s steps complete the quest by themselves",
    "below the target they show as progress", "refused, the quest still
    completes with a tap".
- **The Android side: needs the Fold.** The code that reads Android's
  calendar and asks Health Connect for the day's steps compiles and is in
  the APK, and it is written so that any problem reads as "not connected".
  It has never run on a real device, and a stand-in cannot prove it. This
  is the largest open check in the build.

### 10. Campfire produces Markdown files matching §11 exactly (sample files delivered) — **Pass; one new field to see on the Fold**

- `test/export/markdown_test.dart` checks each file field by field against
  §11. `test/export/export_service_test.dart` regenerates the three sample
  files from a scripted fortnight and compares them with
  [`docs/samples`](samples); they are unchanged since Phase 2.
- On screen: `test/ui/phase2_flows_test.dart`, "closing the day sends the
  export to the vault".
- **Confirmed on the Fold by Adam, 13 November 2026 (version 0.2):** he sent
  back the three files the app wrote into his vault and they matched §11.
- New in this version: the `## Health` section uses the field names chosen
  in Settings (`test/data/phase3_test.dart`, "what was logged reaches the
  day’s Markdown, named as chosen"). Worth one look in a real day note.

### 11. No banned IP terms or guilt-copy terms appear in user-facing strings — **Pass**

- `test/copy/copy_audit_test.dart` reads every string in the app on every
  build: "no guilt, shame or loss language (DESIGN §6.4)" and "no banned
  property names or vocabulary (DESIGN §13)".
- Art: every illustrated piece was generated from the one style prompt in
  `docs/STYLE.md` plus a subject line. No prompt names an artist, studio,
  game or character; the subject lines are listed in `ASSETS.md`.

### 12. Seeded quests (§12) are present and editable on first run — **Pass**

- `test/data/repository_test.dart`, "seeds the quests from the design,
  editable and archivable" and "onboarding can activate Five-Minute Reset".
- The two health seeds now behave as §12 describes:
  `test/ui/phase3_flows_test.dart`, "Morning Health Check opens it and
  completes when saved" and "the weekly injection takes an optional dose
  note".

## Phase 3 brief, beyond §15

| Asked for | Result | Evidence |
|---|---|---|
| READ_CALENDAR requested in context | Pass in tests | Asked from a card on the Dawn board, never at launch (`phase3_flows_test.dart`, calendar group) |
| Today's events as Accept/Dismiss Confirm quests | Pass in tests | Same group; `phase3_test.dart`, "accepting one makes today’s commitment, a Confirm quest" |
| Never auto-completed | Pass | `phase3_test.dart`, "it is never completed for you" |
| Excluded-calendar setting | Pass in tests | "an excluded calendar is left out" |
| Steps fill the 7,000-steps Auto quest | Pass in tests; needs the Fold | Item 9 |
| Manual fallback when permission is denied | Pass | "refused, the quest still completes with a tap" |
| Health Log with user-chosen fields, feeding the Markdown Health section | Pass | `phase3_flows_test.dart`, Health Log group and "a Health Log field can be switched off"; `phase3_test.dart`, Health Log group |
| Weekly Delve resolved at the chosen day's Campfire | Pass | `phase3_rules_test.dart` and `phase3_test.dart`, Delve groups; `phase3_flows_test.dart`, "opens at the Campfire once the day is closed" and "the Delve day can be chosen" |
| Comeback quest | Pass | Item 8 |
| Local quest reminder, optional, off by default, the only notification | Pass in tests; needs the Fold to see one arrive | `phase3_rules_test.dart`, reminders group ("off by default: no time, no reminders"); `phase3_flows_test.dart`, "a reminder is planned for its quest and stops once done". The app has one notification channel and nothing else posts to it |

## Open device checks, in one place

1. Install 0.3.0 over 0.2 and confirm the data is still there.
2. Connect the calendar; see today's events; accept one and dismiss one.
3. Connect Health Connect; see today's steps on the steps quest.
4. Set a reminder a few minutes ahead and see it arrive.
5. Look at `## Health` in a day note after saving the Health Log.
6. Left over from Phase 2: Share… and restoring from a backup.
