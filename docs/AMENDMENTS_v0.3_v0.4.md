# Valebound — COMBINED Amendments v0.3 + v0.4 (send this ONE file)

## How to use this bundle (for Adam)

This bundle contains BOTH amendments in full, in order. Drop this single file into the live Claude session and paste the combined prompt at the very end of this file. Claude builds Part A (v0.3, classes + combat) as v0.7 first, reports back, then Part B (v0.4, questionnaire + quest generation) as v0.8. Do NOT send Amendment v0.4 alone expecting it to contain v0.3 — it does not; that is why this bundle exists.

---

# PART A — Amendment v0.3 (build first, as v0.7)

# Valebound — Amendment v0.3: Classes, Combat & Real Stakes
## For the v0.6 → v0.7 iteration (14 Nov 2026, from Adam's hands-on feedback)

**Adam's feedback, in his words in substance:** v0.6 *feels really good*, but it needs more gamification. You can never lose, and there are no roles or combat. He suspects that has to change. He wants: choose-your-class, each class with different abilities/capabilities, a link between class and the challenges ahead, and some form of combat as a **daily challenge — a game part** of the day.

**Status:** This amendment *supersedes* DESIGN.md where they conflict — specifically §6.4 (failure rules) and the "no combat" implication of §§3/14. Everything else in DESIGN.md v0.2 stands (Fold layouts, companion system §7A, Obsidian export §11, IP guardrails §13, no-network §9.2).

---

## 1. The design correction — what "losing" now means

The v0.2 design over-corrected. It banned losing entirely to avoid shame mechanics, and in doing so removed tension, choice, and game feel. The fix is to split "losing" in two:

> **You can lose a fight. You cannot lose who you've become.**

**CAN be lost (new — this is the game):**
- A daily encounter, or a weekly boss attempt
- The encounter's bonus loot, chest, and bonus XP
- A day's optional bonus restoration (the enemy "holds the road" until tomorrow)
- Position/time in a boss fight (boss attempts are turn-limited, §5)

**STILL can never be lost (unchanged, locked):**
- XP, levels, attribute progress, companion XP/Bond, gear, titles
- World restoration already earned, Journey discoveries already found
- Anything to a missed day, a streak, or a real-life bad week

**Tone rule (unchanged):** a defeat screen says what happened in the *fight* and what to try next ("The Armoured Still held. A trap would crack it — or finish a quest to earn a Salve and retry."). It never comments on the player's real life, habits, or worth. No guilt copy, ever — but a monster absolutely may win.

## 2. Classes — choose your class (v0.7: four classes)

Chosen at onboarding (existing users: chosen on first v0.7 launch, no progress reset). Class is identity + playstyle + which real-life quests supercharge your combat. **Free respec at Sunday Campfire** — experimentation is encouraged, class is never a trap. All classes can beat all enemies; class changes *how hard* a given enemy is and *which strategy* is natural (§4 matrix). Companion damage is always the off-type safety valve, so no one is hard-locked out of a fight.

| Class | Role | Home attribute | Resource (earned from quests) | Passive | Signature ability (daily cooldown or resource cost) |
|---|---|---|---|---|---|
| **Ranger** | Striker / Scout | Adventure (+ Care via companion) | **Focus** — from Adventure & Shared quests | Companion acts more often; Shared quests grant +1 Focus | **Companion Volley** — companion strikes for heavy Swift damage scaled by companion level + Bond |
| **Warden** | Tank / Protector | Vitality | **Guard** — from Vitality & health quests | Converts Guard to a Shield that absorbs damage before HP | **Stand Firm** — gain a large Shield and force the enemy to target it (ignore companion) for 2 turns |
| **Sage** | Controller | Mind | **Insight** — from Mind quests | Enemy intent and weakness are fully revealed (other classes see intent only) | **Exploit** — spend Insight to stun 1 turn and deal Arcane damage; stronger the more Insight spent |
| **Artificer** | Tactician / Debuffer | Craft | **Scrap** — from Craft quests | Craft quests also stock consumables (traps, salves, bombs) | **Deploy Trap** — breaks Armour, damage-over-time for 3 turns, ignores Swift evasion |

*Design for, do not build in v0.7:* a fifth class, **Herald** (Support/Healer, home attribute Order, resource Morale from calendar/Order quests, a once-per-encounter reroll and a Rally heal) — the data model gets a class enum that can grow, the UI ships with four.

**Co-op forward-compat (note only):** these are real party roles — Warden holds intent, Ranger deals damage, Sage controls, Artificer debuffs, Herald heals. When party play arrives (§2 of DESIGN.md), a group covers roles; solo, the companion + consumables cover the gaps.

## 3. The Daily Encounter — the game part of the day

- **One encounter per day**, generated at Dawn, playable any time (the natural moment is after a few quests, when resources are stocked — the Dawn board shows it as "Today's Encounter" with the enemy's type and a one-line scout report).
- **Length:** 2–4 minutes. Turn-based. Hero + companion vs one enemy (occasionally a Swarm of 2–3 weak ones).
- **Enemy build:** HP and damage scaled to party (hero + companion) level. Every enemy has: a **type tag** (Swift / Armoured / Brute / Swarm / Arcane — drives the class matrix in §4), a **telegraphed intent** each turn (what it will do next — attack hero, attack companion, charge a big hit, heal/armour up), and one **weakness** and one **resistance**, stated in the scout report in plain language.
- **Your turn — pick one main action + companion command when available:**
  - **Strike** — basic attack in your class's damage type
  - **Class Ability** — §2 signature, costs resource/cooldown
  - **Defend / Rest** — halve incoming damage this turn, gain +1 resource
  - **Use Item** — a consumable (Salve = heal, Trap, Bomb, Smoke = skip enemy turn) from the Artificer-fed shared pool; items come from quests and loot, never purchases
  - **Companion Command** — every second turn, order the companion's trick (per §7A.3 tricks; damage type differs from hero's — the off-type option)
- **Chance:** visible hit chances (75–95%), crits on high rolls, D&D-flavoured dice shown on screen. **The day's rolls are seeded:** retrying with the same actions gives the same rolls — a retry is a *strategy puzzle* (change actions, spend an item, or go complete a quest to earn resource/a Salve), not save-scumming.
- **Energy link to real life:** you enter with combat resources earned from today's completed quests (Minor +1, Standard +2, Heroic +3 toward your class resource, capped). Zero quests done = you *can* still fight, at base resource — the encounter is a game, not a gate — but a day lived well makes you visibly stronger. This is the class ↔ challenge ↔ habits link Adam asked for.

## 4. Class ↔ Challenge matrix (the link, made explicit)

Damage effectiveness: **Strong** = +50% and a bonus effect, **Normal** = as written, **Hard** = −33% (still winnable with items/companion/defend timing).

| Enemy type | Ranger | Warden | Sage | Artificer |
|---|---|---|---|---|
| **Swift** (evasive, hits often, low HP) | Strong — companion tracks it | Hard — big hits get dodged | Normal — Exploit ignores evasion when stunned first | Strong — traps don't miss |
| **Armoured** (high mitigation, slow) | Hard — arrows glance off | Normal — outlast it | Normal — Arcane bypasses some armour | Strong — trap breaks armour |
| **Brute** (huge hits, telegraphed charge) | Normal — kite with Defend turns | Strong — shield the charge | Strong — stun the charge turn | Normal |
| **Swarm** (many small hits) | Strong — Volley hits all | Hard — shield is per-hit inefficient | Normal | Strong — Bomb hits all |
| **Arcane** (buffs/debuffs, trick intents) | Normal | Normal | Strong — reads every intent | Hard — devices get disrupted |

The scout report names the matchup in words ("Armoured — your Volley will struggle; your companion and traps won't"), so the player always knows *why* a fight is hard and has a named alternative.

## 5. Winning, losing, and the weekly boss

- **Win:** encounter chest — gold/materials, a consumable, bonus XP (hero + companion), and +1 Boss Mark.
- **Lose (hero HP hits 0):** the encounter ends, the enemy holds the road for today: no chest, no bonus, no bonus restoration today. Hero returns to camp at full HP. **Retry** is allowed after completing *any* quest (which earns a Salve + fresh resources), or free tomorrow against a new enemy. Nothing else is touched — §1's list is exhaustive.
- **Companion in combat:** companion can be targeted and "winded" (out for the rest of that encounter) but never injured beyond the fight, never loses Bond. Winded is a combat state, not a punishment.
- **Weekly Boss (extends the §3B Delve):** Sunday's Delve becomes a real boss fight in the same system — 7-turn limit, boss intents in phases, Boss Marks from the week buy one opening advantage (player's choice: boss starts debuffed / party starts shielded / extra consumable). **You can lose the boss** (turn limit expires) — but **boss HP damage persists week to week**: a lost attempt still chips the boss, so a multi-week boss is a campaign, not a wall. Defeating it grants the week's major restoration + a title.

## 6. Data & UI deltas (for Claude)

- `Character` gains: `classId` (enum, extensible), `respecAvailableAt`, combat stats derived from level + class (never stored raw where a formula suffices).
- New entities: `Encounter` (date, enemyId/type, seed, state, outcome), `EnemyTemplate` (type, intents, weakness/resistance), `Consumable` (kind, count), `BossState` (bossId, hpRemaining, marks).
- HP is encounter-scoped (hero + companion), reset at camp — it is **not** a persistent character stat and never appears in the Obsidian export as a health fact. Daily export gains one line under `## World` or a new `## Encounter` section: enemy, result, class used. (Update DESIGN.md §11 sample accordingly.)
- Screens: class choice joins onboarding; Party Sheet gains class panel (role, resource, ability, matrix hints); a dedicated **Encounter screen** — opened Fold: enemy + intent on one pane, actions + combat log on the other; cover screen: stacked, big action buttons, completable one-handed.
- Balance guardrails: a same-level Standard encounter should be winnable by any class in 3–5 turns using its natural strategy, and *losable* in 3–5 turns by ignoring intents entirely. Playtesting target: a player who does their quests and reads intents wins ~80% on Standard; Heroic tier (optional difficulty at encounter start, +50% rewards) ~50%.

## 7. Scope fence for this iteration (v0.7)

**In:** 4 classes + onboarding/respec, class resources from quests, Daily Encounter (§3) with 5 enemy types (≥2 templates each), consumables pool, win/lose/retry per §5, Boss Marks + persistent-HP weekly boss in the Sunday Delve, export delta, balance pass per §6 guardrails.
**Out (later):** Herald class, PvP, multiplayer roles in live combat, equipment with combat stats (gear stays cosmetic in v0.7), random loot tables beyond the encounter chest, any persistent HP/injury system, any loss of XP/progress (§1 is locked).

---

## Paste-in for Claude (send with this file, in the live v0.6 session)

```
Design amendment — read AMENDMENT_v0.3_CLASSES_AND_COMBAT.md in full. It supersedes DESIGN.md §6.4 and the no-combat scope assumptions; everything else in DESIGN.md still stands.

Adam's hands-on verdict on v0.6: it feels really good, but it needs more gamification — real classes, real combat, and the ability to actually lose a challenge. Build v0.7 to the amendment:

1. Four classes (Ranger, Warden, Sage, Artificer) with onboarding choice, free Sunday respec, class resources earned from the matching attribute's quests, passives and signature abilities per §2. Herald is data-model-ready only — do not build it.
2. The Daily Encounter per §3: seeded dice, telegraphed intents, the five enemy types and the §4 effectiveness matrix, consumables, companion commands. Standard should be winnable ~80% by a player who did their quests and reads intents — and genuinely losable by one who ignores them.
3. Losing works exactly per §§1/5: you can lose the fight, the chest, and today's bonus — you can never lose XP, levels, restoration, Bond, or anything to a missed day. Boss HP persists across weekly attempts. Defeat copy talks about the fight and the next strategy, never about the player's real life.
4. Keep everything else working: companion tracks, Fold layouts in both postures (Encounter screen included), Obsidian export with the new Encounter line, no network, no new analytics.

Tests: matrix effectiveness per class/enemy type, seeded-roll determinism on retry, lose-path leaves all progression untouched, respec keeps XP/levels, boss HP persists after a lost attempt. Report back with the balance numbers from a simulated week for one class, not just "it works."
```


---

# PART B — Amendment v0.4 (build second, as v0.8)

# Valebound — Amendment v0.4: Onboarding Questionnaire & Quest Generation
## For the v0.8 iteration (14 Nov 2026, from Adam's hands-on feedback)

**Adam's feedback, in substance:** v0.6 just hands you a set list of tasks. When you first open the app there should be **a series of questionnaires** to help you work out what habits *you* want to track, and daily quests and missions should be **fashioned from that** — linking together (1) your calendar, (2) your stated habit-forming goals, and (3) your class.

**Status:** This amendment supersedes DESIGN.md §12 (seeded quests) as the *default new-user experience* and extends §§4/8/9.3/10/11. The §12 list becomes a **template library**, not a starting board. Amendment v0.3 (classes/combat) is assumed built or in build — this amendment is its natural pair: the questionnaire is also how class gets recommended (§3, Chapter 5).

---

## 1. The principle

> **No quest without a source.** Every daily quest must be traceable to at least one of: a stated goal, a calendar commitment, or the day's encounter — and the quest card says which, in one short "For:" line.

A generated board beats a seeded list in three ways: it is *yours* (goals you stated, in your words), it is *timed* (calendar-aware, energy-aware), and it is *class-aware* (it stocks the resources tonight's encounter needs). The seeded templates failed all three — they were a demo board that shipped.

## 2. Quest generation — the chain

```
Stated Goal  →  Habit Plan  →  Daily Quest instances
     ↑               ↑                  ↑
 questionnaire   questionnaire    calendar + class + history
```

- **Goal** — something the user stated ("Feel stronger", "Finish my army", "Be present with my dog"), with a life domain, a why-line in their own words, and a horizon (this month / this season / ongoing).
- **Habit Plan** — the repeatable behaviour that serves a goal, designed in the questionnaire (§3, Ch. 3): an **anchor** (an existing daily moment it stacks onto — "after morning coffee", "after Babs' walk"), a frequency, a preferred time window, an attribute, a track (Hero/Companion/Shared, §7A.2), and **three sizes** (§4).
- **Daily Quest** — the instance generated at Dawn from: habit plans due today + today's calendar (Chapter 6 mappings) + class/encounter needs (§5) + adaptive history (§6). De-duplicated: if a calendar event *is* a habit plan (a scheduled painting block), they merge into one quest, not two.

## 3. The questionnaire — "First Dawn" (onboarding)

A series of short chapters, **one question per screen**, large tap targets, voice-dictation friendly, progress visible ("Chapter 3 of 7"), skippable per chapter, resumable — total target ≤ 5 minutes, and the app is fully usable if the user skips everything (they get the template library and a "Tell Valebound your goals" prompt in Settings forever until done). Never a wall of form fields. Each chapter ends with a one-screen *mirror*: "Here's what I heard" — the user edits before it becomes data.

**Chapter 1 — Your Story.** Pick up to 3 life domains to focus on (Body & Health / Making & Craft / Mind & Learning / Home & Family / Adventure & Outdoors / Work & Order / Friendship & Community). One free-text or dictated line per domain: "What would better look like?" → becomes the Goal's why-line, verbatim.

**Chapter 2 — Goals.** For each domain: one goal (template sentence starters offered, free text always available), horizon picker, and "how will you know it's working?" (a simple self-check phrase, not a metric interrogation). Cap: **3 active goals at launch** — the questionnaire actively steers against a 12-goal board. More can be added later, one at a time (§7).

**Chapter 3 — Habit Design (per goal, the heart of it).** For each goal, design 1–2 habit plans:
- "What's a small, repeatable thing that moves this?" (suggestion chips drawn from the domain + free text)
- **Anchor:** "When in your day does it attach?" — chips of common anchors (wake up, after coffee/breakfast, lunch, after work, after dinner, before bed) + custom + the user's real recurring calendar anchors (Ch. 6 data, if granted)
- **Frequency:** daily / weekdays / chosen days / weekly — with an honesty nudge built in: "Most people who pick daily for everything keep about half. Fewer, kept, beats many, dropped." (Copy is informational, never shaming.)
- **Size it** (§4): the app proposes Tiny and Stretch versions of the stated habit; user edits.
- **Track suggestion:** small/care/companion-flavoured habits are offered the Companion track with the §7A.2 one-liner; user confirms or moves.
- **Dread check:** one tap — "How does this one feel? Easy / Fine / Heavy." Heavy habits get Heroic weighting and are never scheduled back-to-back.

**Chapter 4 — Your Rhythm.** Wake/sleep rough windows, work pattern (weekdays / shifts / irregular / none), energy peak (morning/afternoon/evening — used only for quest *ordering* hints), rest days (days the board intentionally runs light — user picks, default none), and the **burstiness question**, asked plainly: "Do you work in sprints and quiet stretches, or steady daily?" Sprint-style answers weight the system toward scaled quests (§4) and weekly totals over daily perfection.

**Chapter 5 — Class & Companion.** A 6-question taste quiz (preferred way to solve a problem, favourite fantasy moment, how you'd help a friend, etc.) plus the Chapter 1–2 data (dominant attributes) produce **class scores**: the app presents its **recommended class with the reasoning shown** ("Your goals lean Vitality + Adventure — Warden fits, Ranger is close") and the player freely chooses any class (Amendment v0.3 §2). Companion choice (§7A.1) happens here too, informed by one question — "Is your companion based on a real animal in your life?" → if yes, kind/name pre-filled for confirmation (Adam: Hound, Babs).

**Chapter 6 — Calendar.** Optional, asked *after* trust is built, with the plain-English promise first: "Valebound reads today's events on this phone only. Nothing leaves the device. Event titles are never written to logs; you choose what becomes a quest." If granted: pick which calendars count, then a one-time **mapping pass** — the app groups recurring events and proposes a type for each (Commitment / Health / Craft block / Social / Travel / Ignore), user confirms in bulk. Mappings remembered per calendar + per recurring series. If declined: the chapter ends, calendar quests simply never appear, no re-asking more than once per season.

**Chapter 7 — Your First Week (review & calibrate).** The generated Week 1 board, day by day, in plain list form: every quest with its For-line. User can per-quest: keep / make it Tiny-only for week 1 / move day / drop. Then one calibration question — "Does this week look: too light / about right / too much?" — which scales Week 1 volumes (0.75× / 1× / 1.25× targets) rather than lecturing. End screen: hero + companion at the first camp, goals pinned as banners. Onboarding ends by *playing*, not by a settings tour.

**Existing-user migration (Adam's case):** on v0.8 first launch, offer First Dawn as "Tell Valebound your goals" — pre-load current quests into Chapter 7's review as *unlinked* quests; for each, the user links it to a (new) goal, keeps it unlinked, or archives it. Nothing is deleted, nothing is auto-archived.

## 4. Scaled quests — Tiny / Target / Stretch (new quest mechanic)

Every habit-plan quest generates in **three sizes**, chosen at completion time (the board shows Target by default, one tap cycles size):

- **Tiny** — the minimum viable version (~2 min: "walk to the corner", "prime one model", "read one page"). Awards Minor XP + full completion credit. Tiny exists so a brutal day still keeps the thread — it is a *designed* size, not a failed Target.
- **Target** — the stated habit as designed. Standard XP per §5.4.
- **Stretch** — the sprint version. Heroic XP.

History tracks sizes honestly (a week of Tinies is data for §6, not a verdict), and the encounter resource link (v0.3 §3) scales with size completed.

## 5. Class-aware fashioning (daily board rules)

At Dawn, after goals + calendar generate the board, a **class pass** adjusts presentation (never invents obligations):

1. **Resource coverage:** if no quest today feeds the hero's class resource and the encounter is up, *one* existing quest that can feed it is highlighted ("Feeds Guard") — highlight, not addition. If truly none exists, the encounter scout report says so and prices base-resource play fairly (v0.3 §3 already allows it).
2. **Encounter synergy hint:** the scout report cross-references the board: "Today's enemy is Armoured. Your Craft block (2:00) stocks a Trap — handy tonight." No new quests are created for synergy; existing life is *pointed at* the game.
3. **Prep & follow-through quests (calendar-linked, optional per mapping):** for Heavy calendar events, Dawn may offer a Minor **Prep** quest ("Lay out kit for [event]", anchored 30–60 min before) and Campfire may offer a Minor **Follow-through** ("Note one thing from [event]"). Both are offers, dismissible forever per series.
4. **Companion balance:** if the board has zero companion-track quests, and a companion-track habit plan exists but isn't due, nothing is added — instead Campfire notes the companion "rested today" as a neutral flavour line. Companion quests come from plans, not from quota guilt.

## 6. Adaptive tuning — the Sunday Check-In

Adaptation happens **with** the user, weekly, in the open — never by silent algorithmic judgement:

- At Sunday Campfire, a **2-question check-in** (≤ 20 seconds): "This week's quests felt: too light / right / too heavy" and a per-goal glance (quests completed by size: Tiny/Target/Stretch counts, shown as information).
- The app may *propose* one change at a time ("Painting block: 3 Tinies, 0 Targets in 2 weeks — shrink the Target to 20 minutes?"), accepted/declined in one tap. Declining is final for that suggestion.
- **Never** auto-drop, auto-shrink, or auto-escalate a habit. Never present completion percentages as grades. The data informs; the user decides; the app remembers.

## 7. Adding a goal later — "New Banner" flow

Settings / Quest Log → **New Goal** runs a 3-screen mini-questionnaire (goal line + why; one habit plan via Ch. 3's flow; first-week review of just that plan). Same chain (§2), same For-lines, available any time — onboarding is a flow, not a one-time gate.

## 8. Data & export deltas

- New entities: `Goal` (domain, text, whyLine, horizon, active), `HabitPlan` (goalId, anchor, frequency, window, attribute, track, dread, tiny/target/stretch definitions), `Profile` (rhythm answers, burstStyle, restDays, calibration), `CalendarMapping` (calendarId/seriesId → type, prep/followThrough flags), `ClassScore` snapshot from Ch. 5 with the recommendation shown.
- `Daily Quest` instances gain: `goalId` (nullable), `sourceKind` (habit / calendar / prep / follow-through / encounter / system), `size` completed, `forLine` rendered from source.
- **Obsidian export (§11) gains `Goals & Habits.md`** — overwritten per export: active goals with why-lines, their habit plans (anchor, frequency, sizes), and the current class + companion. Calendar *titles* appear only if the user enabled "include event names in export" (default **off** — generic "Calendar commitment" otherwise). Daily files gain the For-line per quest in the existing table (add a `For` column).
- Privacy (re-state, locked): questionnaire answers, goals, and calendar data are on-device + the user's own vault export only. No network (§9.2 stands). Bug-reporter banned-fields list (BUG_TESTING.md) extends to calendar titles and why-lines.

## 9. Scope fence (v0.8)

**In:** First Dawn Ch. 1–7, goal→habit→quest chain, scaled quests, calendar mapping pass + prep/follow-through offers, class recommendation + class-aware board pass, Sunday Check-In + one-change proposals, New Banner flow, existing-user migration, export deltas.
**Out:** AI/free-text quest *invention* (the app composes from user-stated plans and mappings — it does not hallucinate new obligations), health advice or goal suggestions in medical domains beyond user-stated targets, shared/family questionnaires, syncing questionnaire data anywhere, re-onboarding nagging beyond the single Settings prompt for skippers.

---

## Paste-in for Claude (send with this file, after v0.7 lands)

```
Design amendment — read AMENDMENT_v0.4_ONBOARDING_AND_QUEST_GENERATION.md in full. It supersedes DESIGN.md §12 as the new-user default (§12 becomes the template library) and extends the Dawn generation rules. Amendment v0.3 (classes/combat) stands as built.

Adam's verdict on v0.6: the board is a set list of tasks, and it should instead be fashioned per-user. Build v0.8:

1. First Dawn onboarding per §3: seven short chapters, one question per screen, skippable and resumable, each chapter ending in a "here's what I heard" mirror. Goals capped at 3 for launch; habit design captures anchor, frequency, dread, track, and Tiny/Target/Stretch sizes per §4.
2. The generation chain per §§2/5: Dawn composes the board from habit plans due + today's mapped calendar + class/encounter context, de-duplicated, every quest carrying a "For:" line naming its goal/calendar/encounter source. Class pass highlights resource coverage and encounter synergy — it never invents new obligations.
3. Calendar per Ch. 6 + §5.3: permission asked late with the plain-English promise, per-calendar opt-in, one-time recurring-series mapping pass, optional Prep and Follow-through offers. Event titles never enter logs or exports unless the user turns on the export toggle (default off).
4. Sunday Check-In per §6: two questions, at most one proposed change, user accepts or declines — no silent adaptation, no grades.
5. Migration for existing users per §3: my current quests arrive in the Chapter 7 review as unlinked; I link, keep, or archive each. Nothing deleted.
6. Export: add Goals & Habits.md and the For column per §8.

Tests: a scripted questionnaire run produces a Week 1 board where every quest has a valid source + For-line; a calendar event that matches a habit plan generates exactly one quest; Tiny completion awards Minor XP and full credit; declining a Sunday proposal never re-proposes it; skipping all chapters still yields a working template board. Report back with screenshots of each chapter on the cover screen — onboarding is where this app will live or die.
```


---

## COMBINED paste-in for Claude (use this instead of the individual paste-ins)

```
Two design amendments are in this one file, and they are sequential, not alternatives. PART A is Amendment v0.3 (classes, daily combat encounter, revised win/lose rules) — build it first as v0.7, run its tests, and report back with the balance numbers it asks for. PART B is Amendment v0.4 (First Dawn questionnaire, goal-to-habit-to-quest generation, calendar mapping, class-aware board) — build it second as v0.8, on top of v0.7, including its migration path for my existing quests. Where Part B references classes, resources, or the encounter, Part A is the definition — do not re-invent them. Where either part conflicts with DESIGN.md, the amendment wins; everything else in DESIGN.md stands. Start Part A now.
```
