# After the first run on the Fold: version 0.4.0

Branch `phase-4` (built on `phase-3`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7). App version 0.4.0.

This is not one of the three phases in the brief. It is what Adam asked for
on 14 November 2026 after using 0.3.0 on the Fold: a daily challenge, his
Libre 2 glucose readings, and a tutorial. Each changes the design, so each
has a dated amendment in `docs/DESIGN.md` and a decision in `DECISIONS.md`
(D-70 to D-73).

## The game loop, for reference

- **Each quest:** do the real thing, tap it. Your own quests pay XP, gold
  and materials. The companion's pay Companion XP, Bond and a Pace.
- **Each day:** the Dawn board, the day's Still creature to wake (new), and
  the Campfire to close the day and write it to the vault.
- **Every few days:** materials wake a place and a villager comes home;
  every 10 Paces is a Discovery; levels, titles and companion tricks arrive.
- **Each week:** the Delve at the Campfire.

Nothing can be lost anywhere in it (DESIGN §6.4).

## (a) What works now

- **The day's Still creature.** One of the six creatures turns up each
  Dawn, dozing by the place you are restoring. It has its own row in the
  board's header strip, with three pips. Every quest you finish that day
  lights a pip. The third wakes it: it leaves 3 gold and one material of
  the kind that place still needs, and the quest's reward says so. The
  Campfire lists it under what changed in the Vale. If it sleeps on, a
  different creature is there tomorrow and nothing is recorded. It gives no
  XP.
- **Glucose from Health Connect.** Settings → Health has a Glucose block
  with **Connect glucose**. Once connected, the app reads the blood glucose
  readings that another app has put in Health Connect and shows their
  average for the day, as a number, at the top of the Health Log and in
  Settings. The same figure goes into the day note's `## Health` section as
  `Average glucose`. A reading you type into "Glucose" is separate and stays
  exactly as typed. No targets, no advice, and nothing is written back.
- **The tour.** The first time the app opens after this update, eleven
  bubbles walk the board. Each dims the screen and lights the thing it
  describes. **Skip the tour** is on every bubble but the last. The Map, the
  Character screen, the Quest Log and the Campfire each show one bubble the
  first time they are opened. Settings → About → **Show the tour again**
  brings all of it back.
- **Whole-day figures.** When the app is opened on a new day, yesterday's
  full step count and glucose average are written back, so that day's note
  carries the whole day and not just what had happened when the app was
  last open. Yesterday's quests are not completed after the fact.

## (b) How to try it

Install over the top; your data stays.

1. Download `app-debug.apk` from the `latest-debug` release and install it.
   The tour starts by itself. Walk it, or skip it and bring it back from
   Settings → About.
2. **Creature.** Look at the third row of the strip under your level bars.
   Finish three quests and watch the pips; the third quest's reward names
   the creature and what it left.
3. **Glucose.** Settings → Health → **Connect glucose**, and allow blood
   glucose in the Health Connect sheet. What happens next depends on
   whether any app on the phone is putting readings into Health Connect:
   - If one is, the Health Log shows "Average glucose today" with the number
     of readings behind it.
   - If none is, it says "nothing from Health Connect yet today" and keeps
     nothing. That is the likely result with Abbott's app alone (see below).
4. **Steps.** Tomorrow morning, look at today's note in the vault: `steps:`
   should be the whole day's count.

## Getting Libre 2 readings into Health Connect

This part is outside the app, and it is a decision about how you run a
medical device, so it is yours to make. What was found on 14 November 2026:

- Abbott's own pages describe two ways the Libre apps share readings:
  LibreView (their cloud) and LibreLinkUp (their follower app). Nothing on
  them says the app writes to Health Connect.
- Juggluco, a third-party Android app, reads Libre 2 sensors directly and,
  by its own description, can send readings to Health Connect.
- Juggluco's listing also says that once it has scanned a Libre 2 sensor,
  Abbott's app can only scan that sensor. Check what that means for the
  alarms and automatic readings you rely on before trying it.

A quick way to see where you stand without installing anything: open Health
Connect in Android's settings and look at which apps have access and
whether it holds any blood glucose data.

Sources: [Abbott, Connected Care](https://www.freestyle.abbott/ie-en/products/connected-care.html);
[Juggluco on SourceForge](https://sourceforge.net/p/juggluco);
[Juggluco listing](https://apkcombo.com/juggluco/tk.glucodata/).

## (c) Screenshots

Rendered by the test suite at Galaxy Z Fold 8 panel sizes, with a stand-in
step counter and glucose source. Half-size copies:

| | Cover screen (compact) | Opened Fold (expanded) |
|---|---|---|
| Tour: welcome | [bubble](screenshots/phase-4/tour-welcome-cover.png) | [bubble](screenshots/phase-4/tour-welcome-open.png) |
| Tour: you and your companion | [bubble](screenshots/phase-4/tour-party-cover.png) | [bubble](screenshots/phase-4/tour-party-open.png) |
| Tour: the day's creature | [bubble](screenshots/phase-4/tour-sleeper-cover.png) | [bubble](screenshots/phase-4/tour-sleeper-open.png) |
| Tour: a quest | [bubble](screenshots/phase-4/tour-quest-cover.png) | [bubble](screenshots/phase-4/tour-quest-open.png) |
| Tour: the Campfire | [bubble](screenshots/phase-4/tour-campfire-cover.png) | [bubble](screenshots/phase-4/tour-campfire-open.png) |
| Tour: getting around | [bubble](screenshots/phase-4/tour-nav-cover.png) | [beside the rail](screenshots/phase-4/tour-nav-open.png) |
| A screen's one-time hint | [Map](screenshots/phase-4/hint-map-cover.png) | |
| The creature awake | [board](screenshots/phase-4/board-creature-awake-cover.png) | |
| Glucose | [Health Log](screenshots/phase-4/health-log-glucose-cover.png), [Settings](screenshots/phase-4/settings-glucose-cover.png) | |

Every bubble on the opened Fold is checked to sit wholly on one side of the
crease.

## What has and has not been verified

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 361 tests, all passing |
| `flutter build apk --debug` | Succeeds (commit `c0d4e11`, run 43573409549): 162,921,267 bytes, SHA-256 `c5b986f0…5542c62`, signed with the fixed key, published as the `latest-debug` release |
| The creature: turns, stirs, waking once, the gift, no XP | `test/rules/daily_still_test.dart`, `test/data/daily_still_test.dart` |
| Glucose: the average kept and exported, typed readings untouched, nothing for a day never opened | `test/data/glucose_test.dart` |
| The creature, glucose and the tour on screen | `test/ui/phase4_flows_test.dart`, against a stand-in device |
| Both postures; bubbles clear of the crease | `test/golden/phase4_golden_test.dart` |

**Not yet run on a device:** all of 0.4.0. In particular the code that reads
blood glucose from Health Connect compiles and is in the build, but has
never run on a phone, and it can only show a figure if some app is putting
readings there.

Also worth knowing:

- The sample files in `docs/samples` were regenerated. Their format is
  unchanged; gold and materials are a little higher because a three-quest
  day now brings the creature's gift.
- Neither the creature nor the Delve is written into the Markdown files,
  because DESIGN §11 fixes the sections. A place the creature's gift
  restores does appear under `## World`.
- Time in range is still a field you type. Working it out from the readings
  would need a target range in the app, which §9.3 rules out and you did
  not ask for.
