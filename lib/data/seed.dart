import 'package:drift/drift.dart';

import '../rules/enums.dart';
import 'database.dart';

/// System quest keys.
const String systemKeyCampfire = 'campfire';

/// First-run quests, DESIGN §12. All are editable and archivable.
///
/// "Today's Commitment" (§12 item 3) is a template for accepted calendar
/// suggestions rather than a fixed quest, so it has no row here; it arrives
/// with calendar suggestions in Phase 3.
List<QuestsCompanion> seedQuests({
  required DateTime now,
  required String Function() newId,
  required bool activateFiveMinuteReset,
}) {
  QuestsCompanion quest({
    required String name,
    required String icon,
    required Attribute attribute,
    required Difficulty difficulty,
    required Track track,
    required ScheduleType scheduleType,
    String weekdays = '',
    required CompletionType type,
    int? target,
    String notes = '',
    bool active = true,
    QuestSource source = QuestSource.recurring,
    String? systemKey,
    required int sortOrder,
  }) {
    return QuestsCompanion.insert(
      id: newId(),
      name: name,
      iconKey: Value(icon),
      attribute: attribute,
      difficulty: difficulty,
      track: track,
      scheduleType: scheduleType,
      scheduleWeekdays: Value(weekdays),
      completionType: type,
      target: Value(target),
      notes: Value(notes),
      active: Value(active),
      source: source,
      systemKey: Value(systemKey),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    );
  }

  return <QuestsCompanion>[
    // 1. The flagship companion quest: full Companion XP + half hero Care XP.
    quest(
      name: 'Walk Babs',
      icon: 'paw',
      attribute: Attribute.care,
      difficulty: Difficulty.standard,
      track: Track.shared,
      scheduleType: ScheduleType.daily,
      type: CompletionType.tap,
      sortOrder: 10,
    ),
    // 1a. A lesser goal living on the companion track.
    quest(
      name: 'Play / Train with Babs',
      icon: 'ball',
      attribute: Attribute.care,
      difficulty: Difficulty.minor,
      track: Track.companion,
      scheduleType: ScheduleType.daily,
      type: CompletionType.timer,
      target: 10,
      sortOrder: 20,
    ),
    // 1b. A non-pet lesser goal. Seeded inactive; onboarding offers it.
    quest(
      name: 'Five-Minute Reset',
      icon: 'broom',
      attribute: Attribute.order,
      difficulty: Difficulty.minor,
      track: Track.companion,
      scheduleType: ScheduleType.daily,
      type: CompletionType.timer,
      target: 5,
      notes: 'Tidy, stretch, or reset one small space.',
      active: activateFiveMinuteReset,
      sortOrder: 30,
    ),
    // 2. Fills from Health Connect in Phase 3; manual tap until then.
    quest(
      name: '7,000 Steps',
      icon: 'boot',
      attribute: Attribute.vitality,
      difficulty: Difficulty.standard,
      track: Track.hero,
      scheduleType: ScheduleType.daily,
      type: CompletionType.auto,
      target: 7000,
      source: QuestSource.health,
      sortOrder: 40,
    ),
    // 4. Appears on the days the user enables. Default: the weekend.
    quest(
      name: 'Painting / Craft Block',
      icon: 'brush',
      attribute: Attribute.craft,
      difficulty: Difficulty.heroic,
      track: Track.hero,
      scheduleType: ScheduleType.weekdays,
      weekdays: '6,7',
      type: CompletionType.timer,
      target: 60,
      sortOrder: 50,
    ),
    // 5. Opens the Health Log in Phase 3.
    quest(
      name: 'Morning Health Check',
      icon: 'sprig',
      attribute: Attribute.vitality,
      difficulty: Difficulty.minor,
      track: Track.hero,
      scheduleType: ScheduleType.daily,
      type: CompletionType.tap,
      sortOrder: 5,
    ),
    // 6. Weekly, Saturday, with an optional dose note.
    quest(
      name: 'Weekly Injection (Mounjaro)',
      icon: 'vial',
      attribute: Attribute.vitality,
      difficulty: Difficulty.minor,
      track: Track.hero,
      scheduleType: ScheduleType.weekly,
      weekdays: '6',
      type: CompletionType.tap,
      notes: 'Add a dose note when you complete it, if you like.',
      sortOrder: 60,
    ),
    // 7. The ritual that closes the day.
    quest(
      name: 'Campfire Review',
      icon: 'campfire',
      attribute: Attribute.mind,
      difficulty: Difficulty.minor,
      track: Track.hero,
      scheduleType: ScheduleType.daily,
      type: CompletionType.tap,
      source: QuestSource.system,
      systemKey: systemKeyCampfire,
      sortOrder: 900,
    ),
  ];
}
