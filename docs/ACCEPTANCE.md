# Acceptance checklist (DESIGN §15)

Run by Claude on 14 November 2026 against version 0.3.0, commit `de85a1a`
on branch `phase-3`, GitHub Actions run 43565195441 (Flutter 3.47.9).
Updated the same night with Adam's run of 0.3.0 on his Galaxy Z Fold 8 and
the three files the app wrote into his vault. Version 0.3.1 followed
(commit `008449d`, run 43568359044, 317 tests passing, published as the
`latest-debug` release); it changes only how calendar suggestions are offered.

**How it was run.** Claude's workspace cannot build Flutter, so the build,
the analyser and all the tests ran on GitHub Actions and the results were
read back from the `ci-results` branch. Claude has no phone. Anything that
needs a real device is counted as a pass only where Adam has confirmed it
on his Fold, and that is said, with the date and the version.

## Result

| | |
|---|---|
| Items passing in full | 11 of 12 (items 1 to 8 and 10 to 12) |
| Items with one device check still open | 1 of 12 (item 9: a real step count has not been seen yet) |
| Items failing | 0 |

So by the checklist's own rule ("not done until all are true") one thing
is left: seeing today's steps arrive on the steps quest. Items 2 and 10
moved to a full pass on 14 November 2026 with Adam's run on the Fold, and
the calendar half of item 9 with them. The open checks are listed at the
foot of this page.

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
- Version 0.3.1 built the same way: 162,883,967 bytes, SHA-256
  `8cfa18afaad66826a12d8fd48dedfc84aae75f975cff6ec271432147600fa161`, same
  signing key. It is the build on the release now.

### 2. App installs and runs fully offline; data persists across restart — **Pass**

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
- **Installs and runs, pass: confirmed on the Fold by Adam, 14 November
  2026.** Version 0.3.0 installed over the Phase 2 app and his data was
  still there. The character sheet the app then wrote still counts
  the day played before the upgrade (two days visited, six quests, 96 XP).

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
- In a file the app wrote on the Fold (Adam's `Daily/2026-11-14.md`): Walk
  Babs reads `13 XP + 25 Companion XP`, with `companion_xp_earned: 25` and
  `paces: 1`. His character sheet has Companion XP 50, Bond 2 and Paces 2
  after two walks.

### 7. XP, level-up (incl. the L1→2 = 100 XP step), and attribute XP are correct — **Pass**

- `test/rules/xp_curve_test.dart`: "matches the worked examples in the
  design", "level boundaries, including the L1→2 = 100 XP step".
- `test/rules/awards_test.dart`: "XP values are fixed by the design", "four
  Standard hero quests make level 2 (L1→2 = 100 XP)", "attribute XP levels
  on the same curve".
- `test/data/repository_test.dart`: "level-up at 100 XP, with the title
  list kept current".
- On the Fold: Adam's character sheet is level 1 at 96 XP, with Vitality
  60, Care 26 and Mind 10, which sum to 96. Gold 24 and six materials are
  what those six quests give under D-08, and the stores hold exactly what
  is left after the Gate Lantern's cost.

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

### 9. Calendar suggestions appear (with permission) and are ignorable; Health Connect steps fill the Auto quest, manual fallback works without permission — **Calendar: pass. Steps: pass in tests, connected on the Fold, a real count not yet seen**

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
- **Calendar on the Fold, pass: confirmed by Adam, 14 November 2026
  (0.3.0).** He connected the calendar from the board and today's events
  were offered. His `Quests.md` shows the two he accepted, each as the
  design asks: `Order · Standard · Once, 2026-11-14 · Confirm`.
- **What that run turned up.** One accepted event, "Mounjaro", repeats the
  seeded Weekly Injection (Mounjaro), which was on the board the same day.
  Version 0.3.1 flags such an event on its card and offers an event that
  sits in two calendars only once (D-68, D-69;
  `test/rules/suggestions_test.dart` and three tests in
  `test/ui/phase3_flows_test.dart`).
- **Steps on the Fold: connected, count not yet seen.** Adam connected
  Health Connect on 14 November 2026 and reports that it worked. The day
  note written at 01:46 that night has no `steps:` line, and its 7,000
  Steps row was completed at 01:34, so no count had reached the app by
  then. That is what the app does when Health Connect has no steps for the
  day yet, which is likely an hour and a half after midnight. The proof
  still wanted is a count on the quest ("3,200 of 7,000 steps so far") and
  `steps:` in a day note, later in a day.

### 10. Campfire produces Markdown files matching §11 exactly (sample files delivered) — **Pass**

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
  day’s Markdown, named as chosen").
- **Confirmed on the Fold by Adam, 14 November 2026 (0.3.0):** the three
  files he sent back match §11 field for field. The day note has the
  frontmatter in order, with `steps` left out because there was no figure;
  the six-column quest table; Journey, Health, World in that order; and no
  Notes section because no note was written. `## Health` lists his three
  entries under their field names with their units.

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
| READ_CALENDAR requested in context | Pass; on the Fold 14 Nov 2026 | Asked from a card on the Dawn board, never at launch (`phase3_flows_test.dart`, calendar group) |
| Today's events as Accept/Dismiss Confirm quests | Pass; on the Fold 14 Nov 2026 | Same group; `phase3_test.dart`, "accepting one makes today’s commitment, a Confirm quest"; two accepted events in Adam's `Quests.md` |
| Never auto-completed | Pass | `phase3_test.dart`, "it is never completed for you" |
| Excluded-calendar setting | Pass in tests | "an excluded calendar is left out" |
| Steps fill the 7,000-steps Auto quest | Pass in tests; connected on the Fold, a real count not yet seen | Item 9 |
| Manual fallback when permission is denied | Pass | "refused, the quest still completes with a tap" |
| Health Log with user-chosen fields, feeding the Markdown Health section | Pass; on the Fold 14 Nov 2026 | `phase3_flows_test.dart`, Health Log group and "a Health Log field can be switched off"; `phase3_test.dart`, Health Log group; the `## Health` section of Adam's day note |
| Weekly Delve resolved at the chosen day's Campfire | Pass | `phase3_rules_test.dart` and `phase3_test.dart`, Delve groups; `phase3_flows_test.dart`, "opens at the Campfire once the day is closed" and "the Delve day can be chosen" |
| Comeback quest | Pass | Item 8 |
| Local quest reminder, optional, off by default, the only notification | Pass; on the Fold 14 Nov 2026 (permission asked when the reminder was set, and the reminder arrived) | `phase3_rules_test.dart`, reminders group ("off by default: no time, no reminders"); `phase3_flows_test.dart`, "a reminder is planned for its quest and stops once done". The app has one notification channel and nothing else posts to it |

## Open device checks, in one place

1. A real step count: later in a day, the steps quest should read
   something like "3,200 of 7,000 steps so far", and that day's note should
   carry `steps:`. If it stays empty after a walk, Samsung Health may not
   be sharing steps with Health Connect.
2. Version 0.3.1: a calendar event that repeats a quest on the board should
   say so on its card.
3. Dismissing a suggestion (covered by tests; not reported from the Fold).
4. Left over from Phase 2: Share… and restoring from a backup.

Done on the Fold, 14 November 2026: installing over the Phase 2 app with
the data intact; the calendar; the reminder; the Health Log in a day note.
