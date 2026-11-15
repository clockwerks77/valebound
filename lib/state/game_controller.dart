import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../data/settings.dart';
import '../device/device_port.dart';
import '../export/export_service.dart';
import '../export/vault_port.dart';
import '../rules/checkin.dart';
import '../rules/classes.dart';
import '../rules/combat.dart';
import '../rules/companion_rules.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/encounter.dart';
import '../rules/enums.dart';
import '../rules/first_dawn.dart';
import '../rules/gear.dart';
import '../rules/generation.dart';
import '../rules/goals.dart';
import '../rules/health_fields.dart';
import '../rules/narrator.dart';
import '../rules/progression.dart';
import '../rules/reminders.dart';
import '../rules/still.dart';
import '../rules/suggestions.dart';
import '../rules/world.dart';

/// A quest tapped done a moment ago and not yet committed, so it can still
/// be undone (DECISIONS.md D-35).
class PendingCompletion {
  PendingCompletion({
    required this.entry,
    required this.at,
    this.note,
    this.progress,
    this.onCommitted,
  });

  final BoardQuest entry;

  /// When it was tapped: the time the completion is recorded at.
  final DateTime at;
  final String? note;
  final int? progress;
  final void Function(CompletionOutcome outcome)? onCommitted;
  Timer? timer;
}

/// Holds what the screens show and forwards every action to the repository.
/// No state-management package: a plain [ChangeNotifier] is enough for one
/// player on one device (DECISIONS.md D-03).
class GameController extends ChangeNotifier {
  GameController(
    this.repo, {
    VaultPort vault = const NoVault(),
    this.device = const NoDevice(),
  }) : export = ExportService(repo, vault);

  final GameRepository repo;

  /// Calendar, Health Connect and the reminder (DESIGN §9.3, §6.1). All
  /// optional; the app is whole without any of them.
  final DevicePort device;

  /// The Markdown export and its queue (DESIGN §11).
  final ExportService export;

  bool loading = true;
  bool hasProfile = false;

  CharacterRow? hero;
  CompanionRow? companion;
  WorldStateRow? world;
  DawnPlan? lastDawn;

  String day = '';
  List<BoardQuest> board = const <BoardQuest>[];
  List<QuestRow> quests = const <QuestRow>[];
  List<DaySummary> history = const <DaySummary>[];
  int completionCount = 0;

  Map<Attribute, int> attributeXp = const <Attribute, int>{};
  Map<MaterialKind, int> materials = const <MaterialKind, int>{};
  List<String> discoveries = const <String>[];
  List<String> titles = const <String>[];

  /// Today's log: the Campfire time and the day note.
  DayLogRow? today;

  /// Place key to the day it was restored.
  Map<String, String> restoredOn = const <String, String>{};
  List<String> gearUnlocked = const <String>[];
  List<String> cosmeticsUnlocked = const <String>[];
  Map<String, String> equipped = const <String, String>{};

  // ---- Real life (Phase 3) ---------------------------------------------

  GameSettings settings = const GameSettings();

  /// Today's calendar events not yet accepted or dismissed.
  List<CalendarEvent> suggestions = const <CalendarEvent>[];

  /// Today's board as Dawn composed it (Amendment v0.4 §§2, 5): the order,
  /// and for every quest what it is for.
  ComposedBoard composed =
      const ComposedBoard(order: <String>[], lines: <String, BoardLine>{});

  /// Prep and Follow-through quests that may be offered for a heavy
  /// calendar event today. Offers, never additions.
  List<CalendarOffer> offers = const <CalendarOffer>[];

  /// Today's calendar events that are a quest already on the board.
  Map<String, EventFact> _merged = const <String, EventFact>{};

  /// The size picked on a habit quest's card, until it is done.
  final Map<String, QuestSize> _sizeChoice = <String, QuestSize>{};
  String _sizeDay = '';
  List<DeviceCalendar> calendars = const <DeviceCalendar>[];
  bool calendarGranted = false;
  List<CalendarEvent> _eventsToday = const <CalendarEvent>[];

  StepsAccess stepsAccess = StepsAccess.unavailable;

  /// Glucose from Health Connect (DECISIONS D-71): whether it can be read,
  /// and today's readings so far when it is.
  StepsAccess glucoseAccess = StepsAccess.unavailable;
  GlucoseSpan? glucoseToday;

  /// Today's Health Log entries by field key.
  Map<String, HealthEntryRow> healthToday = const <String, HealthEntryRow>{};

  /// The weekly Delve, when one can be entered at the Campfire.
  DelveWaiting? delve;

  /// The day's Still creature and how far along it is (DECISIONS D-70).
  DailyStillToday? dailyStillToday;

  /// Today's finished quests as a class counts them, and how today's
  /// encounter stands (Amendment v0.3).
  List<QuestDone> questsDone = const <QuestDone>[];
  EncounterRecord? encounterToday;

  bool notificationsAllowed = false;

  /// Set when the app was opened from Health Connect's "why" link.
  String? launchReason;

  final List<AutoCompletion> _autoCompleted = <AutoCompletion>[];
  String? _reminderSignature;

  /// Quests the app completed by itself since this was last asked (steps
  /// reaching their target), so the screen can mark the moment.
  List<AutoCompletion> takeAutoCompletions() {
    final out = List<AutoCompletion>.of(_autoCompleted);
    _autoCompleted.clear();
    return out;
  }

  /// The calendar offer on the Dawn board: made once, in context.
  bool get calendarOfferDue {
    if (settings.calendarOn) return false;
    if (!settings.calendarAsked) return true;
    // "Not now" is not asked about again for a season (Amendment v0.4 §3).
    final askedOn = settings.calendarAskedOn;
    return askedOn != null && DayKey.daysBetween(askedOn, day) >= 90;
  }

  bool get stepsConnected =>
      settings.stepsOn && stepsAccess == StepsAccess.connected;

  bool get glucoseConnected =>
      settings.glucoseOn && glucoseAccess == StepsAccess.connected;

  /// Today's average glucose as kept in the Health Log, when there is one.
  HealthEntryRow? get glucoseAverageToday => healthToday[glucoseAverageFieldKey];

  /// Today's steps as recorded, from Health Connect or typed by hand.
  int? get stepsToday {
    final raw = healthToday[stepsFieldKey]?.value;
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  bool get hasReminders =>
      quests.any((q) => q.active && q.reminderTime != null);

  /// The companion presents the comeback quest once they know Comfort.
  bool get comfortKnown => (companion?.level ?? 1) >= comfortLevel;

  // ---- The world, worked out from what has been gathered ---------------

  /// Places restored so far.
  int get restored => restoredCount(materials);

  /// Materials gathered but not yet built into anything.
  Map<MaterialKind, int> get stores => inStores(materials);

  /// The place being worked toward now.
  RestorationTarget get target => targetAt(restored);

  /// The villager greeting today's board, once anyone has come home.
  VillagerLine? get dawnLine => dawnVillager(restored, day);
  VillagerLine? get campfireLine => campfireVillager(restored, day);

  bool get campfireDone => today?.campfireAt != null;
  String get dayNote => today?.dayNote ?? '';

  String get frame => equipped[CosmeticKind.frame.name] ?? defaultFrame;
  String get banner => equipped[CosmeticKind.banner.name] ?? defaultBanner;
  GearItem? get gearWorn => gearByKey(companion?.gearEquipped);

  DateTime get now => repo.clock();
  String get companionName => companion?.name ?? 'your companion';

  /// Set when the saved data could not be opened at launch.
  String? startupTrouble;

  /// [init], but a problem opening storage is shown instead of thrown.
  Future<void> start() async {
    try {
      await init();
    } catch (error) {
      startupTrouble = '$error';
      loading = false;
      notifyListeners();
    }
  }

  Future<void> init() async {
    hasProfile = await repo.hasProfile();
    launchReason = await device.takeLaunchReason();
    if (hasProfile) {
      await _reload(fromDevice: true);
      _prologueWanted = !settings.prologueSeen;
      _tourWanted = !settings.tourDone;
    }
    await export.refreshStatus();
    loading = false;
    notifyListeners();
    if (hasProfile) _exportSoon();
  }

  /// Re-reads everything. Also rolls the day over if midnight has passed.
  ///
  /// [fromDevice] also asks the device for today's steps and calendar; that
  /// happens when the app is opened or returned to, and when the day turns.
  Future<void> refresh({bool fromDevice = false}) async {
    if (!hasProfile) return;
    await _reload(fromDevice: fromDevice);
    notifyListeners();
  }

  /// Called when the app comes back to the front.
  Future<void> resumed() async {
    launchReason ??= await device.takeLaunchReason();
    await refresh(fromDevice: true);
  }

  /// How often Health Connect is read again while the app stays in front.
  static const Duration healthRefreshEvery = Duration(minutes: 3);

  bool _readingHealth = false;

  /// Reads steps and glucose again, without waiting for the app to be left
  /// and returned to. Runs every few minutes while the app is in front, and
  /// when the Health Log opens (DECISIONS D-74).
  Future<void> refreshHealth() async {
    if (!hasProfile || loading || _readingHealth) return;
    _readingHealth = true;
    try {
      if (DayKey.of(repo.clock()) != day) {
        // Midnight passed with the app open: the whole day turns over.
        await refresh(fromDevice: true);
        return;
      }
      final stepsBefore = stepsAccess;
      final glucoseBefore = glucoseAccess;
      await _readSteps();
      await _readGlucose();
      final changed =
          stepsBefore != stepsAccess || glucoseBefore != glucoseAccess;
      if (!changed && !stepsConnected && !glucoseConnected) return;
      await _reload();
      notifyListeners();
    } finally {
      _readingHealth = false;
    }
  }

  Future<void> _reload({bool fromDevice = false}) async {
    lastDawn = await repo.ensureDawn();
    final today = DayKey.of(repo.clock());
    final readDevice = fromDevice || today != day;
    day = today;
    settings = await repo.settings();
    if (_sizeDay != day) {
      _sizeChoice.clear();
      _sizeDay = day;
    }
    if (readDevice) {
      await _readSteps();
      await _readGlucose();
      await _readCalendar();
    }
    await repo.syncWorld();
    hero = await repo.hero();
    companion = await repo.companion();
    world = await repo.world();
    await _planCalendar();
    board = await repo.loadBoard(day, alsoDue: _merged.keys.toSet());
    encounterToday = decodeEncounter((await repo.dayLog(day))?.encounter);
    _compose();
    quests = await repo.allQuests();
    history = await repo.history();
    completionCount = await repo.completionCount();
    final h = hero;
    attributeXp =
        h == null ? const <Attribute, int>{} : decodeAttributeXp(h.attributeXp);
    materials =
        h == null ? const <MaterialKind, int>{} : decodeMaterials(h.materials);
    titles = h == null ? const <String>[] : decodeStringList(h.titles);
    final w = world;
    discoveries =
        w == null ? const <String>[] : decodeStringList(w.discoveriesUnlocked);
    restoredOn =
        w == null ? const <String, String>{} : decodeStringMap(w.buildingState);
    cosmeticsUnlocked =
        h == null ? const <String>[] : decodeStringList(h.unlockedCosmetics);
    equipped = h == null
        ? const <String, String>{}
        : decodeStringMap(h.equippedCosmetics);
    final c = companion;
    gearUnlocked =
        c == null ? const <String>[] : decodeStringList(c.gearUnlocked);
    await repo.recordBoardSize(day, board.length);
    this.today = await repo.dayLog(day);
    healthToday = await repo.healthEntriesByKey(day);
    dailyStillToday = await repo.dailyStillOn(day);
    questsDone = await repo.questsDoneOn(day);
    encounterToday = decodeEncounter(this.today?.encounter);
    delve = await repo.delveWaiting();
    await _syncReminders();
  }

  // ---- Device: steps, calendar, reminders ------------------------------

  /// Reads today's steps from Health Connect, when connected, and lets them
  /// fill the Auto quest. Quiet in every other case (DESIGN §9.3).
  Future<void> _readSteps() async {
    stepsAccess = await device.stepsAccess();
    if (!stepsConnected) return;
    final dawn = DayKey.parse(day);
    // Yesterday's count is only whole once the day is over.
    final yesterday = DayKey.addDays(day, -1);
    final whole = await device.stepsBetween(DayKey.parse(yesterday), dawn);
    if (whole != null) await repo.recordStepsFor(yesterday, whole);
    final steps = await device.stepsBetween(dawn, repo.clock());
    if (steps == null) return;
    _autoCompleted.addAll(await repo.recordSteps(steps));
  }

  /// Reads the day's glucose readings from Health Connect, when connected,
  /// and keeps their average in the Health Log (DECISIONS D-71). Numbers
  /// only: nothing is judged, and nothing is written back.
  Future<void> _readGlucose() async {
    glucoseAccess = await device.glucoseAccess();
    if (!glucoseConnected) {
      glucoseToday = null;
      return;
    }
    final dawn = DayKey.parse(day);
    final yesterday = DayKey.addDays(day, -1);
    final whole = await device.glucoseBetween(DayKey.parse(yesterday), dawn);
    if (whole != null) {
      await repo.recordGlucoseAverage(yesterday, whole.average);
    }
    glucoseToday = await device.glucoseBetween(dawn, repo.clock());
    final today = glucoseToday;
    if (today != null) await repo.recordGlucoseAverage(day, today.average);
  }

  Future<void> _readCalendar() async {
    calendarGranted = await device.calendarGranted();
    if (!settings.calendarOn || !calendarGranted) {
      _eventsToday = const <CalendarEvent>[];
      calendars = const <DeviceCalendar>[];
      return;
    }
    final start = DayKey.parse(day);
    final end = DayKey.parse(DayKey.addDays(day, 1));
    calendars = await device.calendars();
    _eventsToday = await device.eventsBetween(start, end);
  }

  /// Works out what today's calendar becomes (Amendment v0.4 §2): a mapped
  /// event is put on the board, one that is a habit plan (or repeats a
  /// quest already there) merges into it, and an unmapped one is only ever
  /// offered. Also finds the Prep and Follow-through offers.
  Future<void> _planCalendar() async {
    _merged = const <String, EventFact>{};
    offers = const <CalendarOffer>[];
    if (!settings.calendarOn || _eventsToday.isEmpty) {
      suggestions = const <CalendarEvent>[];
      return;
    }
    final choices = await repo.calendarChoicesOn(day);
    // One event often sits in two calendars. It is one event, and a choice
    // made about one copy counts for them all.
    final byKey = <String, CalendarEvent>{};
    final facts = <EventFact>[];
    for (final e in _eventsToday) {
      if (settings.excludedCalendars.contains(e.calendarId)) continue;
      if (byKey.containsKey(e.sameAs)) continue;
      byKey[e.sameAs] = e;
      facts.add(_factOf(e));
    }
    final settled = <String>{
      for (final e in _eventsToday)
        if (choices.containsKey(e.id)) e.sameAs,
    };
    final plans = settings.activePlans;
    final planByQuest = <String, HabitPlan>{
      for (final p in plans)
        if (p.questId != null) p.questId!: p,
    };
    final names = <String, List<String>>{};
    for (final b in await repo.loadBoard(day)) {
      final q = b.quest;
      if (q.source == QuestSource.calendar ||
          q.source == QuestSource.prep ||
          q.source == QuestSource.followThrough ||
          q.systemKey == systemKeyComeback) {
        continue;
      }
      final plan = planByQuest[q.id];
      names[q.id] = plan == null
          ? <String>[q.name]
          : <String>[plan.target, plan.tiny, plan.stretch];
    }
    final today = planCalendar(
      events: facts,
      mappings: settings.mappings,
      plans: plans,
      boardNames: names,
    );
    final kindOf = <String, MappingKind>{
      for (final m in settings.mappings) m.seriesKey: m.kind,
    };
    for (final f in today.asQuests) {
      final e = byKey[f.key];
      if (e == null || settled.contains(f.key)) continue;
      await repo.acceptSuggestion(
        externalId: e.id,
        title: e.title,
        timeLabel: e.timeLabel,
        attribute: kindOf[f.seriesKey]?.attribute ?? Attribute.order,
      );
    }
    _merged = today.merged;
    suggestions = <CalendarEvent>[
      for (final f in today.suggestions)
        if (!settled.contains(f.key) && byKey[f.key] != null) byKey[f.key]!,
    ];
    offers = offersAt(
      now: repo.clock(),
      events: facts,
      mappings: settings.mappings,
      settled: choices.keys.toSet(),
    );
  }

  EventFact _factOf(CalendarEvent e) => EventFact(
        key: e.sameAs,
        calendarId: e.calendarId,
        title: e.title,
        begin: e.begin,
        end: e.end,
        allDay: e.allDay,
        timeLabel: e.timeLabel,
      );

  QuestFact _questFact(BoardQuest b) => QuestFact(
        id: b.quest.id,
        name: b.quest.name,
        source: b.quest.source,
        attribute: b.quest.attribute,
        track: b.quest.track,
        difficulty: b.quest.difficulty,
        systemKey: b.quest.systemKey,
        goalId: b.quest.goalId,
        planId: b.quest.planId,
        done: b.isDone,
      );

  /// Composes the loaded board: what each quest is for, the size it shows,
  /// the order, and the one quest that feeds the class resource.
  void _compose() {
    final status = statusOf(encounterToday);
    composed = composeBoard(
      day: day,
      quests: <QuestFact>[for (final b in board) _questFact(b)],
      goals: settings.goals,
      plans: settings.plans,
      rhythm: settings.rhythm,
      merged: _merged,
      calendarTimes: <String, String>{
        for (final b in board)
          if (b.quest.source == QuestSource.calendar && b.quest.notes.isNotEmpty)
            b.quest.id: b.quest.notes,
      },
      heroClass: HeroClass.byId(hero?.classId),
      encounterOpen:
          status == EncounterStatus.ready || status == EncounterStatus.retry,
    );
    final byId = <String, BoardQuest>{for (final b in board) b.quest.id: b};
    board = <BoardQuest>[
      for (final id in composed.order)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// The quest already on today's board that [event] looks to be about, or
  /// null. A hint for the suggestion card only: the suggestion is still
  /// offered, and the choice stays with the user.
  String? boardQuestMatching(CalendarEvent event) => questMatching(
        event.title,
        <String>[
          for (final b in board)
            if (b.quest.source != QuestSource.calendar &&
                b.quest.systemKey != systemKeyComeback)
              b.quest.name,
        ],
      );

  /// Plans the week's reminders for quests that have one. The device is only
  /// told when the plan has changed.
  Future<void> _syncReminders() async {
    final now = repo.clock();
    final requests = <ReminderRequest>[];
    for (final q in quests) {
      if (!q.active || q.reminderTime == null) continue;
      var settled = false;
      for (final b in board) {
        if (b.quest.id == q.id) settled = b.isDone || b.isSetAside;
      }
      final times = upcomingReminders(
        schedule: scheduleOf(q),
        time: q.reminderTime,
        now: now,
        settledToday: settled,
      );
      for (var i = 0; i < times.length; i++) {
        requests.add(
          ReminderRequest(
            id: reminderId(q.id, i),
            at: times[i],
            title: q.name,
            body: reminderBody,
          ),
        );
      }
    }
    final signature = <String>[
      for (final r in requests)
        '${r.id}@${r.at.millisecondsSinceEpoch}:${r.title}',
    ].join('|');
    if (signature == _reminderSignature) return;
    _reminderSignature = signature;
    await device.syncReminders(requests);
  }

  // ---- Calendar (DESIGN §9.3) ------------------------------------------

  /// Asks for the calendar, from the Dawn board or Settings. Whatever the
  /// answer, the offer on the board is not made again.
  Future<bool> connectCalendar() async {
    final granted = await device.requestCalendar();
    await repo.setSetting(SettingKey.calendarAsked, '1');
    await repo.setSetting(SettingKey.calendarAskedOn, day);
    await repo.setSetting(SettingKey.calendarOn, granted ? '1' : '0');
    await refresh(fromDevice: true);
    return granted;
  }

  /// "Not now": the board stays as it is, and Settings can turn it on later.
  Future<void> declineCalendar() async {
    await repo.setSetting(SettingKey.calendarAsked, '1');
    await repo.setSetting(SettingKey.calendarAskedOn, day);
    await repo.setSetting(SettingKey.calendarOn, '0');
    await refresh();
  }

  Future<void> turnCalendarOff() async {
    await repo.setSetting(SettingKey.calendarOn, '0');
    await refresh(fromDevice: true);
  }

  Future<void> setCalendarExcluded(String calendarId, {required bool excluded}) async {
    final ids = Set<String>.of(settings.excludedCalendars);
    if (excluded) {
      ids.add(calendarId);
    } else {
      ids.remove(calendarId);
    }
    await repo.setExcludedCalendars(ids);
    await refresh();
  }

  /// Accept: the event becomes today's commitment. Returns the quest's id.
  Future<String> acceptSuggestion(CalendarEvent event) async {
    final id = await repo.acceptSuggestion(
      externalId: event.id,
      title: event.title,
      timeLabel: event.timeLabel,
    );
    await refresh();
    _exportSoon();
    return id;
  }

  Future<void> dismissSuggestion(CalendarEvent event) async {
    await repo.dismissSuggestion(event.id);
    await refresh();
  }

  // ---- Steps and the Health Log (DESIGN §8.7, §9.3) ---------------------

  Future<StepsAccess> connectSteps() async {
    final access = await device.requestSteps();
    await repo.setSetting(
      SettingKey.stepsOn,
      access == StepsAccess.connected ? '1' : '0',
    );
    await refresh(fromDevice: true);
    _exportSoon();
    return access;
  }

  Future<void> disconnectSteps() async {
    await repo.setSetting(SettingKey.stepsOn, '0');
    await refresh(fromDevice: true);
  }

  Future<StepsAccess> connectGlucose() async {
    final access = await device.requestGlucose();
    await repo.setSetting(
      SettingKey.glucoseOn,
      access == StepsAccess.connected ? '1' : '0',
    );
    await refresh(fromDevice: true);
    _exportSoon();
    return access;
  }

  Future<void> disconnectGlucose() async {
    await repo.setSetting(SettingKey.glucoseOn, '0');
    await refresh(fromDevice: true);
  }

  /// Saves the Health Log's form: field key to exactly what was typed. An
  /// empty value clears that entry. Steps typed here fill the Auto quest
  /// just as steps from Health Connect do.
  Future<void> saveHealthLog(Map<String, String> values) async {
    for (final field in settings.healthFields) {
      final value = values[field.key];
      if (value == null) continue;
      if (field.key == stepsFieldKey) {
        final steps = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
        if (steps != null) {
          _autoCompleted.addAll(await repo.recordSteps(steps));
          continue;
        }
      }
      await repo.setHealthEntry(day, field.key, value, unit: field.unit);
    }
    await refresh();
    _exportSoon();
  }

  Future<void> setHealthFields(List<HealthField> fields) async {
    await repo.setHealthFields(fields);
    await refresh();
  }

  // ---- Classes and fights (Amendment v0.3) ------------------------------

  /// The hero's class, or null until one has been chosen.
  HeroClass? get heroClass => HeroClass.byId(hero?.classId);

  /// True for a hero with no class yet: a new one, or one from before 0.7.
  bool get needsClass => hasProfile && heroClass == null;

  /// Chooses or changes the class. XP, levels and everything gathered are
  /// untouched.
  Future<void> chooseClass(HeroClass cls) async {
    await repo.setHeroClass(cls);
    await _reload();
    notifyListeners();
    _exportSoon();
  }

  /// A change of class is free at the weekly Campfire (the Delve's day).
  bool get respecOpen =>
      day.isNotEmpty && DayKey.weekday(day) == settings.delveWeekday;

  /// The creature holding the road today.
  EnemyTemplate get enemyToday => enemyFor(day);
  EncounterStatus get encounterStatus => statusOf(encounterToday);

  /// The class resource in hand for a fight now, from today's quests.
  int get resourceNow {
    final cls = heroClass;
    return cls == null ? baseResource : resourceToday(cls, questsDone);
  }

  Map<ItemKind, int> get pouch => settings.pouch;
  BossState get bossState => settings.boss;

  /// The titles won from bosses, oldest first.
  List<String> get bossTitles => bossState.titles;

  /// Today's fight as it would start now, or null without a class.
  FightSetup? encounterSetup({required bool heroic}) {
    final cls = heroClass;
    final h = hero;
    final c = companion;
    if (cls == null || h == null || c == null) return null;
    return FightSetup(
      heroClass: cls,
      level: h.level,
      companionLevel: c.level,
      bond: c.bond,
      type: enemyToday.type,
      seed: encounterSeed(day),
      resource: resourceNow,
      heroic: heroic,
      items: pouch,
    );
  }

  /// Writes down a finished fight with today's creature.
  Future<EncounterOutcome?> finishEncounter(Fight fight) async {
    final outcome = await repo.recordEncounter(
      won: fight.outcome == FightOutcome.won,
      heroic: fight.heroic,
      turns: fight.turn,
      pouchAfter: fight.items,
    );
    await _reload();
    notifyListeners();
    _exportSoon();
    return outcome;
  }

  /// The week's boss fight as it would start now, or null when no Delve is
  /// waiting or there is no class.
  FightSetup? bossSetup({Advantage? advantage}) {
    final cls = heroClass;
    final h = hero;
    final c = companion;
    final waiting = delve;
    if (cls == null || h == null || c == null || waiting == null) return null;
    return FightSetup(
      heroClass: cls,
      level: h.level,
      companionLevel: c.level,
      bond: c.bond,
      type: bossState.boss.type,
      seed: bossSeed(waiting.delveDay),
      resource: resourceNow,
      items: pouch,
      boss: true,
      bossHp: bossState.hpLeft,
      advantage: advantage,
    );
  }

  /// Writes down the week's attempt on the boss.
  Future<BossOutcome?> finishBoss(Fight fight, {required bool spentMarks}) async {
    final pouchAfter = Map<ItemKind, int>.of(fight.items);
    final outcome = await repo.recordBossAttempt(
      left: fight.enemyHp,
      spentMarks: spentMarks,
      turns: fight.turn,
      pouchAfter: pouchAfter,
    );
    await _reload();
    notifyListeners();
    _exportSoon();
    return outcome;
  }

  // ---- The weekly Delve (DESIGN §4.2) -----------------------------------

  Future<DelveResult?> enterDelve() async {
    final result = await repo.resolveDelve();
    await refresh();
    if (result != null) _exportSoon();
    return result;
  }

  Future<void> setDelveWeekday(int weekday) async {
    await repo.setDelveWeekday(weekday);
    await refresh();
  }

  // ---- The reminder (DESIGN §6.1) ---------------------------------------

  /// Asks to show notifications; called the first time a reminder is set.
  Future<bool> enableNotifications() async {
    notificationsAllowed = await device.requestNotifications();
    notifyListeners();
    return notificationsAllowed;
  }

  Future<void> checkNotifications() async {
    notificationsAllowed = await device.notificationsAllowed();
    notifyListeners();
  }

  /// Writes the Markdown files in the background. Never throws and never
  /// shows anything: if the folder is away, the queue waits (DESIGN §11).
  void _exportSoon() {
    unawaited(
      export.exportPending().then((_) => notifyListeners()).catchError((_) {}),
    );
  }

  Future<void> createProfile({
    required String heroName,
    required String portraitId,
    required String companionName,
    required CompanionKind companionKind,
    required bool activateFiveMinuteReset,
  }) async {
    await repo.createProfile(
      heroName: heroName,
      portraitId: portraitId,
      companionName: companionName,
      companionKind: companionKind,
      activateFiveMinuteReset: activateFiveMinuteReset,
    );
    hasProfile = true;
    await _reload();
    _prologueWanted = !settings.prologueSeen;
    _tourWanted = !settings.tourDone;
    notifyListeners();
  }

  // ---- The narrator (DECISIONS D-76) ------------------------------------

  bool _prologueWanted = false;

  /// True once, when the prologue should be told: on the first run, and on
  /// the first launch of a build that has one.
  bool takePrologueRequest() {
    final wanted = _prologueWanted;
    _prologueWanted = false;
    return wanted;
  }

  /// The prologue has been read to the end, or skipped.
  Future<void> finishPrologue() async {
    await repo.setSetting(SettingKey.prologueSeen, '1');
    await refresh();
  }

  /// The chapter being told now.
  Chapter get chapter => chapterAt(restored);

  /// "Chapter Two · Larkdown", or the afterword's heading.
  String get storyTitle => storyHeading(restored);

  /// What the narrator says over today's board.
  Narration get narration => dawnNarration(
        now: repo.clock(),
        day: day,
        restored: restored,
        paces: world?.journeyPaces ?? 0,
        companionName: companionName,
        returning: comebackQuest != null,
      );

  /// Places that woke today, in the order they woke.
  List<RestorationTarget> get wokeToday {
    final indexes = <int>[
      for (final e in restoredOn.entries)
        if (e.value == day) targetIndexByKey(e.key),
    ]..sort();
    return <RestorationTarget>[
      for (final i in indexes)
        if (i >= 0) targetAt(i),
    ];
  }

  /// What the narrator says at tonight's Campfire.
  String get campfireStory {
    return campfireNarration(
      day: day,
      questsDone: board.where((b) => b.isDone && !_isCampfire(b)).length,
      wokeToday: wokeToday,
      // The day's creature, once it has been met and woken in the fight.
      creatureWoke:
          (encounterToday?.won ?? false) ? enemyToday.name : null,
      companionName: companionName,
      next: target,
    );
  }

  /// The story so far, oldest first.
  List<ChronicleEntry> get story => chronicle(
        arrivedOn: hero == null ? day : DayKey.of(hero!.createdAt),
        companionName: companionName,
        restored: restored,
        restoredOn: restoredOn,
      );

  // ---- The tour and the screen hints (DECISIONS D-72) -------------------

  bool _tourWanted = false;

  /// True once, when the tour of the board should be shown: on the first
  /// run, and whenever it is asked for again in Settings.
  bool takeTourRequest() {
    final wanted = _tourWanted;
    _tourWanted = false;
    return wanted;
  }

  /// The tour has been seen, or left early. Either way it is not shown
  /// again unless asked for.
  Future<void> finishTour() async {
    await repo.setSetting(SettingKey.tourDone, '1');
    await refresh();
  }

  /// "Show the tour again": the board's tour, and each screen's hint.
  Future<void> requestTour() async {
    await repo.setSetting(SettingKey.tourDone, null);
    await repo.setSetting(SettingKey.hintsSeen, null);
    _tourWanted = true;
    await refresh();
  }

  bool hintDue(String id) => !settings.hintsSeen.contains(id);

  Future<void> markHintSeen(String id) async {
    if (!hintDue(id)) return;
    final seen = <String>[...settings.hintsSeen, id]..sort();
    await repo.setSetting(SettingKey.hintsSeen, jsonEncode(seen));
    await refresh();
  }

  // ---- Board groups (DESIGN §8.1) -------------------------------------

  bool _isCampfire(BoardQuest b) => b.quest.systemKey == systemKeyCampfire;
  bool _isComeback(BoardQuest b) => b.quest.systemKey == systemKeyComeback;

  /// Hero-track quests to do now.
  List<BoardQuest> get nowQuests => board
      .where(
        (b) =>
            !b.isDone &&
            !b.isSetAside &&
            !_isCampfire(b) &&
            !_isComeback(b) &&
            b.quest.track == Track.hero,
      )
      .toList();

  /// "Return to the Vale", while it is on today's board and not yet done.
  BoardQuest? get comebackQuest {
    for (final b in board) {
      if (_isComeback(b) && !b.isDone) return b;
    }
    return null;
  }

  /// Companion and Shared quests still open: the "With [Name]" section.
  List<BoardQuest> get companionQuests => board
      .where(
        (b) =>
            !b.isDone &&
            !b.isSetAside &&
            !_isCampfire(b) &&
            b.quest.track.travelsWithCompanion,
      )
      .toList();

  /// Quests the user set aside for later today.
  List<BoardQuest> get laterQuests =>
      board.where((b) => !b.isDone && b.isSetAside && !_isCampfire(b)).toList();

  List<BoardQuest> get doneQuests {
    final done = board.where((b) => b.isDone).toList()
      ..sort(
        (a, b) => a.completion!.completedAt.compareTo(b.completion!.completedAt),
      );
    return done;
  }

  /// Open Heroic and Boss quests: each has a Still creature sitting on it.
  List<BoardQuest> get stillQuests => board
      .where(
        (b) => !b.isDone && !_isCampfire(b) && drawsStill(b.quest.difficulty),
      )
      .toList();

  BoardQuest? get campfireQuest {
    for (final b in board) {
      if (_isCampfire(b)) return b;
    }
    return null;
  }

  int get questsTotalToday => board.length;
  int get questsDoneToday => board.where((b) => b.isDone).length;

  int get heroXpToday => board.fold(
        0,
        (sum, b) => sum + (b.completion?.xpAwarded ?? 0),
      );
  int get companionXpToday => board.fold(
        0,
        (sum, b) => sum + (b.completion?.companionXpAwarded ?? 0),
      );
  int get pacesToday => board.fold(
        0,
        (sum, b) => sum + (b.completion?.pacesAwarded ?? 0),
      );

  // ---- Actions --------------------------------------------------------

  Future<CompletionOutcome?> complete(
    String questId, {
    String? note,
    int? progress,
    DateTime? at,
  }) async {
    final outcome = await repo.completeQuest(
      questId,
      note: note,
      progress: progress,
      at: at,
      size: _sizeChoice[questId],
    );
    _sizeChoice.remove(questId);
    await refresh();
    if (outcome != null) _exportSoon();
    return outcome;
  }

  // ---- Goals, sizes and First Dawn (Amendment v0.4) ---------------------

  List<Goal> get goals => settings.activeGoals;
  List<HabitPlan> get plans => settings.activePlans;

  /// What the board shows for a quest beyond the quest itself, or null for
  /// one that is not on today's board.
  BoardLine? lineFor(String questId) => composed.lines[questId];

  /// The size a habit quest's card is showing. Null for any other quest.
  QuestSize? sizeFor(String questId) {
    final line = composed.lines[questId];
    if (line?.plan == null) return null;
    return _sizeChoice[questId] ?? line!.size;
  }

  /// One tap on the size chip: Tiny, Target, Stretch, and round again.
  void cycleSize(String questId) {
    final current = sizeFor(questId);
    if (current == null) return;
    _sizeChoice[questId] = current.next;
    notifyListeners();
  }

  /// The words on a quest's card: a habit's at the size showing, or at the
  /// size it was done at.
  String titleFor(BoardQuest b) {
    final line = composed.lines[b.quest.id];
    final plan = line?.plan;
    if (line == null || plan == null) return b.quest.name;
    final done = b.completion;
    if (done != null) return done.questNameSnapshot;
    return line.titleAt(
      sizeFor(b.quest.id) ?? QuestSize.target,
      calibration: settings.rhythm.calibrationOn(day),
    );
  }

  /// What finishing a quest is worth at the size showing.
  Difficulty worthFor(BoardQuest b) {
    final done = b.completion;
    if (done != null) return done.difficultySnapshot;
    final line = composed.lines[b.quest.id];
    final size = sizeFor(b.quest.id);
    if (line == null || size == null) return b.quest.difficulty;
    return line.difficultyAt(size, b.quest.difficulty);
  }

  /// What the scout says about today's board, or null.
  String? get scoutBoardHint {
    final cls = heroClass;
    if (cls == null) return null;
    return boardHint(
      cls: cls,
      type: enemyToday.type,
      quests: <QuestFact>[for (final b in board) _questFact(b)],
      lines: composed.lines,
      pouch: pouch,
    );
  }

  /// Where First Dawn stands. A hero from before 0.8 is offered it.
  FirstDawnState get firstDawnState =>
      settings.firstDawn ?? FirstDawnState.offered;

  /// The board shows "Tell Valebound your goals" while this is true.
  bool get firstDawnOffered =>
      hasProfile &&
      (firstDawnState == FirstDawnState.offered ||
          firstDawnState == FirstDawnState.begun);

  FirstDawnDraft get firstDawnDraft =>
      FirstDawnDraft.decode(settings.firstDawnDraft);

  /// Keeps the answers so far, so the flow can be left and resumed.
  Future<void> saveFirstDawnDraft(FirstDawnDraft draft) async {
    await repo.saveFirstDawnDraft(draft);
    settings = await repo.settings();
  }

  Future<void> setFirstDawn(FirstDawnState state) async {
    await repo.setFirstDawn(state);
    await refresh();
  }

  /// The questionnaire is finished: its answers become goals, habits and
  /// the first week's board.
  Future<void> finishFirstDawn(FirstDawnDraft draft) async {
    await repo.commitFirstDawn(
      draft,
      fresh: firstDawnState == FirstDawnState.fresh,
    );
    await refresh();
    _exportSoon();
  }

  /// A goal added later (Amendment v0.4 §7): the same chain, one goal.
  Future<void> addGoalFrom(FirstDawnDraft draft) async {
    await repo.commitFirstDawn(draft, fresh: false, wholeFlow: false);
    await refresh();
    _exportSoon();
  }

  Future<void> setGoalActive(String goalId, {required bool active}) async {
    await repo.setGoalActive(goalId, active: active);
    await refresh();
    _exportSoon();
  }

  Future<void> pinQuestToGoal(String questId, String? goalId) async {
    await repo.pinQuestToGoal(questId, goalId);
    await refresh();
  }

  Future<void> setExportEventNames({required bool on}) async {
    await repo.setSetting(SettingKey.exportEventNames, on ? '1' : null);
    await refresh();
    _exportSoon();
  }

  /// The recurring events of the next four weeks, for the mapping pass
  /// (Chapter 6). Read on the device, kept nowhere.
  Future<List<EventSeries>> readSeries() async {
    if (!settings.calendarOn || !calendarGranted) return const <EventSeries>[];
    final start = DayKey.parse(day);
    final end = DayKey.parse(DayKey.addDays(day, 28));
    final events = await device.eventsBetween(start, end);
    return recurringSeries(<EventFact>[
      for (final e in events)
        if (!settings.excludedCalendars.contains(e.calendarId)) _factOf(e),
    ]);
  }

  Future<void> saveMappings(List<CalendarMapping> mappings) async {
    await repo.setMappings(mappings);
    await refresh();
  }

  CalendarMapping? _mappingOf(CalendarOffer offer) {
    for (final m in settings.mappings) {
      if (m.seriesKey == offer.event.seriesKey) return m;
    }
    return null;
  }

  /// Yes to a Prep or Follow-through: a Minor quest for today.
  Future<void> acceptOffer(CalendarOffer offer) async {
    await repo.acceptSuggestion(
      externalId: offer.choiceKey,
      title: offer.questName,
      timeLabel: offer.prep ? 'Before ${offer.event.timeLabel}' : '',
      attribute: _mappingOf(offer)?.kind.attribute ?? Attribute.order,
      source: offer.prep ? QuestSource.prep : QuestSource.followThrough,
      difficulty: Difficulty.minor,
    );
    await refresh();
  }

  /// "Not today".
  Future<void> dismissOffer(CalendarOffer offer) async {
    await repo.dismissSuggestion(offer.choiceKey);
    await refresh();
  }

  /// "Never for this one": that offer is not made again for the series.
  Future<void> neverOffer(CalendarOffer offer) async {
    await repo.setMappings(<CalendarMapping>[
      for (final m in settings.mappings)
        if (m.seriesKey == offer.event.seriesKey)
          offer.prep ? m.copyWith(prepOff: true) : m.copyWith(followOff: true)
        else
          m,
    ]);
    await refresh();
  }

  // ---- The Sunday Check-In (Amendment v0.4 §6) --------------------------

  /// The check-in is open at the Campfire on the weekly day, once a week,
  /// for anyone with a habit plan.
  bool get checkInOpen =>
      plans.isNotEmpty &&
      DayKey.weekday(day) == settings.delveWeekday &&
      settings.checkIns.feltOn(day) == null;

  /// How each habit was done over the last two weeks, by size.
  Future<Map<String, SizeCounts>> sizeCounts({int days = 14}) =>
      repo.sizeCountsSince(DayKey.addDays(day, -(days - 1)));

  /// Records how the week felt and returns the one change to put to the
  /// user, or null. Nothing changes unless they accept it.
  Future<Proposal?> answerCheckIn(Felt felt) async {
    await repo.recordFelt(day, felt);
    final counts = await sizeCounts();
    await refresh();
    return proposeChange(
      plans: plans,
      counts: counts,
      felt: felt,
      declined: settings.checkIns.declined,
    );
  }

  Future<void> acceptProposal(Proposal proposal) async {
    await repo.acceptProposal(proposal);
    await refresh();
    _exportSoon();
  }

  Future<void> declineProposal(Proposal proposal) async {
    await repo.declineProposal(proposal);
    await refresh();
  }

  @override
  void dispose() {
    for (final pending in _pending.values) {
      pending.timer?.cancel();
    }
    _pending.clear();
    super.dispose();
  }

  // ---- Undo ------------------------------------------------------------

  /// How long a tapped completion can be taken back. Nothing is awarded
  /// until it has passed, so nothing ever has to be removed (DESIGN §6.4).
  static const Duration undoWindow = Duration(seconds: 5);

  final Map<String, PendingCompletion> _pending = <String, PendingCompletion>{};

  bool isPending(String questId) => _pending.containsKey(questId);

  /// Marks [entry] done, to be committed when the Undo window closes.
  void completeSoon(
    BoardQuest entry, {
    String? note,
    int? progress,
    void Function(CompletionOutcome outcome)? onCommitted,
  }) {
    final id = entry.quest.id;
    if (entry.isDone || _pending.containsKey(id)) return;
    final pending = PendingCompletion(
      entry: entry,
      at: repo.clock(),
      note: note,
      progress: progress,
      onCommitted: onCommitted,
    );
    pending.timer = Timer(undoWindow, () => unawaited(_commit(id)));
    _pending[id] = pending;
    notifyListeners();
  }

  /// Takes back a completion that is still inside its Undo window.
  void undo(String questId) {
    final pending = _pending.remove(questId);
    if (pending == null) return;
    pending.timer?.cancel();
    notifyListeners();
  }

  Future<void> _commit(String questId, {bool quietly = false}) async {
    final pending = _pending.remove(questId);
    if (pending == null) return;
    pending.timer?.cancel();
    final entry = pending.entry;
    final outcome = entry.quest.completionType == CompletionType.timer
        ? await completeTimer(entry, at: pending.at)
        : await complete(
            questId,
            note: pending.note,
            progress: pending.progress,
            at: pending.at,
          );
    if (outcome == null) {
      notifyListeners();
    } else if (!quietly) {
      pending.onCommitted?.call(outcome);
    }
  }

  /// Commits anything still inside its Undo window, without fanfare. Called
  /// when the app leaves the screen, so a tap is never dropped.
  Future<void> flushPending() async {
    for (final id in _pending.keys.toList()) {
      await _commit(id, quietly: true);
    }
  }

  /// Stores a count quest's value without completing it.
  Future<void> setCountOnly(String questId, int value) async {
    await repo.setCount(questId, value);
    await refresh();
  }

  /// Sets a count quest's value; completes it on reaching the target.
  Future<CompletionOutcome?> setCount(BoardQuest entry, int value) async {
    final target = entry.quest.target ?? 0;
    if (target > 0 && value >= target) {
      await repo.setCount(entry.quest.id, target);
      return complete(entry.quest.id, progress: target);
    }
    await repo.setCount(entry.quest.id, value);
    await refresh();
    return null;
  }

  Future<void> startTimer(String questId) async {
    await repo.startTimer(questId);
    await refresh();
  }

  Future<void> pauseTimer(String questId) async {
    await repo.pauseTimer(questId);
    await refresh();
  }

  Future<void> addTimerMinutes(String questId, int minutes) async {
    await repo.addTimerMinutes(questId, minutes);
    await refresh();
  }

  /// Completes a timer quest with whatever time it has recorded.
  Future<CompletionOutcome?> completeTimer(
    BoardQuest entry, {
    DateTime? at,
  }) async {
    await repo.pauseTimer(entry.quest.id);
    final fresh = await repo.loadBoard(day);
    var seconds = entry.banked;
    for (final b in fresh) {
      if (b.quest.id == entry.quest.id) seconds = b.banked;
    }
    return complete(entry.quest.id, progress: seconds, at: at);
  }

  Future<void> setAside(String questId, {required bool aside}) async {
    await repo.setAside(questId, aside: aside);
    await refresh();
  }

  Future<String> saveQuest(QuestDraft draft) async {
    final id = await repo.saveQuest(draft);
    await refresh();
    _exportSoon();
    return id;
  }

  Future<void> setQuestActive(String questId, {required bool active}) async {
    await repo.setQuestActive(questId, active: active);
    await refresh();
    _exportSoon();
  }

  // ---- Campfire (DESIGN §4.1 step 4) -----------------------------------

  /// Saves the day note and completes the Campfire Review, which closes the
  /// day and triggers the export.
  Future<CompletionOutcome?> closeDay({required String note}) async {
    final outcome = await repo.closeDay(note: note);
    await refresh();
    _exportSoon();
    return outcome;
  }

  /// Updates the note after the Campfire is done.
  Future<void> saveDayNote(String note) async {
    await repo.setDayNote(day, note);
    await refresh();
    _exportSoon();
  }

  // ---- Inventory -------------------------------------------------------

  Future<void> equipCosmetic(String key) async {
    await repo.equipCosmetic(key);
    await refresh();
  }

  Future<void> equipGear(String? key) async {
    await repo.equipGear(key);
    await refresh();
  }

  // ---- Settings --------------------------------------------------------

  Future<void> renameHero(String name) async {
    await repo.renameHero(name);
    await refresh();
    _exportSoon();
  }

  Future<void> changeCompanion({
    required String name,
    required CompanionKind kind,
  }) async {
    await repo.changeCompanion(name: name, kind: kind);
    await refresh();
    _exportSoon();
  }

  Future<void> pickVaultFolder() async {
    await export.vault.pickFolder();
    await export.exportPending();
    notifyListeners();
  }

  Future<void> forgetVaultFolder() async {
    await export.vault.forgetFolder();
    await export.refreshStatus();
    notifyListeners();
  }

  Future<void> exportNow() async {
    await export.exportPending();
    notifyListeners();
  }

  Future<bool> shareExport() async =>
      export.vault.shareFiles(await export.buildShareFiles(day));

  Future<bool> saveBackup() async => export.vault.saveDocument(
        'habit-adventure-backup-$day.json',
        await repo.exportBackupJson(),
      );

  /// Restores a backup chosen by the user. Null means no file was chosen.
  Future<BackupResult?> restoreBackup() async {
    final source = await export.vault.openDocument();
    if (source == null) return null;
    final result = await repo.importBackupJson(source);
    if (result.ok) {
      hasProfile = await repo.hasProfile();
      await refresh();
    }
    return result;
  }
}

/// Makes the [GameController] available to the widget tree.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope({
    super.key,
    required GameController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Rebuilds the caller whenever the game state changes.
  static GameController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'GameScope is missing above this widget');
    return scope!.notifier!;
  }

  /// For callbacks: reads the controller without subscribing.
  static GameController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<GameScope>();
    return scope!.notifier!;
  }
}
