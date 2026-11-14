import '../data/database.dart';
import '../data/repository.dart';
import '../rules/companion_rules.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/journey.dart';
import '../rules/world.dart';
import '../rules/xp_curve.dart';
import 'markdown.dart';
import 'vault_port.dart';

/// What Settings shows about the export (DESIGN §11). Never an error.
enum ExportState {
  /// No vault folder has been picked yet.
  noFolder,

  /// A folder is picked but cannot be written to right now. The export is
  /// queued and goes out by itself when the folder is there again.
  waiting,

  /// Everything is written.
  upToDate,
}

/// Builds the Markdown files from the database and writes them to the vault.
///
/// The queue is the database itself: a day needs exporting while its log has
/// no `exportedAt`. Every change to a day clears that stamp, so nothing is
/// forgotten if the folder is away for a while.
class ExportService {
  ExportService(this.repo, this.vault);

  final GameRepository repo;
  final VaultPort vault;

  VaultStatus vaultStatus = const VaultStatus();
  ExportState state = ExportState.noFolder;
  DateTime? lastExportAt;
  int pendingDays = 0;

  bool _running = false;
  bool _again = false;

  /// Days with something to export whose file is not yet written.
  Future<List<String>> _pending() async {
    final logs = await repo.allDayLogs();
    final completions = await repo.allCompletions();
    final daysWithContent = <String>{
      for (final c in completions) c.day,
      ...await repo.daysWithHealthEntries(),
    };
    return <String>[
      for (final log in logs)
        if (log.exportedAt == null &&
            (daysWithContent.contains(log.day) ||
                log.campfireAt != null ||
                log.dayNote.trim().isNotEmpty))
          log.day,
    ];
  }

  Future<void> refreshStatus() async {
    vaultStatus = await vault.status();
    if (!vaultStatus.chosen) {
      // Nothing is queued anywhere until there is a folder to queue for.
      state = ExportState.noFolder;
      pendingDays = 0;
      return;
    }
    pendingDays = (await _pending()).length;
    if (!vaultStatus.available) {
      state = ExportState.waiting;
    } else {
      state = pendingDays == 0 ? ExportState.upToDate : ExportState.waiting;
    }
  }

  /// Writes the Character Sheet, the quest list and every queued day. Quiet
  /// by design: if the folder is not there, the queue simply stays.
  Future<void> exportPending() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        vaultStatus = await vault.status();
        if (!vaultStatus.chosen || !vaultStatus.available) continue;
        if (!await repo.hasProfile()) continue;
        final days = await _pending();
        final files = await buildFiles(days: days);
        if (await vault.writeFiles(files)) {
          await repo.markExported(days);
          lastExportAt = repo.clock();
        }
      } while (_again);
    } finally {
      _running = false;
    }
    await refreshStatus();
  }

  /// The files for Share…: the sheet, the quest list, today, and anything
  /// still queued.
  Future<Map<String, String>> buildShareFiles(String today) async {
    final days = <String>{...await _pending(), today}.toList()..sort();
    return buildFiles(days: days);
  }

  /// `relative path → content` for the sheet, the quest list and [days].
  Future<Map<String, String>> buildFiles({required List<String> days}) async {
    final hero = await repo.hero();
    final companion = await repo.companion();
    final world = await repo.world();
    if (hero == null || companion == null || world == null) {
      return <String, String>{};
    }
    final now = repo.clock();
    final completions = await repo.allCompletions();
    final quests = await repo.allQuests();
    final logs = <String, DayLogRow>{
      for (final l in await repo.allDayLogs()) l.day: l,
    };
    final files = <String, String>{
      characterSheetFile: characterSheetMarkdown(
        await _sheet(hero, companion, world, completions.length, now),
      ),
      questsFile: questsMarkdown(
        QuestsData(
          updated: now,
          companionName: companion.name,
          quests: <QuestLine>[
            for (final q in quests)
              if (q.active)
                QuestLine(
                  name: q.name,
                  attribute: q.attribute,
                  difficulty: q.difficulty,
                  schedule: scheduleOf(q).describe(),
                  type: describeType(q.completionType, q.target),
                  track: q.track,
                ),
          ],
        ),
      ),
    };
    final restoredOn = decodeStringMap(world.buildingState);
    for (final day in days) {
      files[dailyFile(day)] = dailyMarkdown(
        await _day(day, completions, logs[day], restoredOn),
      );
    }
    return files;
  }

  Future<SheetData> _sheet(
    CharacterRow hero,
    CompanionRow companion,
    WorldStateRow world,
    int questsCompleted,
    DateTime now,
  ) async {
    final attributeXp = decodeAttributeXp(hero.attributeXp);
    final gathered = decodeMaterials(hero.materials);
    final restored = restoredCount(gathered);
    final stores = inStores(gathered);
    final target = targetAt(restored);
    final discoveryKeys = decodeStringList(world.discoveriesUnlocked);
    final byRegion = <String, List<String>>{};
    for (var i = 0; i < restored; i++) {
      final t = targetAt(i);
      byRegion.putIfAbsent(regionByKey(t.region).name, () => <String>[]).add(t.name);
    }
    return SheetData(
      updated: now,
      heroName: hero.name,
      heroLevel: hero.level,
      heroTotalXp: hero.totalXp,
      title: titleForLevel(hero.level),
      attributes: <AttributeLine>[
        for (final a in Attribute.values)
          AttributeLine(
            a,
            XpCurve.levelForXp(attributeXp[a] ?? 0),
            attributeXp[a] ?? 0,
          ),
      ],
      questsCompleted: questsCompleted,
      gold: hero.gold,
      stores: stores,
      gathered: gathered,
      daysVisited: await repo.daysVisited(),
      companionName: companion.name,
      companionKind: companion.kind.label,
      companionLevel: companion.level,
      companionXp: companion.totalXp,
      bond: companion.bond,
      tricks: <String>[
        for (final t in companionTricks)
          if (companion.level >= t.level) t.name,
      ],
      gear: <String>[
        for (final g in companionGear)
          if (decodeStringList(companion.gearUnlocked).contains(g.key)) g.name,
      ],
      paces: world.journeyPaces,
      discoveries: <String>[
        for (var i = 0; i < discoveryKeys.length; i++)
          sceneByKey(discoveryKeys[i], i).title,
      ],
      placesRestored: restored,
      placesDrafted: restorationTargets.length,
      restoredByRegion: byRegion,
      nextTarget: target.name,
      nextNeeds: <TargetNeed>[
        for (final k in MaterialKind.values)
          TargetNeed(
            k,
            (stores[k] ?? 0) > target.costOf(k)
                ? target.costOf(k)
                : (stores[k] ?? 0),
            target.costOf(k),
          ),
      ],
    );
  }

  Future<DayData> _day(
    String day,
    List<CompletionRow> completions,
    DayLogRow? log,
    Map<String, String> restoredOn,
  ) async {
    var xpThroughDay = 0;
    var pacesBefore = 0;
    var pacesToday = 0;
    final today = <CompletionRow>[];
    for (final c in completions) {
      final order = c.day.compareTo(day);
      if (order <= 0) xpThroughDay += c.xpAwarded;
      if (order < 0) pacesBefore += c.pacesAwarded;
      if (order == 0) {
        pacesToday += c.pacesAwarded;
        today.add(c);
      }
    }
    final pacesTotal = pacesBefore + pacesToday;
    final health = await repo.healthEntriesOn(day);
    int? steps;
    for (final h in health) {
      if (h.fieldKey == 'steps') {
        steps = int.tryParse(h.value.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }
    final restoredToday = <int>[
      for (final e in restoredOn.entries)
        if (e.value == day) targetIndexByKey(e.key),
    ]..sort();
    final boardSize = log?.questsTotal ?? (await repo.loadBoard(day)).length;
    return DayData(
      day: day,
      heroLevel: XpCurve.levelForXp(xpThroughDay),
      xpEarned: today.fold(0, (sum, c) => sum + c.xpAwarded),
      companionXpEarned: today.fold(0, (sum, c) => sum + c.companionXpAwarded),
      paces: pacesToday,
      questsTotal: boardSize,
      steps: steps,
      quests: <DayQuestLine>[
        for (final c in today)
          DayQuestLine(
            completedAt: c.completedAt,
            quest: c.questNameSnapshot,
            track: c.trackSnapshot,
            attribute: c.attributeSnapshot,
            difficulty: c.difficultySnapshot,
            heroXp: c.xpAwarded,
            companionXp: c.companionXpAwarded,
          ),
      ],
      pacesTotal: pacesTotal,
      campRegion: regions[regionIndexForPaces(pacesTotal)].name,
      pacesToNextDiscovery: pacesToNextDiscovery(pacesTotal),
      discoveries: <String>[
        for (final i in newDiscoveries(pacesBefore, pacesTotal))
          sceneFor(i).title,
      ],
      health: <HealthLine>[
        for (final h in health)
          HealthLine(
            healthLabel(h.fieldKey),
            h.fieldKey == 'steps' && steps != null ? thousands(steps) : h.value,
            h.unit,
          ),
      ],
      restorations: <String>[
        for (final i in restoredToday)
          if (i >= 0) '${targetAt(i).name} (${regionByKey(targetAt(i).region).name})',
      ],
      note: log?.dayNote ?? '',
    );
  }
}
