# Phase 3 report: real life connects

Branch `phase-3` (built on `phase-2`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7). App version 0.3.0, then 0.3.1 the same
night after Adam's first run on the Fold (calendar suggestions offered
once, and flagged when they repeat a quest already on the board).

The acceptance checklist from DESIGN §15, item by item with evidence, is in
[`ACCEPTANCE.md`](ACCEPTANCE.md).

## (a) What works now

- **Calendar suggestions.** The Dawn board asks once, on a card below
  today's quests, whether today's calendar events should appear as quests.
  Say yes and Android asks for calendar access; each of today's events then
  shows at the top of the board with its time and two buttons, **Accept**
  and **Dismiss**. An accepted event becomes a Confirm quest for today
  (Order, Standard) that completes only when you tap "I did this". A
  dismissed one is gone for the day. Events you declined or that were
  cancelled are not offered. The app only reads the calendar. Settings has a
  tick per calendar, so any of them can be left out, and a button to stop
  using the calendar altogether. From 0.3.1: an event that sits in two
  calendars is offered once, and an event that repeats a quest already on
  today's board says so on its card ("Looks like “Weekly Injection
  (Mounjaro)”, which is already on today’s board.") with Dismiss as the
  main button.
- **Steps from Health Connect.** Connect from Settings or from the steps
  quest itself. Today's step count then shows on the quest ("3,200 of 7,000
  steps so far") and the quest completes by itself at its target, with the
  usual reward. If Health Connect is refused, missing, or has no figure for
  the day, the quest completes with a tap as before, and steps can be typed
  into the Health Log.
- **Health Log.** A quick form behind the sprig button at the top of the
  board: steps, glucose, time in range, weight, and the weekly injection
  with an optional dose note. Every field is optional. Settings chooses
  which fields appear, kilograms or pounds, and lets you add fields of your
  own with a name and unit. What you type is stored as typed and written
  into the `## Health` section of the day's Markdown note under the names
  you chose. No targets, no advice.
- **Morning Health Check and Weekly Injection** now do what DESIGN §12
  describes: the first opens the Health Log and completes when you save it;
  the second offers a dose note and records it.
- **The weekly Delve.** On the chosen day (Sunday unless changed in
  Settings), once the day is closed at the Campfire, a Delve card appears
  there. It shows what the week gathered (provisions from your own quests,
  trail marks from the companion's, keys from Heroic and Boss quests, days
  on the road) and settles as Cleared, Scouted or Rested. Every outcome
  brings gold and materials home, more for a fuller week, and can restore a
  place. It gives no XP. If its day goes by, it waits for the next Campfire.
- **The comeback quest.** After two or more full days away, the board opens
  with one extra card, "Return to the Vale", worth a Minor quest plus a
  bonus (25 XP). Today's ordinary quests are there as usual and nothing from
  the days away is listed. Once the companion knows Comfort (level 8) it
  also adds Bond.
- **The reminder.** In the quest editor under "More options": Off (the
  default), or a time. Android's notification permission is asked for the
  first time one is set, not before. A quest already done or set aside does
  not remind that day. This is the only notification the app can send.
- **All five completion types in the editor:** Tap, Count, Timer, Auto
  (steps) and Confirm.
- **Illustrated portraits.** The four heroes and six companions are now
  cel-shaded illustrations in place of the drawn crests, in the look Adam
  chose on 14 November. One Discovery card (the standing stone) is
  illustrated; the other nineteen, the map and the scenes are still the
  code-drawn stand-ins listed in `ASSETS.md`.
- **Storage upgrade.** The database moved to schema 3 with a migration; a
  Phase 2 database opens with every row intact, and a backup made by 0.2.0
  restores into 0.3.0.

## (b) How to try it

Install over the top of the Phase 2 app; your data stays.

1. On the Fold, open the repository's **Releases** page, download
   `app-debug.apk` from **Latest debug build** (`latest-debug`) and install
   it. Settings → About should read version 0.3.1.
2. **Portraits.** Look at the board header and the Character tab. In
   Settings → Your party → Change, step through the six companion kinds.
3. **Calendar.** Scroll the board to "Today’s calendar, as quests?" and tap
   **Connect calendar**, then allow access. Today's events should appear at
   the top. Accept one, dismiss one, and complete the accepted one with "I
   did this". In Settings → Calendar, untick a calendar and check its events
   leave the board.
4. **Steps.** Settings → Health → **Connect Health Connect**, and allow
   Steps. The 7,000 Steps quest should show today's count, and complete by
   itself once you are past 7,000. If the count stays empty, Samsung Health
   may not be sharing steps with Health Connect yet; that switch is in
   Samsung Health's own settings.
5. **Health Log.** Tap the sprig button at the top of the board, type a
   glucose reading, **Save**. Then complete Morning Health Check from the
   board and see that it opens the same form. Look at today's file in the
   vault for the `## Health` section.
6. **Reminder.** Open a quest in the Log tab, **More options**, pick a time a
   few minutes ahead, save, allow notifications, and close the app. It is an
   inexact alarm, so Android may deliver it a few minutes late.
7. **Delve.** Settings → Weekly Delve → choose today's weekday. Open the
   Campfire, **Close the day**, then **Enter the Delve** on the card that
   appears.
8. **Comeback.** This one needs two full days away, so it will show itself
   the first time that happens. The screenshot below is what to expect.

Steps 3, 4 and 6 are the ones only your phone can prove: the code that talks
to Android's calendar, Health Connect and alarm clock compiles and is in the
build, but it has never run on a real device.

From a computer with Flutter: `flutter build apk --debug`, output at
`build/app/outputs/flutter-apk/app-debug.apk`.

## (c) Screenshots

Rendered by the test suite at Galaxy Z Fold 8 panel sizes (cover 416×657dp,
inner 816×616dp with a centre fold, 3× density), with a stand-in calendar
and step counter. Half-size copies:

| | Cover screen (compact) | Opened Fold (expanded) |
|---|---|---|
| Calendar suggestions on the board | [board](screenshots/phase-3/board-calendar-cover.png), [an event that repeats a quest](screenshots/phase-3/board-calendar-match-cover.png) | [board + Map](screenshots/phase-3/board-calendar-open.png) |
| Comeback quest | [board](screenshots/phase-3/board-comeback-cover.png) | [board + Map](screenshots/phase-3/board-comeback-open.png) |
| Health Log | [form](screenshots/phase-3/health-log-cover.png) | [form + note](screenshots/phase-3/health-log-open.png) |
| Reminder in the quest editor | [editor](screenshots/phase-3/editor-reminder-cover.png) | [editor, in one pane](screenshots/phase-3/editor-reminder-open.png) |
| Settings | [calendar](screenshots/phase-3/settings-calendar-cover.png), [health and fields](screenshots/phase-3/settings-health-cover.png) | [both panes](screenshots/phase-3/settings-open.png) |
| Campfire with the Delve waiting | [card](screenshots/phase-3/campfire-delve-cover.png) | [camp + review](screenshots/phase-3/campfire-delve-open.png) |
| The Delve | [supplies](screenshots/phase-3/delve-cover.png), [outcome](screenshots/phase-3/delve-result-cover.png) | [supplies](screenshots/phase-3/delve-open.png), [outcome](screenshots/phase-3/delve-result-open.png) |

Every opened-Fold run also checks that no button, XP bar or text field sits
on the crease.

## What has and has not been verified

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 317 tests, all passing |
| `flutter build apk --debug` | See [`ACCEPTANCE.md`](ACCEPTANCE.md), item 1 |
| Delve, comeback, reminder and Health Log rules | `test/rules/phase3_rules_test.dart` |
| One event offered once; an event that repeats a quest recognised | `test/rules/suggestions_test.dart`, `test/ui/phase3_flows_test.dart` |
| Comeback, Delve, steps, calendar choices, Health Log, settings, backup | `test/data/phase3_test.dart` |
| **A Phase 2 database opens under this build with every row intact** | `test/data/phase3_test.dart`, on a database built from the Phase 2 table definitions |
| Calendar, comeback, Health Log, steps, Delve, settings and reminder flows on screen | `test/ui/phase3_flows_test.dart`, against a stand-in device |
| A quest of each completion type created and completed | `test/acceptance/completion_types_test.dart` |
| Both postures; nothing critical on the crease | `test/golden/phase3_golden_test.dart` |
| No guilt copy, no banned names, no network packages | `test/copy/copy_audit_test.dart` |

**Confirmed on the Galaxy Z Fold 8 by Adam, 14 November 2026 (version
0.3.0):** installed over the Phase 2 app with the data intact; connected
the calendar and accepted two of today's events as quests; connected Health
Connect; set a reminder, was asked for notification permission at that
point, and the reminder arrived; saved the Health Log. He sent back the
three files the app wrote (`Character Sheet.md`, `Quests.md`,
`Daily/2026-11-14.md`): they match §11, the `## Health` section carries his
entries under the field names with their units, and the numbers add up
against the rules (a Shared quest reads `13 XP + 25 Companion XP`; XP,
attribute XP, gold, materials, Bond and Paces all agree with the six quests
completed).

**Still to see on a device:** a real step count on the steps quest (the
day note sent at 01:46 has no `steps:` line, which is what the app writes
when Health Connect has no steps for the day yet); version 0.3.1's two
calendar changes; and, left over from Phase 2, Share… and restoring from a
backup.

Also worth knowing:

- The build is still a debug build, which DESIGN §9 allows. Debug builds
  declare Android's internet permission for Flutter's developer tools. The
  app has no network code and a test enforces that, but the permission is
  listed. A release build would drop it, and would be far smaller and
  smoother. It is a one-line change that waits for Adam's word
  (`DECISIONS.md` D-65).
- The Delve is not written into the Markdown files, because §11 fixes the
  list of sections. A place it restores does appear under `## World`
  (`DECISIONS.md` D-55).
- Health Connect is read through Android's own interface, which needs
  Android 14 or later. On anything older the app says so and the quest
  works by tap.
- The clockwork sprite portrait is glossier than the other nine and is the
  one to redo.
