import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../export/export_service.dart';
import '../../rules/companion_rules.dart';
import '../../rules/day_key.dart';
import '../../rules/encounter.dart' show withArticle;
import '../../rules/journey.dart';
import '../../rules/world.dart';
import '../../rules/xp_curve.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../motion.dart';
import '../art/crests.dart';
import '../art/painted.dart';
import '../board/board_screen.dart' show VillagerCard;
import '../celebrations.dart';
import '../encounter/class_choice.dart';
import '../encounter/encounter_screen.dart';
import '../tour/tours.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// Opens the Campfire over whatever screen is showing.
Future<void> openCampfire(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    RiseRoute<void>(builder: (_) => const CampfireScreen()),
  );
}

/// Campfire / Day Review (DESIGN §4.1 step 4, §8.6): what was completed, XP
/// gained, level progress, the world's change, and one optional note. Closing
/// the day here triggers the Markdown export.
///
/// User-triggered and never timed. It can be opened as often as wanted; the
/// day closes once and the note can be changed afterwards.
class CampfireScreen extends StatefulWidget {
  const CampfireScreen({super.key});

  @override
  State<CampfireScreen> createState() => _CampfireScreenState();
}

class _CampfireScreenState extends State<CampfireScreen> {
  final TextEditingController _note = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  bool _noteSaved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _note.text = GameScope.read(context).dayNote;
      _loaded = true;
      // The first time the Campfire is opened, say what it is.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showHintOnce(context, HintId.campfire);
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    final game = GameScope.read(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final outcome = await game.closeDay(note: _note.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome != null && navigator.mounted) {
      await celebrate(navigator.context, outcome);
    }
  }

  Future<void> _saveNote() async {
    if (_busy) return;
    setState(() => _busy = true);
    await GameScope.read(context).saveDayNote(_note.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _noteSaved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    if (game.hero == null || game.companion == null) {
      return const Scaffold(backgroundColor: Palette.forestNight);
    }
    final done = game.campfireDone;
    final expanded = isExpanded(context);

    final review = <Widget>[
      const _TodayCard(),
      const SizedBox(height: 12),
      const _WorldCard(),
      if (game.campfireLine != null) ...<Widget>[
        const SizedBox(height: 12),
        VillagerCard(greeting: game.campfireLine!),
      ],
      const SizedBox(height: 12),
      ParchmentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'A NOTE FOR TODAY',
              style: AppText.label.copyWith(color: Palette.goldDeep),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_noteSaved) setState(() => _noteSaved = false);
              },
              style: AppText.body.copyWith(color: Palette.slate),
              decoration: const InputDecoration(
                hintText: 'Anything worth keeping, if you like.',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Optional. Saved exactly as written, in today’s vault note.',
              style: AppText.small.copyWith(color: Palette.slateSoft),
            ),
          ],
        ),
      ),
      if (game.delve != null) ...<Widget>[
        const SizedBox(height: 12),
        _DelveCard(open: done),
      ],
      if (game.respecOpen) ...<Widget>[
        const SizedBox(height: 12),
        const _RespecCard(),
      ],
      const SizedBox(height: 12),
      const _ExportLine(),
      const SizedBox(height: 16),
      if (!done)
        PrimaryButton(
          label: 'Close the day',
          icon: 'campfire',
          color: Palette.moss,
          onPressed: _busy ? null : _close,
        )
      else ...<Widget>[
        Text(
          'The day is closed. Rest well.',
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(color: Palette.onDark),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            QuietButton(
              label: _noteSaved ? 'Note saved' : 'Save note',
              icon: 'pen',
              color: Palette.onDark,
              onPressed: _busy ? null : _saveNote,
            ),
            PrimaryButton(
              label: 'Back to the board',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: Palette.forestNight,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Palette.skyDeep, Palette.forestDeep, Palette.forestNight],
            stops: <double>[0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: expanded
              ? TwoPane(
                  start: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 0, 24),
                    children: const <Widget>[_Back(), SizedBox(height: 8), CampScene()],
                  ),
                  end: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 24),
                    children: review,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                  children: <Widget>[
                    const _Back(),
                    const SizedBox(height: 8),
                    const CampScene(),
                    const SizedBox(height: 14),
                    ...review,
                  ],
                ),
        ),
      ),
    );
  }
}

/// The week's Delve, waiting at the Campfire. It opens once the day is
/// closed, so the whole day counts toward it.
class _DelveCard extends StatelessWidget {
  const _DelveCard({required this.open});

  /// The day is closed, so the Delve can be entered.
  final bool open;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final delve = game.delve;
    if (delve == null) return const SizedBox.shrink();
    final state = game.bossState;
    final boss = state.boss;
    final met = state.hpLeft != null;
    return ParchmentCard(
      edge: Palette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'THE WEEKLY DELVE',
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 6),
          Text(
            boss.name,
            style: AppText.cardTitle.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 4),
          Text(
            open
                ? '${met ? 'It is still worn down from last time. ' : ''}'
                    'Seven turns to wear it down further. Boss Marks in '
                    'hand: ${state.marks}.'
                : 'It opens when you close the day, so all of today’s '
                    'quests count toward your strength.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          if (open) ...<Widget>[
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Enter the Delve',
              icon: 'cave',
              color: Palette.moss,
              onPressed: () => openBoss(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// On the Delve's day the fire is where a class can be changed, for
/// nothing (Amendment v0.3 §2).
class _RespecCard extends StatelessWidget {
  const _RespecCard();

  @override
  Widget build(BuildContext context) {
    final cls = GameScope.of(context).heroClass;
    if (cls == null) return const SizedBox.shrink();
    return ParchmentCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'YOUR CLASS',
                  style: AppText.label.copyWith(color: Palette.goldDeep),
                ),
                const SizedBox(height: 4),
                Text(
                  'You are ${withArticle(cls.label)}. Tonight you may take up another '
                  'for nothing. Everything you have earned stays.',
                  style: AppText.small.copyWith(color: Palette.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          QuietButton(
            label: 'Change',
            onPressed: () => showClassChoice(context),
          ),
        ],
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RoundIconButton(
        icon: 'close',
        semanticLabel: 'Back to the board',
        size: 40,
        background: Palette.forestNight.withValues(alpha: 0.5),
        foreground: Palette.onDark,
        edge: Palette.onDark.withValues(alpha: 0.25),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Hero and companion at tonight's camp, placed by total Paces (§7A.4).
class CampScene extends StatelessWidget {
  const CampScene({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hero = game.hero!;
    final companion = game.companion!;
    final paces = game.world?.journeyPaces ?? 0;
    final region = regions[regionIndexForPaces(paces)].name;
    final oldFriends = companion.level >= oldFriendLevel;
    final String where;
    if (paces == 0) {
      where = 'Camped at the village gate, in $region.';
    } else if (paces >= roadPaces) {
      where = 'Camped at Old Lanternhall, $paces Paces along the road.';
    } else {
      where = 'Camped $paces ${paces == 1 ? 'Pace' : 'Paces'} along the '
          'road, in $region.';
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: ColoredBox(
        color: Palette.forestNight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The painted camp, with the two of them either side of its
            // fire.
            AspectRatio(
              aspectRatio: 1.6,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Cut evenly top and bottom: the lantern on its post
                  // hangs clear below the heading, and the whole fire
                  // shows.
                  const ArtPicture(
                    asset: campfireArt,
                    fallback: CustomPaint(painter: _CampPainter()),
                  ),
                  // Dark behind the heading, and where the picture meets
                  // the card beneath it.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Palette.forestNight.withValues(alpha: 0.72),
                          Palette.forestNight.withValues(alpha: 0.0),
                          Palette.forestNight.withValues(alpha: 0.0),
                          Palette.forestNight.withValues(alpha: 0.88),
                        ],
                        stops: const <double>[0.0, 0.42, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 16,
                    right: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'CAMPFIRE',
                          style:
                              AppText.label.copyWith(color: Palette.goldBright),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DayKey.friendly(game.day),
                            maxLines: 1,
                            style: AppText.display.copyWith(
                              color: Palette.onDark,
                              fontSize: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          _Camper(
                            portrait: HeroPortrait(
                              portraitId: hero.portraitId,
                              size: 72,
                              frame: game.frame,
                            ),
                            name: hero.name,
                          ),
                          // The fire burns here, in the picture.
                          const SizedBox(width: 104),
                          _Camper(
                            portrait: CompanionPortrait(
                              kind: companion.kind,
                              size: 72,
                              gearIcon: game.gearWorn?.icon,
                            ),
                            name: companion.name,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                children: <Widget>[
                  Text(
                    where,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: Palette.onDark),
                  ),
                  const SizedBox(height: 8),
                  // The narrator closes the day (DECISIONS D-76).
                  Text(
                    game.campfireStory,
                    textAlign: TextAlign.center,
                    style: AppText.narrator.copyWith(
                      color: Palette.onDark,
                      fontSize: 15.5,
                    ),
                  ),
                  if (oldFriends) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Old friends by now.',
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(color: Palette.onDarkSoft),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Camper extends StatelessWidget {
  const _Camper({required this.portrait, required this.name});

  final Widget portrait;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        portrait,
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardTitle.copyWith(color: Palette.onDark, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Night over the camp: stars, two dark ridges and the fire's glow. Painted
/// in code; it stands in if the painted camp cannot be shown.
class _CampPainter extends CustomPainter {
  const _CampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF14263C), Color(0xFF1F3F52), Color(0xFF173A32)],
          stops: <double>[0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    final random = math.Random(5);
    final star = Paint();
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h * 0.5;
      star.color = Palette.onDark.withValues(alpha: 0.25 + random.nextDouble() * 0.6);
      canvas.drawCircle(Offset(x, y), 0.5 + random.nextDouble() * 1.0, star);
    }
    Path ridge(double base, double amp, double phase) {
      final path = Path()..moveTo(0, h);
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        final y = base +
            amp * (0.6 * math.sin((t * 1.6 + phase) * math.pi * 2) +
                0.4 * math.sin((t * 3.7 + phase * 2) * math.pi * 2));
        path.lineTo(t * w, y * h);
      }
      return path
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(ridge(0.5, 0.05, 0.2), Paint()..color = const Color(0xFF1B4038));
    canvas.drawPath(ridge(0.62, 0.04, 0.7), Paint()..color = const Color(0xFF12322B));
    // The fire's glow, painted across the whole scene so it has no edge.
    final fire = Offset(w / 2, h * 0.62);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Palette.ember.withValues(alpha: 0.55),
            Palette.gold.withValues(alpha: 0.16),
            Palette.gold.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.4, 1.0],
        ).createShader(
          Rect.fromCircle(center: fire, radius: math.max(w, h) * 0.6),
        ),
    );
  }

  @override
  bool shouldRepaint(_CampPainter oldDelegate) => false;
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hero = game.hero!;
    final companion = game.companion!;
    final heroProgress = XpCurve.progress(hero.totalXp);
    final companionProgress = XpCurve.progress(companion.totalXp);
    final done = game.doneQuests;
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('TODAY', style: AppText.label.copyWith(color: Palette.goldDeep)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: <Widget>[
              _Figure('${game.questsDoneToday} of ${game.questsTotalToday}', 'Quests'),
              _Figure('+${game.heroXpToday}', 'Hero XP'),
              _Figure('+${game.companionXpToday}', '${companion.name} XP'),
              _Figure('+${game.pacesToday}', game.pacesToday == 1 ? 'Pace' : 'Paces'),
            ],
          ),
          const SizedBox(height: 14),
          _Progress(
            label: '${hero.name} · Level ${heroProgress.level}',
            progress: heroProgress,
            color: Palette.gold,
          ),
          const SizedBox(height: 10),
          _Progress(
            label: '${companion.name} · Level ${companionProgress.level}',
            progress: companionProgress,
            color: Palette.companion,
          ),
          const SizedBox(height: 12),
          if (done.isEmpty)
            Text(
              'A quiet day. The Vale waited, and it will be here tomorrow.',
              style: AppText.body.copyWith(color: Palette.slateSoft),
            )
          else
            for (final entry in done)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    VIcon(
                      entry.quest.track.travelsWithCompanion ? 'paw' : 'check',
                      size: 15,
                      color: entry.quest.track.travelsWithCompanion
                          ? Palette.companion
                          : Palette.moss,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.quest.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: Palette.slate,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTimeOfDay(entry.completion!.completedAt),
                      style: AppText.small.copyWith(
                        color: Palette.slateSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(value, style: AppText.number.copyWith(color: Palette.slate)),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.small.copyWith(color: Palette.slateSoft, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.label,
    required this.progress,
    required this.color,
  });

  final String label;
  final LevelProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final detail = progress.xpForLevel == 0
        ? 'Top level'
        : '${progress.xpRemaining} XP to the next level';
    return Semantics(
      label: '$label, $detail',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(
                      color: Palette.slate,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Text(
                  detail,
                  style: AppText.small.copyWith(
                    color: Palette.slateSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            XpBar(
              fraction: progress.fraction,
              color: color,
              height: 8,
              track: color.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}

/// What changed in the world today.
class _WorldCard extends StatelessWidget {
  const _WorldCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final restoredToday = <int>[
      for (final e in game.restoredOn.entries)
        if (e.value == game.day) targetIndexByKey(e.key),
    ]..sort();
    final total = game.world?.journeyPaces ?? 0;
    final found = newDiscoveries(total - game.pacesToday, total);
    final target = game.target;
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('THE VALE', style: AppText.label.copyWith(color: Palette.goldDeep)),
          const SizedBox(height: 8),
          if (restoredToday.isEmpty)
            Text(
              'The Vale rests. ${target.name} is '
              '${(targetProgress(game.materials) * 100).round()}% of the way '
              'there.',
              style: AppText.body.copyWith(color: Palette.slate),
            )
          else
            for (final i in restoredToday)
              if (i >= 0)
                _WorldRow(
                  icon: 'sun',
                  color: Palette.goldDeep,
                  text: 'Restored: ${targetAt(i).name}, in '
                      '${regionByKey(targetAt(i).region).name}.',
                ),
          for (final i in found)
            _WorldRow(
              icon: 'lantern',
              color: Palette.companionDeep,
              text: 'Discovered: ${sceneFor(i).title}.',
            ),
          if (game.encounterToday != null)
            _WorldRow(
              icon: 'still',
              color: Palette.slateSoft,
              text: game.encounterToday!.won
                  ? 'Woke: the ${game.enemyToday.name}.'
                  : 'The ${game.enemyToday.name} held the road today.',
            ),
        ],
      ),
    );
  }
}

class _WorldRow extends StatelessWidget {
  const _WorldRow({required this.icon, required this.color, required this.text});

  final String icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VIcon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: Palette.slate, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Export status (DESIGN §8.6, §11). Calm in every state; never an error.
class _ExportLine extends StatelessWidget {
  const _ExportLine();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const VIcon('folder', size: 16, color: Palette.onDarkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            exportStatusLine(game.export),
            style: AppText.small.copyWith(color: Palette.onDarkSoft),
          ),
        ),
      ],
    );
  }
}

/// One line on where the Markdown export stands.
String exportStatusLine(ExportService export) {
  switch (export.state) {
    case ExportState.noFolder:
      return 'No vault folder chosen yet. Pick one in Settings and each '
          'day will be written there.';
    case ExportState.waiting:
      return 'Export waiting for vault folder';
    case ExportState.upToDate:
      final name = export.vaultStatus.name;
      final at = export.lastExportAt;
      final where = name == null ? 'the vault folder' : '“$name”';
      return at == null
          ? 'Writing to $where.'
          : 'Exported to $where at ${formatTimeOfDay(at)}.';
  }
}
