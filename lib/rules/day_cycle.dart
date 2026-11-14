import 'day_key.dart';

/// Full calendar days with no visit before the comeback quest is offered.
/// DESIGN §4.3: "not opened for 2+ days". See DECISIONS.md D-11.
const int comebackAfterFullDaysAway = 2;

/// The single quest offered after time away (DESIGN §4.3): Minor, with
/// bonus XP. It stands beside today's ordinary board; nothing from the days
/// away is listed anywhere.
const String comebackQuestName = 'Return to the Vale';

/// Bonus hero XP on the comeback quest, on top of a Minor quest's 10: the
/// welcome is worth a Standard quest in all (DECISIONS.md D-48).
const int comebackBonusXp = 15;

/// Bonus Bond when the companion knows Comfort and presents the comeback
/// quest (DESIGN §7A.3).
const int comfortBonusBond = 2;

/// What the app should do the first time it is opened on a given day.
class DawnPlan {
  const DawnPlan({
    required this.today,
    required this.isFirstDawn,
    required this.isNewDay,
    required this.fullDaysAway,
    required this.comebackDue,
  });

  final String today;

  /// No day has ever been opened before.
  final bool isFirstDawn;

  /// Today has no Dawn yet, so a fresh board is generated.
  final bool isNewDay;

  /// Whole days between the last visit and today on which the app was not
  /// opened at all. Opened Monday, back Thursday: two (Tuesday, Wednesday).
  final int fullDaysAway;

  /// Offer the single "Return to the Vale" quest (DESIGN §4.3).
  final bool comebackDue;
}

/// Day rollover rules, DESIGN §4.1 step 5, §4.3 and §6.4.
///
/// A new day begins at local midnight. Nothing from an earlier day carries
/// over: no backlog, no catch-up, and no record of what was left undone.
DawnPlan planDawn({required String? lastDawnDay, required DateTime now}) {
  final today = DayKey.of(now);
  if (lastDawnDay == null) {
    return DawnPlan(
      today: today,
      isFirstDawn: true,
      isNewDay: true,
      fullDaysAway: 0,
      comebackDue: false,
    );
  }
  final gap = DayKey.daysBetween(lastDawnDay, today);
  if (gap <= 0) {
    // Same day, or the device clock moved backwards. Either way: carry on.
    return DawnPlan(
      today: today,
      isFirstDawn: false,
      isNewDay: false,
      fullDaysAway: 0,
      comebackDue: false,
    );
  }
  final away = gap - 1;
  return DawnPlan(
    today: today,
    isFirstDawn: false,
    isNewDay: true,
    fullDaysAway: away,
    comebackDue: away >= comebackAfterFullDaysAway,
  );
}
