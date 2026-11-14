import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/export/export_service.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/health_fields.dart';

import '../support/harness.dart';

// Glucose from Health Connect (DECISIONS D-71): the day's average, kept as a
// number in the Health Log and the day note. Also the whole-day step count
// written back for a day already gone by.

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;
  late MemoryVault vault;
  late ExportService export;

  Future<String> id(String name) async =>
      (await repo.allQuests()).firstWhere((q) => q.name == name).id;

  setUp(() async {
    now = DateTime(2026, 11, 14, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
    vault = MemoryVault(chosen: true);
    export = ExportService(repo, vault);
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    await repo.ensureDawn();
  });

  tearDown(() => db.close());

  test('figures are shown to one decimal place, in mmol/L', () {
    expect(formatGlucose(7.44), '7.4');
    expect(formatGlucose(7.46), '7.5');
    expect(formatGlucose(10), '10.0');
    expect(glucoseAverageUnit, 'mmol/L');
  });

  test('the day’s average is kept in the Health Log and reaches the note',
      () async {
    await repo.recordGlucoseAverage('2026-11-14', 7.44);
    final entry =
        (await repo.healthEntriesByKey('2026-11-14'))[glucoseAverageFieldKey]!;
    expect(entry.value, '7.4');
    expect(entry.unit, 'mmol/L');

    await export.exportPending();
    expect(
      vault.files['Daily/2026-11-14.md'],
      contains('## Health\n\n- Average glucose: 7.4 mmol/L\n'),
    );
  });

  test('a reading typed by hand is left as typed, beside it', () async {
    await repo.setHealthEntry('2026-11-14', 'glucose', '10.2', unit: 'mmol/L');
    await repo.recordGlucoseAverage('2026-11-14', 8.31);
    await export.exportPending();
    expect(
      vault.files['Daily/2026-11-14.md'],
      contains(
        '## Health\n\n- Glucose: 10.2 mmol/L\n- Average glucose: 8.3 mmol/L\n',
      ),
    );
  });

  test('the figure follows the day as more readings arrive', () async {
    await repo.recordGlucoseAverage('2026-11-14', 6.12);
    await repo.recordGlucoseAverage('2026-11-14', 6.58);
    final entries = await repo.healthEntriesOn('2026-11-14');
    expect(entries.where((e) => e.fieldKey == glucoseAverageFieldKey).single.value,
        '6.6');
  });

  test('an unchanged figure does not send the day back to be written again',
      () async {
    await repo.completeQuest(await id('Walk Babs'));
    await repo.recordGlucoseAverage('2026-11-14', 7.44);
    await export.exportPending();
    expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNotNull);

    await repo.recordGlucoseAverage('2026-11-14', 7.41);
    expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNotNull);

    await repo.recordGlucoseAverage('2026-11-14', 7.9);
    expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNull);
  });

  test('a day the app was never opened on gets no figure and no note',
      () async {
    await repo.recordGlucoseAverage('2026-11-10', 6.4);
    await repo.recordStepsFor('2026-11-10', 9000);
    expect(await repo.healthEntriesOn('2026-11-10'), isEmpty);
    expect(await repo.dayLog('2026-11-10'), isNull);
    await export.exportPending();
    expect(vault.files.containsKey('Daily/2026-11-10.md'), isFalse);
  });

  test('nothing is kept for a reading that is not a reading', () async {
    await repo.recordGlucoseAverage('2026-11-14', 0);
    await repo.recordGlucoseAverage('2026-11-14', -3);
    expect(await repo.healthEntriesOn('2026-11-14'), isEmpty);
  });

  test('yesterday’s whole step count is written back, and completes nothing',
      () async {
    // Saturday: opened in the evening with 5,100 steps so far.
    now = DateTime(2026, 11, 14, 19);
    await repo.recordSteps(5100);
    final steps = await id('7,000 Steps');
    expect(await repo.completionsOn('2026-11-14'), isEmpty);

    // Sunday morning: Saturday ended on 8,340.
    now = DateTime(2026, 11, 15, 8);
    await repo.ensureDawn();
    await repo.recordStepsFor('2026-11-14', 8340);
    expect(
      (await repo.healthEntriesByKey('2026-11-14'))[stepsFieldKey]!.value,
      '8340',
    );
    // Saturday's board is closed: its quest is not completed after the fact.
    expect(await repo.completionsOn('2026-11-14'), isEmpty);
    expect(
      (await repo.loadBoard('2026-11-15'))
          .firstWhere((b) => b.quest.id == steps)
          .isDone,
      isFalse,
    );
  });
}
