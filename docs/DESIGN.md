# Valebound — Habit Adventure
## Design Document for Build (v0.2, 13 Nov 2026 — companion system upgraded to a core pillar, per Adam)

**Working title:** Valebound *(placeholder — rename before release, do not hard-code the name in data models)*
**Owner:** Adam Stephens — solo user for v1
**Builder:** Claude (from this document + the companion prompt)
**Status:** Ready to build MVP. Decisions marked LOCKED are not to be re-invented. Items marked OPEN are listed in §14 — use the stated default and continue.

---

## 1. One-sentence pitch

A premium, painterly fantasy adventure for Android where your real day is the game: your habits, health targets, and calendar commitments become quests, completing them earns D&D-style XP, levels your character — and your companion, a Hunter-and-pet style partner who carries your smaller, secondary goals — and together you journey through and visibly restore a sleeping valley, village by village, building by building.

It is *inspired by* the era and feel of classic action-adventure games. It is **not** Zelda. See §13 (IP guardrails).

## 2. Who it is for

- **v1 (LOCKED):** One player — Adam — on his Samsung Galaxy Fold 8.
- **Later (design for it, do not build it):** Party / co-op. Friends join the *same persistent world*, pursue their own goals, and contribute to shared world progress. The data model must not block this (§10), but there are no accounts, servers, or multiplayer in v1.

## 3. The hook — how habits become a game worth opening

Three hooks were considered:

**A. World Restoration (RECOMMENDED, LOCKED for v1)**
The Vale is asleep under a grey stillness. Every completed quest restores something *visible and permanent*: fog lifts from a map region, a building is rebuilt, a lantern is lit, a villager returns. Progress is a place you can look at, not just a number. Nothing ever un-restores — a bad week pauses the restoration, it never reverses it.

**B. Weekly Dungeon**
Daily quests earn supplies (keys, potions, provisions). On Sunday a dungeon / boss encounter is resolved using the week's supplies and XP. A strong week = a clean clear; a quiet week = you scout and retreat, no punishment.

**C. Companion Journey (UPGRADED — core pillar, LOCKED, see §7A)**
Your character and companion travel a road across the Vale together — the Hunter-and-pet structure from games like World of Warcraft. The hero carries the primary goals; **the companion is a full second character with their own sheet, XP, and levels, and they carry the secondary / lesser goals** (§7A). Each companion quest = paces along the road, discoveries sniffed out, camps made. For Adam, the first companion will be modelled on his beagle Babs — but a companion is **not** required to be a dog: the player chooses their companion's kind at onboarding (§7A.1).

**Decision:** Build **A + C together as the core hook, with B as the weekly capstone.** The journey *is* how you restore the Vale: you and your companion travel its road, and the places you reach are the places that wake up. If you can only *see* two progression systems in v1, they are the map changing and the companion growing beside you.

Why this works for this user: work and life are bursty — intense sprints, then quiet stretches. A restoration world rewards a sprint (a whole district can come back in a weekend) and forgives a quiet week (the Vale simply waits). A streak counter does the opposite, and is banned (§6.4).

## 4. The core loop

### 4.1 Daily loop — "Dawn to Campfire"

1. **Dawn (morning):** App generates today's quest board from three sources:
   - **Recurring habits** due today (daily / weekday / custom schedule)
   - **Calendar commitments** for today — presented as *suggested* quests the user accepts or dismisses with one tap (never auto-accepted)
   - **Health targets** for today (e.g. 7,000 steps — progress fills automatically where permission is granted, manual fallback otherwise)
2. **Daytime:** User completes quests in whatever order real life allows, using the completion type that fits that quest (§6.2). Each completion gives immediate feedback: XP animation, loot/materials, and — when a restoration threshold is crossed — a map moment.
3. **Any time:** User can add an ad-hoc quest ("I just did a thing") and complete it retroactively for the day. Real life first, logging second.
4. **Campfire (evening, user-triggered, not timed):** A 30-second review screen: what was completed, XP gained, level progress, world change, one optional free-text note for the day. **Campfire triggers the Markdown export (§11).**
5. **Day closes** at Campfire, or automatically at next Dawn.

### 4.2 Weekly loop

- Sunday (or the user's chosen day) Campfire adds the **Dungeon (§3B)**: a simple, satisfying resolution screen based on the week's totals. Outcome tiers: Cleared / Scouted / Rested — all framed positively, rewards scale with participation.
- A **weekly recurring quest** can live here too (e.g. a Saturday weekly health quest, §12).

### 4.3 Comeback loop (LOCKED)

- If the app is not opened for 2+ days, the next Dawn shows a single **"Return to the Vale"** quest (Minor difficulty, bonus XP) instead of a backlog. Missed quests are gone — expired neutrally, never listed as failures.
- No catch-up dump. No red counters. No "you broke your streak" copy anywhere in the app.

## 5. Progression — D&D-flavoured XP and levels

### 5.1 Character XP and levels (LOCKED)

- One hero character, one overall level, plus per-attribute levels (§5.2). The companion has their own parallel XP/level track — see §7A.3.
- XP curve gets progressively steeper, in the spirit of D&D:
  `XP to go from level L to L+1 = round(100 × L^1.5 / 10) × 10`
  (L1→2: 100, L2→3: 280, L3→4: 520, L4→5: 800, L9→10: 2,700.) Store cumulative thresholds in a table; do not compute floating point in UI.
- Level-up is a moment: full-screen fanfare, a title or cosmetic unlock (§5.3), and a world restoration beat if available.

### 5.2 Attributes (LOCKED set, rename-safe)

Every quest belongs to exactly one attribute. Attribute XP is earned alongside character XP.

| Attribute | Covers |
|---|---|
| Vitality | Steps, exercise, health check-ins, weekly health quests |
| Care | Dog walks, home and family commitments |
| Craft | Painting, making, printing, hobby blocks |
| Mind | Reading, learning, reflection, therapy-day admin |
| Adventure | Outings, walks in new places, social plans |
| Order | Appointments, admin, job-search tasks, errands |

### 5.3 Unlocks and loot

- **Gold + materials** (Timber, Stone, Star Shards) drop from quests. In v1 they are *counters that feed World Restoration* — rebuilding a building costs materials earned from any quests. No shop, no prices, no economy balancing in v1.
- **Cosmetic unlocks** at levels / milestones: character portrait frames, banner colours, village decorations, companion gear. Cosmetics only — never gate a function behind a level.
- **Titles** at level milestones, shown on the Character Sheet (e.g. L5 "Vale Walker"). Builder may draft the title list; keep tone warm, never mocking.

### 5.4 Difficulties (LOCKED)

| Difficulty | Means | XP | Typical example |
|---|---|---|---|
| Minor | ~2 minutes, low dread | 10 | Log a stat, take a daily item, confirm a plan |
| Standard | 15–30 min, or a normal daily act | 25 | Dog walk, a calendar commitment |
| Heroic | 60+ min, or high dread/effort regardless of time | 60 | A painting block, a difficult appointment |
| Boss | Weekly-scale effort | 150 | The weekly capstone commitment |

User can override difficulty per quest. Default by completion type is in §6.

## 6. The habit / quest system

### 6.1 Quest definition (fields)

Name, icon (from in-app icon set), attribute, difficulty, **track (Hero / Companion / Shared, §7A.2 — required field, one tap in the creator, default Hero; default Shared for pet-care templates)**, schedule (daily / selected weekdays / weekly on a day / custom interval / one-off with a date), completion type (§6.2), target (for count/timer quests), reminder (optional, local notification, off by default), notes, active/archived, source (manual / recurring / calendar-suggested / health / system).

### 6.2 Completion types (LOCKED — type depends on the quest)

- **Tap:** one tap = done. Default for most quests.
- **Count:** +/- stepper to a target (e.g. glasses of water, pages). Partial progress persists through the day.
- **Timer:** start/stop, or manual minutes entry. Completes at target duration; early stop saves partial progress and offers "count it anyway" — the user is the referee.
- **Auto (health):** progress fills from Health Connect (§9.3); completes itself at target, with a manual-complete fallback.
- **Confirm (calendar):** for calendar-suggested quests — "I did this" tap after the event.

### 6.3 Creating quests must be fast

New quest in ≤15 seconds: name, tap attribute, tap difficulty, tap schedule preset, save. Everything else is optional detail behind an expander. Voice-dictation-friendly (large fields, no fussy pickers for the name).

### 6.4 Failure rules (LOCKED — no exceptions)

- XP is never removed. Levels never drop. The world never decays.
- A missed quest expires silently at day close. It is not shown in a failure list, ever.
- No streak counters in v1. (A gentle "days visited the Vale" history may appear in Stats as information, never as a score to protect.)
- Copy audit: no guilt, shame, or loss language anywhere. Search the final build for: streak broken, failed, missed out, lost, behind, penalty — none may appear in user-facing strings.

## 7. World, NPCs, and enemies

- **The Map** is the home of Hook A: a rich, illustrated valley with distinct regions (village, hills, river, peaks, ruins — original names, builder to draft). Regions start muted/fogged and gain colour, light, buildings, and inhabitants as Restoration points accumulate.
- **NPCs** are villagers who return as buildings are restored. In v1 they are flavour and quest-givers in presentation only: an NPC portrait + one line of warm dialogue on the Dawn board and in Campfire. No dialogue trees, no NPC simulation.
- **Obstacles ("the Still"):** Heroic and Boss quests may be presented with a Still-creature on the map/board — a grey, sleepy obstacle, not a horror monster. Completing the quest clears it in a short animation. Tone: clearing fog, waking things up — not killing.
- **Amendment, 14 Nov 2026 (Adam): the day's Still creature.** Besides the creatures on Heroic and Boss quests, one Still creature appears each Dawn as a small daily challenge. Every quest finished that day stirs it; the third wakes it and it leaves a small gift. If it sleeps on, it is simply elsewhere tomorrow: nothing is lost and nothing is recorded, so §6.4 holds. Numbers and details are in `DECISIONS.md` D-70.
- **Amendment, 14 Nov 2026 (Adam): a narrator.** An unnamed storyteller speaks to the player in the second person and the present tense, calm and a little lyrical, and says where they are and what is happening: a short **prologue** on the first run, a line over the Dawn board that follows the time of day, a line at the Campfire, a **chapter** page as each region's last place wakes and the next region's work begins, and a **Chronicle** where the story so far can be read back. The villagers keep their own one-line voices; this is narration, not a dialogue tree (§12). Every line is worked out from what has already happened; nothing is scored and §6.4 holds. See `DECISIONS.md` D-76.
- **Companion:** a full second character, not a decoration — see §7A in full. The companion appears with the hero on the Party Sheet, Map, Journey road, and Campfire, and has their own XP, levels, gear, and quest track.

## 7A. The Companion System — Hunter & Pet (LOCKED, core pillar)

Modelled on the WoW Hunter structure Adam loves: a hero and a loyal partner who levels beside them — **not** in combat terms, but in goals terms. The hero's track is the day's primary work. The companion's track is where the *smaller, secondary, easy-to-forget* goals live, so they still matter, still progress something you care about, and never compete with the big quests for attention.

### 7A.1 Choosing a companion (onboarding)

- The player **chooses a kind** — a companion is *not* assumed to be a dog. v1 roster (original, illustrated in the game's painterly style; no photos, no copied designs): **Hound, Cat, Fox, Owl, Hare, and Clockwork Sprite.**
- Kind is identity and flavour, not power: each kind gets a one-line temperament (e.g. Hound — loyal, nose for discoveries; Owl — quiet, night-wise) and a **flavour affinity** to one attribute, shown as a star on that attribute in the UI. No kind may be mechanically better — never punish the choice the player loves.
- The player **names** their companion freely. Adam's default journey: a Hound named **Babs**, in honour of his real beagle Barbie — the onboarding for his build should offer that as a one-tap preset ("A hound named Babs") without forcing it on any other future player.
- Kind and name can be changed later in Settings (with a gentle "new chapter" flavour line) — the companion's XP, level, and history carry over. Changing companions must never lose progress.

### 7A.2 Two quest tracks (the heart of the system)

- Every quest has a **track** field: **Hero**, **Companion**, or **Shared** (§6.1).
  - **Hero quests** award hero XP/attribute XP as in §5.
  - **Companion quests** award **Companion XP and Bond** (see §7A.3), and advance the Journey (§7A.4). They use the *same* difficulty table (§5.4) and XP values — a lesser goal is not a worthless goal.
  - **Shared quests** (default for real-world acts done *with* a real pet, e.g. Walk Babs) award Companion XP in full **and** hero XP at half value (rounded up) to the quest's attribute — walking the dog is both her adventure and your Care.
- **What belongs on the companion track** — the quest creator and onboarding must explain this in one sentence: *"Small, kind, easy-to-drop goals live with your companion."* Examples: care rituals for a real pet (walks, play/training, fresh water, grooming), a 5-minute tidy/reset, a stretch, watering a plant, a tiny social check-in, prepping tomorrow's small thing. The user can move *any* quest between tracks at any time — the classification is theirs, never enforced.
- On the Dawn board, companion quests form their own warm section — **"With [Companion Name]"** — with the companion's portrait, visually distinct (smaller cards, paw/leaf marker, companion colour accent) but never visually *lesser*. Completing one must feel like the companion did something: a happy animation, a discovery, paces on the road.

### 7A.3 Companion progression

- **Companion XP and levels** use the same curve as the hero (§5.1), tracked separately. Companion level-up is its own moment (smaller fanfare, new trick/gear).
- **Bond** is a simple level-of-friendship meter that only ever rises: +1 per companion/shared quest completed, +3 on companion level-up days where at least one companion quest was done. Bond milestones unlock companion cosmetics and **Companion Gifts** (below). Bond never decays — a busy month away from small goals costs nothing.
- **Tricks / abilities** (unlock at companion levels 2, 4, 6, 8, 10 — cosmetic-mechanic flavour, deterministic, never random punishment or random withholding):
  - **Sniff Out** (L2): on days a companion quest is completed, the companion "finds" +1 bonus material (rotating type).
  - **Fetch** (L4): the first companion quest each day also advances the current Restoration target by +1 material-equivalent.
  - **Scout** (L6): the Journey road shows the *next* discovery scene as a silhouette — a thing to look forward to.
  - **Comfort** (L8): the Comeback quest (§4.3) is presented *by* the companion ("[Name] kept the camp warm") and awards bonus Bond.
  - **Old Friend** (L10): a portrait scene of hero + companion unlocks for the Party Sheet and Campfire.
- **Companion gear** is a cosmetic track (collar/cloak/bell/blanket per kind, illustrated variants), unlocked by Bond milestones and companion levels. Gear has no stats.

### 7A.4 The Journey

- A **road** runs through the World Map, region to region. Hero quest completions earn Restoration materials as before; **companion/shared quest completions earn Paces** (1 Pace per quest, 2 for Heroic/Boss companion quests).
- Every 10 Paces = a **Discovery**: a small illustrated roadside scene (a standing stone, a hot spring, a travelling merchant's abandoned cart — builder to draft ~12, original) shown in a card, logged in the Journey section of the Party Sheet, and marked on the map with a small lantern. Discoveries are pure delight — no stats, no fail state, nothing missable (they queue in order).
- Campfire shows hero + companion at that night's camp on the road, positioned by total Paces — the visual summary of the whole system: *the big goals restore the world; the small goals move you through it, together.*

## 8. Screens

1. **Dawn / Quest Board (home):** Today's quests grouped by Now / Later / Done, plus the **"With [Companion Name]"** companion section (§7A.2); calendar suggestions with Accept/Dismiss; a slim world-progress + journey strip; hero and companion level + XP bars. One-thumb use on the cover screen.
2. **World Map:** The Vale, restoration state, regions, the Journey road with camp position and Discovery lanterns (§7A.4), next restoration target and its material cost.
3. **Party Sheet (was Character Sheet):** Hero and companion as a pair. Compact: tabs or stacked cards. **Opened Fold: hero on one pane, companion on the other — this screen is the showcase for two-pane layout.** Hero: portrait, level, title, attribute levels, totals, titles/cosmetics. Companion: portrait by kind, name, level, Companion XP, Bond meter, tricks unlocked, gear, Journey discoveries log.
4. **Inventory:** Gold, materials, cosmetic unlocks, companion gear and tricks.
5. **Quest Log:** All recurring quests (create/edit/archive), one-off quests, history of completed days.
6. **Campfire / Day Review:** §4.1 step 4. Includes the day's free-text note field and Export status.
7. **Health Log (quick entry):** The user-chosen stat fields (§9.3) in one fast form.
8. **Settings:** Vault folder picker + export controls, calendar source toggle, Health Connect permission, notifications, data import/export (JSON), about/IP note.

**Amendment, 14 Nov 2026 (Adam): a tour.** The first run shows a short tour of the board in bubbles, one on each part, and each other screen explains itself once the first time it is opened. The tour can be left at any point and shown again from Settings. See `DECISIONS.md` D-72.

## 9. Platform, tech, and integrations

### 9.1 Android APK on a foldable (LOCKED)

- **Deliverable is a sideloadable Android APK** (debug APK is acceptable for v1; document the exact build command and output path). No Play Store, no account, no server.
- **Stack: Flutter (stable) + Dart.** Rationale: one codebase produces the APK, first-class adaptive layout, rich custom illustration/animation without a game engine, mature Health Connect and calendar plugins. Do not use a game engine (Unity/Godot) — this is an app with game *systems*, not a game client. Do not build a PWA — the user explicitly requires an APK.
- **Foldable design (LOCKED — design for both postures from day one):**
  - **Cover screen (compact, <600dp wide):** single column. Quest Board is the hero. Bottom navigation: Board, Map, Character, Log.
  - **Opened (expanded, 600dp+):** two-pane. Board + Map side-by-side on Home; Character + Inventory side-by-side; Quest Log as list + detail. Use window size classes, not device model checks.
  - **Hinge:** never place a primary action, XP bar, or dialog button on the display crease; respect `displayFeatures` and add safe padding. Tabletop posture is a stretch goal — do not block MVP on it.
  - Test matrix must include: a compact phone emulator, a foldable emulator closed, and a foldable emulator open. Screenshots of Board in both postures are a Phase-1 deliverable.

### 9.2 Local storage (LOCKED)

- On-device only. SQLite (Drift) for quests, completion log, character, world state. SharedPreferences only for simple settings.
- Data survives restart and app update. JSON export/import of *everything* from Settings (this is also the backup story).
- **No network calls in v1.** No analytics, no ads, no crash reporting. State this in Settings > About.

### 9.3 Calendar and health (permissions optional, graceful without them)

- **Calendar:** `READ_CALENDAR` (runtime permission, requested in context from the Dawn board, not at first launch). Read *today's* device-calendar events; present each as a suggested Confirm quest with the event's title and time. Never modify calendar events. Never auto-complete. User can exclude specific calendars in Settings.
- **Health / steps:** Health Connect API. Daily step total drives Auto quests (seeded target: 7,000). If Health Connect is unavailable or denied, Auto quests fall back to manual tap — the quest must still work.
- **Amendment, 14 Nov 2026 (Adam): glucose may be read from Health Connect.** If the user turns it on, the app reads the day's blood glucose readings that another app has put in Health Connect and shows their **average** as a number in the Health Log and the day note. Read only, on the device, no targets, no advice, no judgement copy; everything else in the next bullet stands. See `DECISIONS.md` D-71.
- **Medical stats are manual and user-defined:** Settings lets the user choose which quick-entry fields appear (examples the builder may offer as presets: glucose reading, Libre time-in-range %, weight, a weekly injection checkbox with dose note). The app stores exactly what the user types, shows no medical advice, no targets, no judgement copy, and includes those fields in the Markdown export *only* (§11). Never transmit them anywhere — there is no network anyway.

## 10. Data model (minimum)

- `Quest` — §6.1 fields; `source` and a nullable `externalId` (calendar event id) included now so co-op/calendar growth is not blocked later.
- `Completion` — questId, date, completedAt, xpAwarded, difficultySnapshot, progress (for count/timer), note.
- `Character` — name, portraitId, level, totalXp, attributeXp (map), gold, materials, unlockedCosmetics, titles.
- `Companion` — name, kind (Hound/Cat/Fox/Owl/Hare/Clockwork Sprite), level, totalXp, bond, tricksUnlocked, gearUnlocked, portraitId. One active companion in v1; the entity is separate from `Character` so a future stable/party is not blocked.
- `Completion` also records `trackSnapshot` and `companionXpAwarded` / `pacesAwarded` so Shared-quest splits (§7A.2) are auditable.
- `WorldState` — restorationPoints, per-region state, per-building state, npcReturned flags, journeyPaces (total), discoveriesUnlocked (ordered list), campPosition (derived from paces).
- `DayLog` — date, dawnGeneratedAt, campfireAt (nullable), dayNote, exportedAt (nullable).
- `HealthEntry` — date, fieldKey, value, unit. (Free-form fieldKey so user-defined stats need no migration.)
- Every entity gets a UUID now (not an auto-increment-only id) — this is the one co-op-ready concession in v1.

## 11. Obsidian / Markdown export (LOCKED — a headline feature)

The user's knowledge lives in an Obsidian vault ("Adam-Brain", synced to his Fold, PC, and tablet). The app must write plain Markdown into a folder **the user picks once** via the Android Storage Access Framework (persist the URI permission). The intended pick is a `Quest Log/` folder inside the on-device vault, so the files sync like any other vault note and can be read later by the user, by Claude on his PC, and by his assistant.

Files (UTF-8, LF, YAML frontmatter):

1. **`Character Sheet.md`** — overwritten on every export. Frontmatter: `type: valebound-character`, `updated`, `level`, `total_xp`, `companion_name`, `companion_kind`, `companion_level`, `bond`. Body: hero attribute table, totals, current title, **a `## Companion` section (kind, name, level, Companion XP, Bond, tricks, gear, total Paces and Discoveries)**, world restoration summary.
2. **`Daily/YYYY-MM-DD.md`** — one per day; regenerated on each completion during the day, final at Campfire. Frontmatter MUST include: `type: valebound-day`, `date`, `level`, `xp_earned`, `companion_xp_earned`, `paces`, `quests_completed`, `quests_total`, `steps` (if known). Body sections, in order:
   - `## Quests Completed` — table: Time | Quest | Track | Attribute | Difficulty | XP (XP column shows hero XP and/or Companion XP as awarded per §7A.2)
   - `## Journey` — Paces earned today, any Discovery unlocked, camp position. Omit only if zero Paces and no Discovery.
   - `## Health` — only the fields the user logged / permitted that day, as a simple list. Omit the section entirely if empty.
   - `## World` — restorations that happened that day (or "The Vale rests.").
   - `## Notes` — the Campfire free-text note, verbatim. Omit if empty.
3. **`Quests.md`** — overwritten on export. The active quest definitions as a readable list (name, attribute, difficulty, schedule, type), so the vault alone explains the current system.

Rules: export is **one-way** (app → Markdown) in v1; never read, parse, or delete vault files; never write outside the picked folder; if the folder is unavailable (permission revoked, vault not yet synced to device), queue silently and show a calm "Export waiting for vault folder" line in Settings — no error dialogs during the day. Also provide **Share…** export of the same files from Settings as a fallback.

A complete sample of each file, with realistic data, is a Phase-2 deliverable — the format above is the contract, the sample proves it.

## 12. Seeded quests (v1 first run, all editable/archivable)

Seeded from the user's actual life. Times are defaults, not surveillance.

1. **Walk Babs** — Care · Standard · Daily · **Shared track** · Tap (timer optional). The flagship companion quest (§7A): full Companion XP for Babs + half hero Care XP.
1a. **Play / Train with Babs** — Care · Minor · Daily · **Companion track** · Timer (10 min target, "count it anyway" allowed). A seeded example of a lesser goal living on the companion track; editable/archivable like all seeds.
1b. **Five-Minute Reset** — Order · Minor · Daily · **Companion track** · Timer. A sample *non-pet* lesser goal (tidy/stretch/reset a space) proving the companion track is for any secondary goal, not only pet care. Seeded inactive — user activates/renames it in onboarding if it fits.
2. **7,000 Steps** — Vitality · Standard · Daily · Auto (Health Connect, manual fallback).
3. **Today's Commitment** — *system template, not a fixed quest:* each accepted calendar suggestion becomes today's commitment quest. Attribute defaults to Order; user can re-tag before completing.
4. **Painting / Craft Block** — Craft · Heroic · Timer (target = the scheduled block) · appears on days the user enables it or a craft block is on the calendar.
5. **Morning Health Check** — Vitality · Minor · Daily · Tap → opens Health Log (§8.7) with the user's chosen fields.
6. **Weekly Injection (Mounjaro)** — Vitality · Minor · Weekly, Saturday · Tap, with an optional dose note. Seeded active; user can archive it like anything else.
7. **Campfire Review** — Mind · Minor · Daily · System quest, completes when Campfire is done. This is the ritual that closes the day and triggers export.

## 13. IP guardrails (LOCKED)

- Inspired-by only. **Do not use** Nintendo property: no "Zelda", "Link", "Hyrule", Triforce, Master Sword, rupees, heart containers, or any copied art, music, sound, font, map, character, or item name. (This document's early shorthand — e.g. "rupees" — is banned in the product.)
- Use the original vocabulary in this document: quests, XP, gold, materials, Heart → **Vitality**, containers → **Milestones**, dungeon → **Delve** is acceptable as a generic word.
- All illustration is original, generated or drawn for this app, in the style of §Visual (below). No traced or "in the style of [living artist / specific game]" assets.

**Amendment, 14 Nov 2026 (Adam):** the rendering style below is changed from painterly to **cel-shaded animation** (clean ink lines, flat colour, hard-edged shading). Everything else in this paragraph stands. See `docs/STYLE.md` and `DECISIONS.md` D-48.

**Visual direction (LOCKED):** Premium modern painterly fantasy — rich, saturated colour; soft light; layered illustrated scenes. The *era feel* comes from subject matter (banners, stone, lanterns, arched doors, a hand-drawn-feeling map), rendered to today's graphical standard. **Not pixel art.** Not flat corporate vector. Not a cartoon clone of any existing game. UI: deep greens, warm gold, parchment-cream cards, dark slate text; a display serif for headings, a clean sans for body; generous spacing — it should feel expensive, not busy.

**Asset & tool pipeline (LOCKED — added v0.2, answering Adam's Blender question):**
- **This is a 2D app. Blender / 3D is NOT the default pipeline and is not required.** Do not build 3D models, 3D scenes, or a 3D map, and do not install or assume a Blender MCP. Reasons: the locked look is painterly 2D, a 3D pipeline would fight that style, bloat the APK, and slow iteration. (Adam's Blender-MCP research was for Northforge STL triage; nothing Blender is installed in his Claude setup as of this doc.)
- **Primary art:** 2D illustrated raster assets (PNG/WebP) — map and region scenes, hero/companion portraits by kind, Discovery cards, Campfire scene, building states (asleep/restored variants). Consistency comes from a **style sheet the builder must create first**: palette, line/brush treatment, lighting, and a written style prompt reused verbatim for every generated/commissioned asset, plus a reference board of the first 3 approved assets that all later assets are checked against.
- **UI & motion:** icons and UI ornaments as vector (SVG / Flutter shapes); animation in Flutter (built-in animation, CustomPaint particles) or Rive if already available — level-up, XP gain, fog clearing, companion reactions, chest/loot moments. No video assets.
- **Tool audit (mandatory, Phase 1, rule 4 of the companion prompt):** Claude must list the tools *actually available in its own environment* (image generation, MCPs, local apps) and state, per asset class, what it will generate itself, what it will draw in code/vector, and what it needs from Adam — with exact sizes/formats in an `ASSETS.md` manifest (filename, dimensions, format, style-prompt used, status: generated / coded / placeholder / needed-from-Adam). Never silently ship grey boxes, and never claim a tool was used that was not.
- **Blender exception:** only if a Blender MCP is *already connected* in that Claude environment, Claude may *propose* — in `DECISIONS.md`, before doing it — using a pre-rendered 3D element flattened to a 2D painterly asset where it genuinely beats 2D (e.g. a complex building perspective). Proposal only; the default answer without Adam's go is no, and the app must never depend on Blender at runtime.

## 14. Scope fence

**MVP includes:** §§4–12 above, in the phase order of the companion prompt.
**Explicitly NOT in v1:** accounts/login, servers, multiplayer/party, chat, a shop or priced economy, explorable character movement on the map, dialogue trees, push-notification campaigns (one optional local quest reminder only), iOS/desktop/web builds, Play Store release, any network feature, any medical advice or interpretation.

**OPEN items (use the default, keep building):**
- App name → default "Valebound" (data must not depend on it)
- Character name/portrait → default: user names the character in onboarding; 4 original portrait choices
- Companion for Adam's build → default: Hound named Babs (preset offer in onboarding, §7A.1); other players choose any kind/name. Roster in §7A.1 is locked for v1.
- Exact health fields → default: steps + the §9.3 presets, all optional
- Dungeon/Delve presentation details → default: §3B single-screen resolution

## 15. Acceptance checklist (the build is not "done" until all are true)

- [ ] `flutter build apk --debug` (or the documented release command) succeeds; APK path printed
- [ ] App installs and runs fully offline; data persists across restart
- [ ] Board is usable one-handed on compact width and uses two panes when open; nothing critical sits on the crease
- [ ] A quest of each completion type can be created and completed
- [ ] Companion onboarding offers all §7A.1 kinds + free naming (incl. the Babs preset); companion has a working Party Sheet pane, Companion XP/levels on the same curve, Bond that only rises, and tricks unlocking at L2/4/6/8/10
- [ ] Track splits are correct: Companion quests award Companion XP only; Shared quests award full Companion XP + half hero XP (rounded up); Paces accumulate and a Discovery fires every 10 Paces
- [ ] XP, level-up (incl. the L1→2 = 100 XP step), and attribute XP are correct
- [ ] Missing a day changes nothing except that day; the comeback quest appears after 2+ days away
- [ ] Calendar suggestions appear (with permission) and are ignorable; Health Connect steps fill the Auto quest, manual fallback works without permission
- [ ] Campfire produces Markdown files matching §11 exactly (sample files delivered)
- [ ] No banned IP terms or guilt-copy terms appear in user-facing strings
- [ ] Seeded quests (§12) are present and editable on first run
