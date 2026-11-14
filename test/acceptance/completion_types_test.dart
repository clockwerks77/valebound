import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/state/game_controller.dart';

import '../support/harness.dart';

// DESIGN §15: "A quest of each completion type can be created and
// completed." Each quest here is made the way the quest editor makes one (a
// draft saved through the controller) and completed the way its own screen
// completes it.

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;
  late MemoryDevice device;
  late GameController game;

  setUp(() async {
    now = DateTime(2026, 11, 14, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
    device = MemoryDevice();
    game = GameController(repo, device: device);
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    await game.init();
  });

  tearDown(() async {
    await game.exportNow();
    game.dispose();
    await db.close();
  });

  Future<String> create(
    String name,
    CompletionType type, {
    int? target,
  }) =>
      game.saveQuest(
        QuestDraft(
          name: name,
          attribute: Attribute.vitality,
          difficulty: Difficulty.minor,
          completionType: type,
          target: target,
        ),
      );

  BoardQuest entry(String id) => game.board.firstWhere((b) => b.quest.id == id);

  test('Tap: one tap completes it', () async {
    final id = await create('Water the herbs', CompletionType.tap);
    expect(entry(id).isDone, isFalse);

    final outcome = await game.complete(id);

    expect(outcome, isNotNull);
    expect(outcome!.heroXpGained, 10);
    expect(entry(id).isDone, isTrue);
  });

  test('Count: it completes on reaching its number', () async {
    final id = await create('Glasses of water', CompletionType.count, target: 8);

    expect(await game.setCount(entry(id), 3), isNull);
    expect(entry(id).isDone, isFalse);
    expect(entry(id).banked, 3);

    final outcome = await game.setCount(entry(id), 8);

    expect(outcome, isNotNull);
    expect(entry(id).isDone, isTrue);
    expect(entry(id).completion!.progress, 8);
  });

  test('Timer: it records the time that ran and completes', () async {
    final id = await create('Stretch', CompletionType.timer, target: 10);

    await game.startTimer(id);
    expect(entry(id).timerRunning, isTrue);
    now = now.add(const Duration(minutes: 10));
    final outcome = await game.completeTimer(entry(id));

    expect(outcome, isNotNull);
    expect(entry(id).isDone, isTrue);
    expect(entry(id).completion!.progress, 600);
  });

  test('Timer: minutes can be typed in instead of timed', () async {
    final id = await create('Read', CompletionType.timer, target: 20);

    await game.addTimerMinutes(id, 20);
    final outcome = await game.completeTimer(entry(id));

    expect(outcome, isNotNull);
    expect(entry(id).completion!.progress, 1200);
  });

  test('Auto: the day’s steps complete it at its target', () async {
    final id = await create('Evening stroll', CompletionType.auto, target: 5000);
    device.stepCount = 5200;

    expect(await game.connectSteps(), StepsAccess.connected);

    expect(entry(id).isDone, isTrue);
    expect(entry(id).completion!.progress, 5200);
    expect(
      game.takeAutoCompletions().map((a) => a.questId),
      contains(id),
    );
  });

  test('Auto: with steps refused, a tap completes it', () async {
    final id = await create('Evening stroll', CompletionType.auto, target: 5000);
    device.grantSteps = false;

    expect(await game.connectSteps(), StepsAccess.notConnected);
    expect(entry(id).isDone, isFalse);

    final outcome = await game.complete(id);

    expect(outcome, isNotNull);
    expect(entry(id).isDone, isTrue);
  });

  test('Confirm: it waits to be told, then completes', () async {
    final id = await create('Call the vet', CompletionType.confirm);
    device.stepCount = 9000;
    await game.connectSteps();
    await game.refresh(fromDevice: true);
    expect(entry(id).isDone, isFalse);

    final outcome = await game.complete(id);

    expect(outcome, isNotNull);
    expect(entry(id).isDone, isTrue);
  });

  test('all five are there to choose from', () {
    expect(CompletionType.values, hasLength(5));
    expect(
      CompletionType.values.map((t) => t.label),
      <String>['Tap', 'Count', 'Timer', 'Auto', 'Confirm'],
    );
  });
}
