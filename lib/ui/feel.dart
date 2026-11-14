import 'package:flutter/services.dart';

/// Touch feedback in one place, so the whole app answers the hand the same
/// way. These are the system's own short haptics: they need no permission
/// and they follow the phone's "touch feedback" setting.
abstract final class Feel {
  /// Moving between things: a tab, a story page, an Undo.
  static void tap() => HapticFeedback.selectionClick();

  /// Something was done: a quest ticked.
  static void done() => HapticFeedback.lightImpact();

  /// A moment worth marking: a level, a Discovery, a place waking.
  static void moment() => HapticFeedback.mediumImpact();
}
