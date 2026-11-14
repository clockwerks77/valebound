# Classes, the daily encounter and real stakes: version 0.7.0

Branch `phase-7` (built on `phase-5`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7).

This is **Part A** of `docs/AMENDMENTS_v0.3_v0.4.md` (Amendment v0.3),
which Adam sent on 14 November 2026 after using the app: it feels good, but
you can never lose, and there are no roles or combat. The amendment
supersedes DESIGN §6.4 and the no-combat assumption; everything else in
DESIGN stands. What the amendment left open, and where it met something
already built, is in `DECISIONS.md` D-86 to D-100. Part B (the First Dawn
questionnaire and quest generation) is the next build, 0.8.

Nothing here has been run on a phone yet.

## (a) What works now

- **Four classes.** Ranger, Warden, Sage and Artificer, each with a home
  attribute, a resource, a passive and one ability. A hero with no class
  chooses one: a new hero straight after the prologue, an existing hero on
  the first launch of 0.7. Herald is held in the code and not offered.
- **Your quests are your strength.** The class resource for a fight is
  worked out from the quests finished that day: more from the class's own
  attribute, a little from every other quest. With nothing done you can
  still fight, at the base.
- **Today's encounter.** One creature of the Still holds the road each
  day: its row is on the board, under the road strip. Tapping it opens the
  scout's report (its type, how your class fares, its weakness, what you
  are carrying), a choice of Standard or Heroic, and then the fight.
- **The fight.** Turn by turn, two to four minutes. The creature's next
  move is shown before you act. You Strike, use your class ability, Defend
  (which halves what is coming and adds a resource) or use something from
  the pouch; your companion joins in when ready. The dice are d20s, shown
  in the log, and seeded by the day.
- **Five kinds of creature** and the class matrix from the amendment:
  each class finds two kinds easier, one or two harder, and the scout says
  which and why.
- **You can lose the fight.** If the creature holds, there is no chest and
  no Boss Mark. Nothing you have earned is touched. Finish any quest for a
  Salve and another try (the dice fall the same, so the plan has to
  change), or meet a new creature tomorrow.
- **A win brings a chest:** gold, materials toward the place being
  restored, a consumable, a little XP for you and your companion, and a
  Boss Mark.
- **The weekly Delve is a boss.** Seven turns. What you take off it stays
  off, so a boss is a few weeks' campaign. Three Boss Marks buy one opening
  advantage. Waking it brings the week's big restoration and a title.
- **A free change of class** at the Campfire on the Delve's day. XP,
  levels and everything gathered stay.
- **The day's note** gains an `## Encounter` section.

## (b) How to try it

1. Install over 0.5.2 and open it. You are asked to choose a class.
2. On the board, tap the encounter row (under the road strip).
3. Read the scout's report, pick Standard, and go in.
4. Watch "ITS NEXT MOVE" each turn. Defend the heavy or big blow; use your
   ability when the resource allows.
5. If it holds: finish any quest, then tap "Try again" on the board.
6. Character tab: scroll to **Class** for the matrix and what is in the
   pouch.
7. On Sunday, close the day at the Campfire, then **Enter the Delve**.

## (c) Screenshots

Rendered by the test suite at the cover-screen and opened-Fold sizes; the
opened-Fold fight is also checked for nothing on the crease. JPEG copies at
three fifths size are in `docs/screenshots/phase-7/`.

| Screen | Cover | Open |
|---|---|---|
| Choosing a class | `110_class_choice_cover` | `110_class_choice_open` |
| The board with today's encounter | `112_board_encounter_cover` | `112_board_encounter_open` |
| The scout's report | `113_scout_cover` | `113_scout_open` |
| The fight, first turn | `114_fight_first_turn_cover` | `114_fight_first_turn_open` |
| The fight, the big blow due | `115_fight_big_blow_due_cover` | `115_fight_big_blow_due_open` |
| Won, with the chest | `116_fight_won_cover` | `116_fight_won_open` |
| The creature held | `118_fight_held_cover` | |
| The board while it holds | `119_board_holding_cover` | |
| The class on the Party Sheet | `120_party_class_cover` | |
| The boss: report, fight, result | `75_delve_cover`, `76_delve_fight_cover`, `76_delve_result_cover` | the same with `_open` |

## Balance

The rules exist twice, in Dart and in Python (`tool/sim`), in whole
numbers so they agree exactly. The numbers were tuned in the Python model;
the Dart engine is then held to it by replaying 96 whole fights move for
move and by matching the win counts of 70,000 simulated fights exactly.
These figures are from the Dart engine in the build's own test log.

Each cell is 3,500 fights: five creature types, seven party levels (hero 1
to 20), 100 days.

| Class | Did their quests, reads intents | Turns to win | No quests done | Ability the moment it is ready, no reading | Strike every turn | Heroic tier |
|---|---|---|---|---|---|---|
| Ranger | 85.1% | 4.7 | 65.5% | 44.7% | 23.5% | 37.7% |
| Warden | 80.0% | 5.1 | 53.4% | 80.0% | 26.5% | 47.5% |
| Sage | 89.0% | 4.6 | 78.5% | 83.1% | 24.6% | 64.3% |
| Artificer | 85.1% | 4.1 | 50.9% | 47.8% | 25.8% | 59.1% |

Against the amendment's guardrails: about 80% on Standard for a player who
does their quests and reads intents (80–89%); really losable by ignoring
intents (24–27%); three to five turns (4.1–5.1); Heroic about a coin toss
(52% across the four classes, 38–64% by class).

**A simulated week for one class.** A Warden, hero level 4, companion
level 3, finishing four quests a day of which one is a Standard Vitality
quest (Guard 7), playing the natural plan:

| Day | Creature | Type | Matchup | Outcome | Turns | HP left |
|---|---|---|---|---|---|---|
| Sun 15 Nov | flutter of Hushmoths | Swarm | Hard | won | 6 | 7 of 57 |
| Mon 16 Nov | Lantern-eyed Mistling | Arcane | Even | won | 6 | 44 of 57 |
| Tue 17 Nov | Fogfinch | Swift | Hard | **held** | 6 | 0 of 57 |
| Wed 18 Nov | Yawnstone | Armoured | Even | won | 4 | 48 of 57 |
| Thu 19 Nov | Great Drowsel | Brute | Strong | won | 3 | 22 of 57 |
| Fri 20 Nov | drift of Mistlings | Swarm | Hard | won | 6 | 9 of 57 |
| Sat 21 Nov | Dozewisp | Arcane | Even | won | 6 | 44 of 57 |

Six of seven, with two close ones. The boss, at these levels, takes a
player like this two to four weekly attempts.

**Known unevenness.** The three Hard pairings sit near 50–60% even for a
careful player: Warden against Swift, Ranger against Armoured, Artificer
against Arcane. An Artificer with no quests done almost never beats an
Arcane creature without something from the pouch. A level 1 hero with no
quests done wins about half the time; the first days are the hardest.

## What is not done

- **Not run on a phone.** Feel, pacing and whether a fight really takes
  two to four minutes are for the Fold to say.
- **Balance is simulated, not played.** The policies are reasonable
  players, not people.
- **No new art.** The ten creatures share the six Still pictures and the
  bosses show a plain roundel.
- **Herald, combat stats on gear, a level-up fanfare from chest XP:** not
  built (DECISIONS D-100).
- **Part B** (questionnaire and quest generation) is not started.

## Tests

Rules: the matrix for every class and type; the seeded d20 and replaying a
fight; the engine against the reference model; the boss's remembered HP;
the balance guardrails. App: choosing a class and changing it with XP and
levels unchanged; an encounter from the board to its chest; the creature
holding with every earned thing compared before and after; the Salve and
the second try; a new creature the next day; a boss attempt that wears it
down for the following week; an existing database upgraded to schema 4.
