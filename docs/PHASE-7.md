# Classes, the daily encounter and real stakes: version 0.7.1

Branch `phase-7` (built on `phase-5`). Built and tested on GitHub Actions
with Flutter 3.47.9 (Dart 3.13.7).

This is **Part A** of `docs/AMENDMENTS_v0.3_v0.4.md` (Amendment v0.3),
which Adam sent on 14 November 2026 after using the app: it feels good, but
you can never lose, and there are no roles or combat. The amendment
supersedes DESIGN §6.4 and the no-combat assumption; everything else in
DESIGN stands. What the amendment left open, and where it met something
already built, is in `DECISIONS.md` D-86 to D-100. Part B (the First Dawn
questionnaire and quest generation) is the next build, 0.8.

Version 0.7.0 was built and published first. Checking its balance level
by level, before reporting it, showed that its numbers only held on
average, so the fights were retuned the same day and 0.7.1 replaced it
(see Balance, and DECISIONS D-101). Nobody was asked to install 0.7.0.

Nothing here has been run on a phone yet.

**The build:** commit `45d3613`, run 43655165315, 458 tests passing.
`Valebound-0.7.1.apk` is 30,066,205 bytes, SHA-256
`301e7692b2fb476b9dc1146aeb1b12218baed10080a228481ec964ff2a2d33d9`
(release build, arm64, no internet permission).
`Valebound-0.7.1-debug.apk` is 169,358,371 bytes, SHA-256
`465beded0eff72d7faa59a9465f48c11c453c468b417682bbffe30c42dd9afa8`.
Both install over 0.5.2 and keep the data.

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
| The board after the win | `117_board_after_win_cover` | `117_board_after_win_open` |
| The creature held | `118_fight_held_cover` | |
| The board while it holds | `119_board_holding_cover` | |
| The class on the Party Sheet | `120_party_class_cover` | |
| The boss: report, fight, result | `75_delve_cover`, `76_delve_fight_cover`, `76_delve_result_cover` | the same with `_open` |

## Balance

The rules exist twice, in Dart and in Python (`tool/sim`), in whole
numbers so they agree exactly. The numbers are tuned in the Python model;
the Dart engine is then held to it by replaying 96 whole fights move for
move and by matching the win counts of 70,000 simulated fights exactly,
in total and level by level.
The figures below are from the Dart engine, in the build's own test log.

**Players and what they win.** Each cell is 3,500 fights: five creature
types, seven party levels (hero 1 to 20), 100 days. The pouch is empty in
all of them.

| Class | Did their quests, reads intents | Turns to win | No quests done | Ability the moment it is ready, no reading | Strike every turn | Heroic tier |
|---|---|---|---|---|---|---|
| Ranger | 82.6% | 3.7 | 60.0% | 61.0% | 39.1% | 42.6% |
| Warden | 83.3% | 4.8 | 58.3% | 90.7% | 20.2% | 43.8% |
| Sage | 88.0% | 4.3 | 79.2% | 80.4% | 22.2% | 54.7% |
| Artificer | 84.1% | 3.9 | 49.4% | 59.5% | 21.2% | 52.0% |

**The same player at each level** (quests done, reading intents; 500
fights a cell). This is the table 0.7.0 did not have a test for.

| Class | Hero 1 | 2 | 3 | 5 | 8 | 12 | 20 |
|---|---|---|---|---|---|---|---|
| Ranger | 86% | 86% | 82% | 83% | 75% | 88% | 78% |
| Warden | 80% | 83% | 80% | 79% | 77% | 90% | 94% |
| Sage | 87% | 85% | 88% | 88% | 84% | 91% | 93% |
| Artificer | 83% | 85% | 82% | 84% | 79% | 85% | 91% |

In 0.7.0 the first column read 64%, 45%, 73% and 64%, and the last 96% to
100%: the creatures' HP grew more slowly than the heroes' attack, so the
overall figure was an average of too hard early and too easy late. Two
pairings could not be won at level 1 at all, and a Warden's opening Shield
was rounded down to nothing at hero levels 1 and 2. In 0.7.1 every stat
grows in the same proportion, the creature's level follows the hero's more
closely, and the Shield is real from level 1.

Against the amendment's guardrails: about 80% on Standard for a player who
does their quests and reads intents (83–88% overall, 75–94% at any one
level); really losable by ignoring intents (20–22%, a Ranger 39% because
the companion fights every turn); three to five turns (3.7–4.8); Heroic
about a coin toss (48% across the four classes, 43–55% by class).

**A simulated week for one class.** A Warden, hero level 4, companion
level 3, finishing four quests a day of which one is a Standard Vitality
quest (Guard 7), playing the natural plan with an empty pouch:

| Day | Creature | Type | Matchup | Outcome | Turns | HP left |
|---|---|---|---|---|---|---|
| Sun 15 Nov | flutter of Hushmoths | Swarm | Hard | **held** | 6 | 0 of 55 |
| Mon 16 Nov | Lantern-eyed Mistling | Arcane | Even | won | 4 | 36 of 55 |
| Tue 17 Nov | Fogfinch | Swift | Hard | **held** | 6 | 0 of 55 |
| Wed 18 Nov | Yawnstone | Armoured | Even | won | 4 | 42 of 55 |
| Thu 19 Nov | Great Drowsel | Brute | Strong | won | 3 | 16 of 55 |
| Fri 20 Nov | drift of Mistlings | Swarm | Hard | won | 6 | 5 of 55 |
| Sat 21 Nov | Dozewisp | Arcane | Even | won | 4 | 36 of 55 |

Five of seven. This happens to be a rough week for a Warden: three of the
seven days are Hard matchups. The same week gives a Ranger six, a Sage six
and an Artificer five. Neither held day costs anything but that day's
chest and Mark, and on both a quest would have opened a second try with a
Salve.

**The boss** takes a player like this two to five weekly attempts, three
on average, at any level (reference model, 800 campaigns).

**Known unevenness.**

- The Hard pairings, with an empty pouch: Ranger against Armoured 54%,
  Warden against Swift 57%, Warden against Swarm 72%, Artificer against
  Arcane 44%. The lowest single cell is 33% (Ranger against Armoured at
  hero level 8). The right item in the pouch lifts each of them to 86% or
  more (reference model): a Salve for the Ranger and the Warden, a Smoke
  for the Artificer against Arcane, where a Salve does nothing. That is
  what the pouch is for.
- Strong pairings are close to certain (97–100%), even played carelessly.
- A Warden who Stands Firm whenever Guard allows, without reading, wins
  91%: more than the reading player modelled here. The Warden is the
  forgiving class; the others pay for not reading.
- A Sage needs quests least (79% with none done), an Artificer most (49%).
- An undefended big or heavy blow takes most or all of a hero's HP. It is
  always shown a turn ahead.

## What is not done

- **Not run on a phone.** Feel, pacing and whether a fight really takes
  two to four minutes are for the Fold to say.
- **Balance is simulated, not played.** The policies are reasonable
  players, not people, and they never use a Trap or a Bomb.
- **No new art.** The ten creatures share the six Still pictures and the
  bosses show a plain roundel.
- **Herald, combat stats on gear, a level-up fanfare from chest XP:** not
  built (DECISIONS D-100).
- **Part B** (questionnaire and quest generation) is not started.

## Tests

Rules: the matrix for every class and type; the seeded d20 and replaying a
fight; the engine against the reference model; the boss's remembered HP;
the balance guardrails, overall and at each level; no pairing shut out at
any level; a Warden's Shield at level 1. App: choosing a class and changing it with XP and
levels unchanged; an encounter from the board to its chest; the creature
holding with every earned thing compared before and after; the Salve and
the second try; a new creature the next day; a boss attempt that wears it
down for the following week; an existing database upgraded to schema 4.
