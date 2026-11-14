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
import '../rules/companion_rules.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/health_fields.dart';
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
  bool get calendarOfferDue => !settings.calendarAsked && !settings.calendarOn;

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

  Future<void> _reload({bool fromDevice = false}) async {
    lastDawn = await repo.ensureDawn();
    final today = DayKey.of(repo.clock());
    final readDevice = fromDevice || today != day;
    day = today;
    settings = await repo.settings();
    if (readDevice) {
      await _readSteps();
      await _readGlucose();
    }
    await repo.syncWorld();
    hero = await repo.hero();
    companion = await repo.companion();
    world = await repo.world();
    board = await repo.loadBoard(day);
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
    delve = await repo.delveWaiting();
    if (readDevice) await _readCalendar();
    await _filterSuggestions();
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

  Future<void> _filterSuggestions() async {
    if (!settings.calendarOn || _eventsToday.isEmpty) {
      suggestions = const <CalendarEvent>[];
      return;
    }
    final choices = await repo.calendarChoicesOn(day);
    // One event often sits in two calendars. It is offered once, and a
    // choice made about one copy counts for them all.
    final settled = <String>{
      for (final e in _eventsToday)
        if (choices.containsKey(e.id)) e.sameAs,
    };
    suggestions = <CalendarEvent>[
      for (final e in _eventsToday)
        if (!choices.containsKey(e.id) &&
            !settings.excludedCalendars.contains(e.calendarId) &&
            settled.add(e.sameAs))
          e,
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
    await repo.setSetting(SettingKey.calendarOn, granted ? '1' : '0');
    await refresh(fromDevice: true);
    return granted;
  }

  /// "Not now": the board stays as it is, and Settings can turn it on later.
  Future<void> declineCalendar() async {
    await repo.setSetting(SettingKey.calendarAsked, '1');
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
    _tourWanted = !settings.tourDone;
    notifyListeners();
  }

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
    );
    await refresh();
    if (outcome != null) _exportSoon();
    return outcome;
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
