import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../export/export_service.dart';
import '../export/vault_port.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/progression.dart';
import '../rules/still.dart';
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
  GameController(this.repo, {VaultPort vault = const NoVault()})
      : export = ExportService(repo, vault);

  final GameRepository repo;

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
    if (hasProfile) {
      await _reload();
    }
    await export.refreshStatus();
    loading = false;
    notifyListeners();
    if (hasProfile) _exportSoon();
  }

  /// Re-reads everything. Also rolls the day over if midnight has passed.
  Future<void> refresh() async {
    if (!hasProfile) return;
    await _reload();
    notifyListeners();
  }

  Future<void> _reload() async {
    lastDawn = await repo.ensureDawn();
    day = DayKey.of(repo.clock());
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
    today = await repo.dayLog(day);
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
    notifyListeners();
  }

  // ---- Board groups (DESIGN §8.1) -------------------------------------

  bool _isCampfire(BoardQuest b) => b.quest.systemKey == systemKeyCampfire;

  /// Hero-track quests to do now.
  List<BoardQuest> get nowQuests => board
      .where(
        (b) =>
            !b.isDone &&
            !b.isSetAside &&
            !_isCampfire(b) &&
            b.quest.track == Track.hero,
      )
      .toList();

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
