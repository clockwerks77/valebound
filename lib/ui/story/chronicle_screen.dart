import 'package:flutter/material.dart';

import '../../rules/day_key.dart';
import '../../rules/journey.dart';
import '../../rules/narrator.dart';
import '../../rules/world.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'story.dart';

/// Opens the Chronicle: where things stand, and the story so far.
Future<void> openChronicle(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const ChronicleScreen()),
  );
}

/// The Chronicle (DECISIONS D-76): the narrator's account of the Vale, read
/// back. One card says where things stand today; beneath it, every chapter
/// that has opened and every place that has woken, oldest first.
///
/// All of it is worked out from what has been restored and when. It is a
/// record of what happened, never of what did not.
class ChronicleScreen extends StatelessWidget {
  const ChronicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final entries = game.story;

    final header = Row(
      children: <Widget>[
        RoundIconButton(
          icon: 'close',
          semanticLabel: 'Close the Chronicle',
          size: 40,
          background: Palette.forestNight.withValues(alpha: 0.5),
          foreground: Palette.onDark,
          edge: Palette.onDark.withValues(alpha: 0.25),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Chronicle',
                style: AppText.display.copyWith(
                  color: Palette.onDark,
                  fontSize: 26,
                ),
              ),
              Text(
                game.storyTitle,
                style: AppText.small.copyWith(color: Palette.onDarkSoft),
              ),
            ],
          ),
        ),
      ],
    );

    final story = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          'THE STORY SO FAR',
          style: AppText.label.copyWith(color: Palette.goldBright),
        ),
      ),
      for (final entry in entries) _EntryView(entry: entry),
    ];

    // The heading and its Close button stay put while the page scrolls.
    final top = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: header,
    );

    return Scaffold(
      backgroundColor: Palette.forestDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Palette.forest,
              Palette.forestDeep,
              Palette.forestNight,
            ],
            stops: <double>[0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: isExpanded(context)
              ? TwoPane(
                  start: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                        child: header,
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 0, 24),
                          children: const <Widget>[_Standing()],
                        ),
                      ),
                    ],
                  ),
                  end: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 22, 14, 24),
                    children: story,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    top,
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                        children: <Widget>[
                          const _Standing(),
                          const SizedBox(height: 20),
                          ...story,
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Where things stand today, in the narrator's words and then plainly.
class _Standing extends StatelessWidget {
  const _Standing();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final restored = game.restored;
    final drafted = restorationTargets.length;
    final awake = restored > drafted ? drafted : restored;
    final chapter = game.chapter;
    final progress = chapterProgress(chapter, restored);
    final target = game.target;
    final percent = (targetProgress(game.materials) * 100).round();
    final paces = game.world?.journeyPaces ?? 0;
    final camp = regions[regionIndexForPaces(paces)].name;
    final found = game.discoveries.length;
    final lanterns = restored - drafted;

    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WHERE THINGS STAND',
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 8),
          Text(
            game.narration.full,
            style: AppText.narrator.copyWith(
              color: Palette.slate,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          _Fact(
            icon: 'sun',
            text: awake == 0
                ? 'The whole Vale is asleep: $drafted places, waiting.'
                : '$awake of the Vale’s $drafted places are awake, and '
                    '$awake ${awake == 1 ? 'villager is' : 'villagers are'} '
                    'home.',
          ),
          if (!valeIsAwake(restored))
            _Fact(
              icon: 'book',
              text: '${chapter.heading}: ${progress.awake} of '
                  '${progress.of} places awake.',
            )
          else if (lanterns > 0)
            _Fact(
              icon: 'lantern',
              text: lanterns == 1
                  ? 'One more lantern lit along the road since.'
                  : '$lanterns more lanterns lit along the road since.',
            ),
          _Fact(
            icon: 'home',
            text: 'Waking next: ${target.name}, $percent% of the way there.',
          ),
          _Fact(
            icon: 'pace',
            text: paces == 0
                ? 'Camp is at the village gate, in $camp.'
                : 'Camp is $paces ${paces == 1 ? 'Pace' : 'Paces'} along '
                    'the road, in $camp.',
          ),
          _Fact(
            icon: 'lantern',
            text: found == 0
                ? 'No Discoveries on the road yet. The first is '
                    '${pacesToNextDiscovery(paces)} '
                    '${pacesToNextDiscovery(paces) == 1 ? 'Pace' : 'Paces'} '
                    'on.'
                : '$found ${found == 1 ? 'Discovery' : 'Discoveries'} found '
                    'on the road with ${game.companionName}.',
          ),
          const SizedBox(height: 10),
          QuietButton(
            label: 'Read the prologue again',
            icon: 'book',
            onPressed: () => showPrologue(
              context,
              companionName: game.companionName,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: VIcon(icon, size: 16, color: Palette.moss),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: Palette.slate),
            ),
          ),
        ],
      ),
    );
  }
}

String _dated(String? day) => day == null ? '' : DayKey.friendly(day);

/// One entry in the story: a chapter page in the narrator's voice, or a
/// place that woke.
class _EntryView extends StatelessWidget {
  const _EntryView({required this.entry});

  final ChronicleEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = _dated(entry.day);
    switch (entry.kind) {
      case ChronicleKind.chapterOpens:
        // A chapter heading, set on the dark like a page of its own.
        final chapter = entry.chapter;
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (chapter != null)
                Text(
                  chapter.label.toUpperCase(),
                  style: AppText.label.copyWith(color: Palette.goldBright),
                ),
              const SizedBox(height: 2),
              Text(
                chapter?.regionName ?? entry.title,
                style: AppText.display.copyWith(
                  color: Palette.onDark,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry.text,
                style: AppText.narrator.copyWith(color: Palette.onDark),
              ),
            ],
          ),
        );
      case ChronicleKind.arrival:
      case ChronicleKind.chapterWakes:
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  VIcon(
                    entry.icon ?? 'sun',
                    size: 16,
                    color: Palette.goldBright,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.title,
                      style: AppText.title.copyWith(color: Palette.onDark),
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: AppText.small.copyWith(color: Palette.onDarkSoft),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.text,
                style: AppText.narrator.copyWith(color: Palette.onDark),
              ),
            ],
          ),
        );
      case ChronicleKind.placeWakes:
      case ChronicleKind.lanterns:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ParchmentCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Roundel(
                  icon: entry.icon ?? 'lantern',
                  color: Palette.forest,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title,
                        style: AppText.cardTitle.copyWith(color: Palette.slate),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: AppText.small
                              .copyWith(color: Palette.goldDeep),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        entry.text,
                        style:
                            AppText.body.copyWith(color: Palette.slateSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
