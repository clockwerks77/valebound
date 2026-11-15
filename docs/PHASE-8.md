# First Dawn, and a board made from goals: version 0.8.0

Branch `phase-8` (built on `phase-7`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7).

This is **Part B** of `docs/AMENDMENTS_v0.3_v0.4.md` (Amendment v0.4),
which Adam sent on 14 November 2026 with his verdict on 0.6: the board is a
set list of tasks, and it should instead be fashioned per user. The
amendment supersedes DESIGN §12 as what a new user starts with (§12 becomes
the template library) and extends the Dawn's rules. Amendment v0.3 (classes
and combat) stands as built in 0.7.1. What the amendment left open, and
where it met something already built, is in `DECISIONS.md` D-102 to D-117.

Nothing here has been run on a phone yet.

**The build:** commit `499a274`, run 43663072974, 525 tests passing.
`Valebound-0.8.0.apk` is 30,328,349 bytes, SHA-256
`a5c5c40eac9b6bf6389537ff8987eae8236c68430ae5ad21a9397e4c7e3e0313`
(release build, arm64, no internet permission).
`Valebound-0.8.0-debug.apk` is 169,575,655 bytes, SHA-256
`7db0caec0a2ed2ebe31250a748fa30bc09f6baedccdd6a4551cd34782f8eb201`.
Both install over 0.7.1 and earlier and keep the data (the database goes
to schema 5: two empty columns on a quest).

## (a) What works now

**1. First Dawn.** After the opening screen and the prologue, a new hero is
asked seven short chapters, one question to a screen:

| Chapter | Asks |
|---|---|
| 1. Your Story | Up to three parts of life (of seven), and one line each on what better would look like. |
| 2. Goals | The goal in a few words (starters offered), how far off it is, and how you will know it is working. |
| 3. Habit Design | For each goal, one habit (a second can be added): what, when in the day it attaches, how often, its three sizes, whose quest it is, and how it feels. |
| 4. Your Rhythm | When the day starts and ends, the working week, when energy is best, rest days, and sprints or steady. |
| 5. Class & Companion | Six questions, then the four classes with the scores' reasoning in words; whether the companion is a real animal, and its name and kind. |
| 6. Calendar | The promise, then which calendars count, then the recurring events, each named once. |
| 7. Your First Week | The week day by day with every quest's For-line; lighter or fuller; the first camp. |

Every chapter ends in a "Here's what I heard" screen whose lines can be
tapped to change them. Every question has "Skip chapter". The close button
leaves it where it is: the board then shows "Tell Valebound your goals ·
Carry on", and it resumes at the same question. Answers are saved after
each one and become goals and habits only at the end. Goals are capped at
three, habits at two a goal. It ends on the board, not on a tour.

**2. The chain.** Goal, to habit plan, to that day's quest. Each Dawn the
board is the habit plans due, the day's mapped calendar events, and the
app's own quests (the Campfire), with duplicates joined. Every card says
what it is for:

- `For: Feel stronger · at lunch` (a goal, and the habit's anchor)
- `For: your calendar · 10:30 – 11:15`
- `For: closing the day` (the Campfire)
- `For: you · not pinned to a goal yet` (a quest of your own)

A habit's card carries a size chip. One tap moves Target to Stretch to Tiny
and round again, and the card's words and XP change with it. **Tiny is
worth Minor XP and the quest is done in full.** A habit that feels Heavy is
worth Heroic at its Target, and two heavy habits are never placed side by
side.

The class pass adds nothing to the board. While the day's encounter is
open it marks the one quest that best feeds the class resource ("Feeds
Guard"), and the scout's report gains one line about today's board.

**3. The calendar.** Asked in Chapter 6, with the amendment's words:
"Valebound reads today's events on this phone only. Nothing leaves the
device. Event titles are never written to logs; you choose what becomes a
quest." Each calendar can be switched off. Recurring events (twice or more
in the next four weeks) are listed once to be named: Commitment, Health,
Craft block, Social, Travel or Ignore. A mapped event becomes a quest by
itself on its days. One you mark "This is my habit" joins that habit's
quest: one quest, not two. One marked "It takes a lot out of me" may be
offered a small Prep before and a Follow-through after; each offer can be
taken, left for today, or turned off for that event for good. An event's
title is shown on the board and is not written to the completion log or to
any export unless "Include event names in exports" is on in Settings (off
by default); it reads "Calendar commitment" otherwise.

**4. The Sunday Check-In.** At the Campfire on the Delve's day: how the
week felt (too light, about right, too heavy), each habit's count by size,
and at most one proposed change. "Yes, change it" makes it from tomorrow.
"No, leave it" is remembered and that proposal is never put again. Nothing
changes by itself, and there is no score or percentage anywhere.

**5. A hero from before 0.8.** Nothing is asked at once and nothing is
archived. The board shows one card, "Tell Valebound your goals" (Begin, or
Later, after which it lives only in Settings). In Chapter 7 the quests you
already have arrive unpinned, each with three choices: pin it to one of
your goals, keep it as it is, or archive it to the Quest Log. Nothing is
deleted.

**6. Export.** `Goals & Habits.md` is written with every export. The day's
quest table gains a `For` column. Samples are in `docs/samples/`.

**Also:** Settings has "Goals & habits" (New goal runs a short version of
the flow; a goal can be archived with its habits) and "Review recurring
events". For a new hero who designs at least one habit, the starter quests
step back into the Quest Log, archived, where any can be brought back; for
someone who skips everything, they are the board.

## (b) How to try it

**As you are now (an existing hero):**

1. Install over the version on the phone. Your quests, XP and class are as
   they were.
2. On the board, find "Tell Valebound your goals" and tap **Begin**.
3. Answer what you like and skip what you do not. Close it part way once,
   to see it wait on the board and carry on.
4. In Chapter 6, connect the calendar and name your recurring events.
5. In Chapter 7, go through "The quests you already have": pin, keep or
   archive each.
6. Back on the board, read the For-lines, and tap a habit's size chip.
7. On Sunday, close the day at the Campfire and answer the check-in.

**As a new hero:** the same seven chapters open by themselves after the
prologue, and the starter quests step back once a habit is designed. That
needs a clean install; take a backup in Settings first, which restores
everything, goals included.

## (c) Screenshots

Rendered by the test suite at the cover-screen (416 × 657) and opened-Fold
(816 × 616) sizes. JPEG copies at three fifths size are in
`docs/screenshots/phase-8/`; each name below exists with `_cover` and
`_open`.

| Chapter | Screens |
|---|---|
| 1. Your Story | `130_c1_story_domains`, `131_c1_story_why`, `132_c1_story_mirror` |
| 2. Goals | `133_c2_goals_goal`, `134_c2_goals_horizon`, `135_c2_goals_check`, `136_c2_goals_mirror` |
| 3. Habit Design | `137_c3_habit_what`, `138_c3_habit_anchor`, `139_c3_habit_often`, `140_c3_habit_size`, `141_c3_habit_track`, `142_c3_habit_dread`, `143_c3_habit_mirror` |
| 4. Your Rhythm | `144_c4_rhythm_wake`, `145_c4_rhythm_rest`, `146_c4_rhythm_burst`, `147_c4_rhythm_mirror` |
| 5. Class & Companion | `148_c5_class_quiz`, `149_c5_class_recommended`, `150_c5_class_companion`, `151_c5_class_mirror` |
| 6. Calendar | `152_c6_calendar_promise`, `153_c6_calendar_which`, `154_c6_calendar_series`, `155_c6_calendar_series_habit`, `156_c6_calendar_mirror` |
| 7. Your First Week | `157_c7_week_review`, `158_c7_week_calibrate`, `159_c7_week_camp` |
| The board it ends on | `160_board_after_first_dawn` |
| A hero from before 0.8 | `165_offer_on_board`, `166_existing_quests_review` |
| The Sunday Check-In | `167_checkin`, `168_checkin_proposal` |
| Goals & habits in Settings | `169_settings_goals` |

Chapter 4's other three questions (when the day ends, the working week,
the energy peak) are the same screen as `144` with different words, and
were not photographed separately. The opened-Fold walk is also checked for
nothing on the crease on five of its screens.

## Tests

525 tests pass, 67 of them new in this version. The five asked for:

| Asked for | Test |
|---|---|
| A scripted questionnaire run produces a Week 1 board where every quest has a valid source and For-line | `test/data/phase8_test.dart`: "a scripted run makes a Week 1 board where every quest has a source and a For-line"; and through the screens, `test/ui/phase8_flows_test.dart`: "a new hero walks all seven chapters and comes out on a board made from the answers" |
| A calendar event that matches a habit plan generates exactly one quest | "a calendar event that is a habit plan makes exactly one quest" |
| Tiny completion awards Minor XP and full credit | "a Tiny completion awards Minor XP and counts in full; Target and Stretch are worth more"; on the card, "one tap cycles the size; Tiny is worth Minor XP and the quest is done in full" |
| Declining a Sunday proposal never re-proposes it | "declining a proposal never re-proposes it"; at the Campfire, "two questions at the Campfire, one proposal, and "no" is final" |
| Skipping all chapters still yields a working template board | "skipping every chapter still leaves a working board: the starter quests, each with a For-line"; through the screens, "skipping every chapter still lands on a working starter board" |

Also covered: leaving First Dawn part way and resuming; the existing hero's
offer, "Later", and the review where nothing is deleted; a heavy habit's
Heroic weight; a rest day and week one's calibration; a mapped, an unmapped
and an ignored event, with the title kept out of the log; the export
toggle; Prep and Follow-through offers and "never for this one"; the
mapping pass over four weeks; "not now" not asked again for a season; a
change proposed and not made until yes; goals and plans through a backup;
an existing database upgraded to schema 5; the `For` column and
`Goals & Habits.md`; a goal added later from Settings.

## What is not done

- **Not run on a phone.** Whether seven chapters feel short on the cover
  screen is for the Fold to say.
- **Three of Chapter 4's answers do nothing yet.** When the day starts and
  ends and the working week are asked, shown back and kept, and the screens
  say so. Energy peak, rest days and sprints are used (D-109).
- **Calendar events as anchors in Chapter 3:** not built, because the
  calendar is asked for after it.
- **Editing a goal's words, or adding a second habit to a goal, after First
  Dawn:** not built. A goal can be archived and a new one raised; a habit's
  words, days and track can be changed in the Quest Log.
- **Dictation** is the keyboard's own microphone.
- **The JSON backup** is the whole database, so a calendar quest's name is
  in it. The Markdown exports and the completion log are as the amendment
  says.
- **No quest is ever made for the encounter.** The amendment names
  "encounter" as a source and also says the class pass never invents an
  obligation; the second was followed (D-105).
- **No new art.**
