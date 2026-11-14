import 'package:flutter/widgets.dart';

import '../../state/game_controller.dart';
import 'tour.dart';

/// The first-run tour of the board: what each part is and where to go.
/// Asked for by Adam after his first run on the Fold (DECISIONS D-72).
List<TourStep> boardTour(String companion) => <TourStep>[
      const TourStep(
        title: 'Welcome to the Vale',
        body: 'Your real day is the game. Do something real, tap it here, '
            'and the Vale wakes a little more. Here is a quick look round.',
      ),
      TourStep(
        title: 'The storyteller',
        body: 'This line says where you are in the Vale and what is waiting '
            'to be woken. It turns with the day. Tap it for the Chronicle: '
            'the story so far.',
        target: TourMark.story,
      ),
      TourStep(
        title: 'You and $companion',
        body: 'Your quests raise your level. $companion levels beside you, '
            'from the small quests you give them.',
        target: TourMark.party,
      ),
      TourStep(
        title: 'A place to wake',
        body: 'Your own quests gather Timber, Stone and Star Shards. When '
            'this place has what it needs it wakes, and someone comes home.',
        target: TourMark.restoring,
      ),
      TourStep(
        title: 'The road',
        body: 'Quests done with $companion are Paces along the road. Every '
            '10 Paces there is something to find.',
        target: TourMark.road,
      ),
      TourStep(
        title: 'Today’s sleeper',
        body: 'A Still creature dozes somewhere in the Vale each day. Every '
            'quest you finish stirs it. The third wakes it, and it leaves a '
            'gift.',
        target: TourMark.sleeper,
      ),
      TourStep(
        title: 'A quest',
        body: 'Tap the ring when you have done it. You get a few seconds to '
            'undo. Tap the card for its details, a timer or a count.',
        target: TourMark.quest,
      ),
      TourStep(
        title: 'With $companion',
        body: 'Small, kind, easy-to-drop goals live with your companion. '
            'They count just as much.',
        target: TourMark.companion,
      ),
      TourStep(
        title: 'The Campfire',
        body: 'When the day is done, close it here: a short review, a note '
            'if you like, and the day is written to your vault.',
        target: TourMark.campfire,
      ),
      TourStep(
        title: 'Anything else',
        body: 'Add a quest at any time, even for something you have already '
            'done. Real life first, logging second.',
        target: TourMark.newQuest,
      ),
      TourStep(
        title: 'Health Log and Settings',
        body: 'The sprig opens the Health Log. The sliders open Settings, '
            'where you can run this tour again.',
        target: TourMark.tools,
      ),
      TourStep(
        title: 'Getting around',
        body: 'Map: the Vale and the road. Character: you, $companion and '
            'what you carry. Log: every quest, and the days gone by.',
        target: TourMark.nav,
      ),
    ];

/// Screens that explain themselves once, the first time they are opened.
abstract final class HintId {
  static const String map = 'map';
  static const String party = 'party';
  static const String log = 'log';
  static const String campfire = 'campfire';

  static const List<String> all = <String>[map, party, log, campfire];
}

TourStep? _hint(String id, String companion) => switch (id) {
      HintId.map => TourStep(
          title: 'The Vale',
          body: 'Grey places are still asleep. The gold road shows how far '
              'you and $companion have come, and each lantern on it is '
              'something you found. Below the map is the place you are '
              'working toward and what it still needs.',
        ),
      HintId.party => TourStep(
          title: 'You and $companion',
          body: 'Levels, the six attributes your quests feed, and '
              '$companion’s Bond, tricks and gear. Inventory, at the top, '
              'holds your gold, materials and what you have unlocked.',
        ),
      HintId.log => const TourStep(
          title: 'The Quest Log',
          body: 'Every quest you keep: add one, change one, or put one '
              'away. Further down are the days gone by. A quiet day is '
              'just a quiet day.',
        ),
      HintId.campfire => TourStep(
          title: 'The Campfire',
          body: 'Today at a glance: what you and $companion did and what '
              'changed in the Vale. Write a note if you like, then close '
              'the day. That writes today’s page to your vault.',
        ),
      _ => null,
    };

/// Shows the hint for screen [id], the first time only.
Future<void> showHintOnce(BuildContext context, String id) async {
  final game = GameScope.read(context);
  final step = _hint(id, game.companionName);
  if (step == null || !game.hintDue(id)) return;
  await game.markHintSeen(id);
  if (!context.mounted) return;
  await runTour(context, <TourStep>[step], doneLabel: 'Got it');
}
