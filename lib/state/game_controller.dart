import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/repository.dart';
import '../data/seed.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/enums.dart';
import '../rules/progression.dart';

/// Holds what the screens show and forwards every action to the repository.
/// No state-management package: a plain [ChangeNotifier] is enough for one
/// player on one device (DECISIONS.md D-03).
class GameController extends ChangeNotifier {
  GameController(this.repo);

  final GameRepository repo;

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
    loading = false;
    notifyListeners();
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
  }) async {
    final outcome =
        await repo.completeQuest(questId, note: note, progress: progress);
    await refresh();
    return outcome;
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
  Future<CompletionOutcome?> completeTimer(BoardQuest entry) async {
    if (entry.timerRunning) {
      await repo.pauseTimer(entry.quest.id);
    }
    final fresh = await repo.loadBoard(day);
    var seconds = entry.banked;
    for (final b in fresh) {
      if (b.quest.id == entry.quest.id) seconds = b.banked;
    }
    return complete(entry.quest.id, progress: seconds);
  }

  Future<void> setAside(String questId, {required bool aside}) async {
    await repo.setAside(questId, aside: aside);
    await refresh();
  }

  Future<String> saveQuest(QuestDraft draft) async {
    final id = await repo.saveQuest(draft);
    await refresh();
    return id;
  }

  Future<void> setQuestActive(String questId, {required bool active}) async {
    await repo.setQuestActive(questId, active: active);
    await refresh();
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
