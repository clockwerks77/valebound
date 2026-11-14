import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../data/repository.dart';
import '../../data/seed.dart';
import '../../device/device_port.dart';
import '../../export/markdown.dart' show thousands;
import '../../rules/daily_still.dart';
import '../../rules/day_cycle.dart';
import '../../rules/day_key.dart';
import '../../rules/enums.dart';
import '../../rules/journey.dart';
import '../../rules/still.dart';
import '../../rules/world.dart';
import '../../rules/xp_curve.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../art/crests.dart';
import '../art/vista.dart';
import '../campfire/campfire_screen.dart';
import '../health/health_log_screen.dart';
import '../log/quest_editor.dart';
import '../settings/settings_screen.dart';
import '../tour/tour.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'quest_actions.dart';
import 'quest_sheet.dart';

/// Dawn / Quest Board: the home screen (DESIGN §8.1).
///
/// Today's quests grouped Now / Later / Done, plus the "With [Companion]"
/// section, the hero and companion XP bars and a slim journey strip.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    if (game.hero == null || game.companion == null) {
      return const SizedBox.shrink();
    }
    final now = game.nowQuests;
    final later = game.laterQuests;
    final done = game.doneQuests;
    final campfire = game.campfireQuest;

    return Stack(
      children: <Widget>[
        ListView(
          controller: TourMark.boardScroll,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
          children: <Widget>[
            const DawnHeader(),
            const _VillagerLine(),
            const _ComebackCard(),
            const _Suggestions(),
            if (now.isNotEmpty) ...<Widget>[
              SectionHeader('Now', icon: 'sun', count: now.length),
              for (var i = 0; i < now.length; i++) ...<Widget>[
                // The tour points at the first quest on the board.
                if (i == 0)
                  KeyedSubtree(
                    key: TourMark.quest,
                    child: QuestCard(entry: now[i]),
                  )
                else
                  QuestCard(entry: now[i]),
                const SizedBox(height: 10),
              ],
            ] else
              const _QuietLine(
                'Nothing waiting for you right now. The day is yours.',
              ),
            const _CalendarOffer(),
            const _CompanionSection(),
            if (later.isNotEmpty) ...<Widget>[
              SectionHeader('Later', icon: 'later', count: later.length),
              for (final entry in later) ...<Widget>[
                QuestCard(
                  entry: entry,
                  companionStyle: entry.quest.track.travelsWithCompanion,
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (campfire != null) ...<Widget>[
              const SectionHeader('Day’s end', icon: 'campfire'),
              KeyedSubtree(
                key: TourMark.campfire,
                child: campfire.isDone
                    ? const _CampfireLit()
                    : QuestCard(entry: campfire),
              ),
            ],
            if (done.isNotEmpty) ...<Widget>[
              SectionHeader('Done', icon: 'check', count: done.length),
              _DoneList(entries: done),
            ],
          ],
        ),
        // Centred, so it never covers the completion controls on the right
        // of a card, and reachable with either thumb.
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Center(
            child: KeyedSubtree(
              key: TourMark.newQuest,
              child: PrimaryButton(
                label: 'Quest',
                icon: 'plus',
                onPressed: () => openQuestEditor(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 4),
      child: Text(
        text,
        style: AppText.body.copyWith(color: Palette.onDarkSoft),
      ),
    );
  }
}

/// The painted header: date, hero and companion levels with XP bars, and the
/// slim world-progress and journey strip.
class DawnHeader extends StatelessWidget {
  const DawnHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hero = game.hero!;
    final companion = game.companion!;
    final heroProgress = XpCurve.progress(hero.totalXp);
    final companionProgress = XpCurve.progress(companion.totalXp);

    return Vista(
      radius: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Palette.forestNight.withValues(alpha: 0.55),
              Palette.forestNight.withValues(alpha: 0.05),
              Palette.forestNight.withValues(alpha: 0.5),
            ],
            stops: const <double>[0.0, 0.42, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // Narrow beside the Map on the opened Fold: the line
                  // shrinks a little to fit, it is never cut short.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'DAWN IN THE VALE · ${game.questsDoneToday} OF '
                        '${game.questsTotalToday} DONE',
                        maxLines: 1,
                        style:
                            AppText.label.copyWith(color: Palette.goldBright),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  KeyedSubtree(
                    key: TourMark.tools,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        RoundIconButton(
                          icon: 'sprig',
                          semanticLabel: 'Health Log',
                          size: 34,
                          background:
                              Palette.forestNight.withValues(alpha: 0.55),
                          foreground: Palette.onDark,
                          edge: Palette.onDark.withValues(alpha: 0.25),
                          onPressed: () => openHealthLog(context),
                        ),
                        const SizedBox(width: 8),
                        RoundIconButton(
                          icon: 'settings',
                          semanticLabel: 'Settings',
                          size: 34,
                          background:
                              Palette.forestNight.withValues(alpha: 0.55),
                          foreground: Palette.onDark,
                          edge: Palette.onDark.withValues(alpha: 0.25),
                          onPressed: () => openSettings(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  DayKey.friendly(game.day),
                  maxLines: 1,
                  style: AppText.display.copyWith(
                    color: Palette.onDark,
                    fontSize: 25,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: TourMark.party,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _PartyBadge(
                        portrait: HeroPortrait(
                          portraitId: hero.portraitId,
                          size: 44,
                          frame: game.frame,
                        ),
                        name: hero.name,
                        level: heroProgress.level,
                        progress: heroProgress,
                        barColor: Palette.gold,
                        semanticRole: 'Hero',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PartyBadge(
                        portrait: CompanionPortrait(
                          kind: companion.kind,
                          size: 44,
                          gearIcon: game.gearWorn?.icon,
                        ),
                        name: companion.name,
                        level: companionProgress.level,
                        progress: companionProgress,
                        barColor: Palette.companion,
                        semanticRole: 'Companion',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const _JourneyStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Frost extends StatelessWidget {
  const _Frost({required this.child, this.padding = const EdgeInsets.all(10)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.forestNight.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.onDark.withValues(alpha: 0.14)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PartyBadge extends StatelessWidget {
  const _PartyBadge({
    required this.portrait,
    required this.name,
    required this.level,
    required this.progress,
    required this.barColor,
    required this.semanticRole,
  });

  final Widget portrait;
  final String name;
  final int level;
  final LevelProgress progress;
  final Color barColor;
  final String semanticRole;

  @override
  Widget build(BuildContext context) {
    final xpText = progress.xpForLevel == 0
        ? 'Top level'
        : '${progress.xpIntoLevel} / ${progress.xpForLevel} XP';
    return Semantics(
      container: true,
      label: '$semanticRole $name, level $level, $xpText',
      child: ExcludeSemantics(
        child: _Frost(
          child: Row(
            children: <Widget>[
              portrait,
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(
                        color: Palette.onDark,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Level $level',
                      style: AppText.small.copyWith(
                        color: Palette.onDarkSoft,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    XpBar(
                      fraction: progress.fraction,
                      color: barColor,
                      height: 7,
                      track: Palette.onDark.withValues(alpha: 0.16),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        xpText,
                        maxLines: 1,
                        style: AppText.small.copyWith(
                          color: Palette.onDarkSoft,
                          fontSize: 11,
                        ),
                      ),
                    ),
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

/// Slim world-progress + journey strip (DESIGN §8.1): what is being restored
/// and how far along it is, then the road.
class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final paces = game.world?.journeyPaces ?? 0;
    final toNext = pacesToNextDiscovery(paces);
    final target = game.target;
    final progress = targetProgress(game.materials);
    final still = game.dailyStillToday;
    return Semantics(
      label: 'Restoring ${target.name}, ${(progress * 100).round()} percent. '
          '$paces Paces on the road, $toNext to the next discovery'
          '${still == null ? '' : '. ${_dailyStillSpoken(still, target.name)}'}',
      child: ExcludeSemantics(
        child: _Frost(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              KeyedSubtree(
                key: TourMark.restoring,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const VIcon('home', size: 15, color: Palette.goldBright),
                        const SizedBox(width: 7),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Restoring ${target.name}',
                              maxLines: 1,
                              style: AppText.small.copyWith(
                                color: Palette.onDark,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatChip(
                          icon: 'coin',
                          value: '${game.hero?.gold ?? 0}',
                          label: 'Gold',
                          iconColor: Palette.goldBright,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    XpBar(
                      fraction: progress,
                      color: Palette.gold,
                      height: 5,
                      track: Palette.onDark.withValues(alpha: 0.16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: TourMark.road,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const VIcon('pace', size: 15, color: Palette.dawnPeach),
                        const SizedBox(width: 7),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$paces ${paces == 1 ? 'Pace' : 'Paces'} · $toNext to '
                              'the next discovery',
                              maxLines: 1,
                              style: AppText.small.copyWith(
                                color: Palette.onDark,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    XpBar(
                      fraction: pacesIntoStretch(paces) / pacesPerDiscovery,
                      color: Palette.companion,
                      height: 5,
                      track: Palette.onDark.withValues(alpha: 0.16),
                    ),
                  ],
                ),
              ),
              if (still != null) ...<Widget>[
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: TourMark.sleeper,
                  child: _DailyStillRow(today: still, place: target.name),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the day's Still creature is doing, in a line.
String _dailyStillLine(DailyStillToday today, String place) {
  final name = today.still.creature.name;
  if (!today.still.awake) return 'A $name dozes by $place';
  final gift = today.gift;
  return gift == null
      ? 'The $name woke and wandered off'
      : 'The $name woke: +$dailyStillGold gold, '
          '+$dailyStillMaterials ${gift.label}';
}

String _dailyStillSpoken(DailyStillToday today, String place) =>
    today.still.awake
        ? '${_dailyStillLine(today, place)}.'
        : '${_dailyStillLine(today, place)}. ${today.still.stirs} of '
            '$dailyStillStirs quests have stirred it.';

/// The day's Still creature (DECISIONS D-70): where it dozes, a pip for each
/// quest that has stirred it, and what it left once it has woken.
class _DailyStillRow extends StatelessWidget {
  const _DailyStillRow({required this.today, required this.place});

  final DailyStillToday today;
  final String place;

  @override
  Widget build(BuildContext context) {
    final awake = today.still.awake;
    return Row(
      children: <Widget>[
        VIcon(
          awake ? 'sun' : 'still',
          size: 15,
          color: awake ? Palette.goldBright : Palette.onDarkSoft,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _dailyStillLine(today, place),
              maxLines: 1,
              style: AppText.small.copyWith(
                color: Palette.onDark,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < dailyStillStirs; i++)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: _StirPip(lit: awake || i < today.still.stirs),
          ),
      ],
    );
  }
}

class _StirPip extends StatelessWidget {
  const _StirPip({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? Palette.goldBright : Colors.transparent,
        border: Border.all(
          color: lit
              ? Palette.goldBright
              : Palette.onDark.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
    );
  }
}

/// A villager who has come home says good morning (DESIGN §7). Presentation
/// only: a portrait and one line.
class _VillagerLine extends StatelessWidget {
  const _VillagerLine();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final greeting = game.dawnLine;
    if (greeting == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: VillagerCard(greeting: greeting),
    );
  }
}

/// A villager's portrait and one line, on the dark background.
class VillagerCard extends StatelessWidget {
  const VillagerCard({super.key, required this.greeting});

  final VillagerLine greeting;

  @override
  Widget build(BuildContext context) {
    final v = greeting.villager;
    return Semantics(
      label: '${v.name}, ${v.role}, says: ${greeting.line}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.forestNight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Palette.gold.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            child: Row(
              children: <Widget>[
                Roundel(icon: v.icon, color: Palette.moss, size: 40),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${v.name.toUpperCase()} · ${v.role.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(
                          color: Palette.goldBright,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '“${greeting.line}”',
                        style: AppText.body.copyWith(
                          color: Palette.onDark,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// After the Campfire: a way back to the evening's review and note.
class _CampfireLit extends StatelessWidget {
  const _CampfireLit();

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      onTap: () => openCampfire(context),
      child: Row(
        children: <Widget>[
          const Roundel(icon: 'campfire', color: Palette.ember, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The campfire is lit',
                  style: AppText.cardTitle.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 2),
                Text(
                  'Read tonight’s review or change your note.',
                  style: AppText.small.copyWith(color: Palette.slateSoft),
                ),
              ],
            ),
          ),
          const VIcon('chevron', size: 18, color: Palette.slateSoft),
        ],
      ),
    );
  }
}

/// "With [Companion Name]": the companion's own warm section (DESIGN §7A.2).
class _CompanionSection extends StatelessWidget {
  const _CompanionSection();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final companion = game.companion!;
    final open = game.companionQuests;
    final anyToday = game.board.any(
      (b) => b.quest.track.travelsWithCompanion,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Palette.companion.withValues(alpha: 0.34),
              Palette.companionDeep.withValues(alpha: 0.22),
            ],
          ),
          border: Border.all(color: Palette.companion.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              KeyedSubtree(
                key: TourMark.companion,
                child: Row(
                  children: <Widget>[
                    CompanionPortrait(kind: companion.kind, size: 46),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'With ${companion.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title.copyWith(color: Palette.onDark),
                          ),
                          Text(
                            'Small, kind goals for the road',
                            style: AppText.small.copyWith(
                              color: Palette.onDarkSoft,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatChip(
                      icon: 'bond',
                      value: '${companion.bond}',
                      label: 'Bond',
                      iconColor: Palette.dawnPeach,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (open.isNotEmpty)
                for (var i = 0; i < open.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  QuestCard(entry: open[i], companionStyle: true),
                ]
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    anyToday
                        ? '${companion.name} is content. Every small goal for '
                            'today is done.'
                        : 'No small goals today. Add one any time and '
                            '${companion.name} will carry it.',
                    style: AppText.body.copyWith(color: Palette.onDark),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One quest on the board.
class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.entry, this.companionStyle = false});

  final BoardQuest entry;

  /// Companion cards are a little smaller and carry the companion accent,
  /// but are never visually lesser.
  final bool companionStyle;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.read(context);
    final quest = entry.quest;
    final color = Palette.attribute(quest.attribute);
    final isCampfire = quest.systemKey == systemKeyCampfire;
    final still = drawsStill(quest.difficulty) ? stillFor(quest.id) : null;
    final pending = game.isPending(quest.id);
    final Widget action;
    if (pending) {
      action = UndoButton(
        questName: quest.name,
        onUndo: () => game.undo(quest.id),
      );
    } else if (isCampfire) {
      // The Campfire is a screen of its own: review, note, then close.
      action = RoundIconButton(
        icon: 'campfire',
        semanticLabel: 'Open the Campfire',
        size: 48,
        onPressed: () => openCampfire(context),
      );
    } else {
      action = switch (quest.completionType) {
        CompletionType.count => CountStepper(entry: entry),
        CompletionType.timer => TimerControl(entry: entry),
        _ => CompleteButton(
            label: 'Complete ${quest.name}',
            color: companionStyle ? Palette.companion : Palette.forest,
            onComplete: () => completeFromBoard(context, entry),
          ),
      };
    }

    return ParchmentCard(
      tint: companionStyle ? Palette.companionTint : null,
      edge: companionStyle ? Palette.companionEdge : null,
      padding: EdgeInsets.fromLTRB(12, companionStyle ? 9 : 12, 10, companionStyle ? 9 : 12),
      onTap: () => isCampfire
          ? openCampfire(context)
          : showQuestSheet(context, quest.id),
      child: Row(
        children: <Widget>[
          Roundel(
            icon: quest.iconKey,
            color: color,
            size: companionStyle ? 38 : 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quest.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    color: Palette.slate,
                    fontSize: companionStyle ? 15 : 16,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    if (companionStyle) ...<Widget>[
                      const VIcon('paw', size: 12, color: Palette.companion),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        '${quest.attribute.label} · ${quest.difficulty.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small.copyWith(
                          color: Palette.slateSoft,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  pending
                      ? 'Done. Undo if that was a slip.'
                      : rewardLabel(quest, game.companionName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: companionStyle ? Palette.companionDeep : Palette.goldDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                if (!pending && _detailLine(entry) != null)
                  Text(
                    _detailLine(entry)!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(
                      color: Palette.slateSoft,
                      fontSize: 12,
                    ),
                  ),
                if (still != null && !pending) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const VIcon('still', size: 14, color: Palette.slateSoft),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          still.sits,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(
                            color: Palette.slateSoft,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

/// One more quiet line for quests that have something to say: steps so
/// far, or the time of a calendar commitment.
String? _detailLine(BoardQuest entry) {
  final quest = entry.quest;
  if (quest.completionType == CompletionType.auto && entry.banked > 0) {
    final target = quest.target ?? 0;
    return target > 0
        ? '${thousands(entry.banked)} of ${thousands(target)} steps so far'
        : '${thousands(entry.banked)} steps so far';
  }
  if (quest.source == QuestSource.calendar && quest.notes.isNotEmpty) {
    return quest.notes;
  }
  return null;
}

/// "Return to the Vale" (DESIGN §4.3): the single welcome after time away.
/// Once the companion knows Comfort, they are the one who offers it.
class _ComebackCard extends StatelessWidget {
  const _ComebackCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final entry = game.comebackQuest;
    final companion = game.companion;
    if (entry == null || companion == null) return const SizedBox.shrink();
    final comfort = game.comfortKnown;
    final pending = game.isPending(entry.quest.id);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ParchmentCard(
        tint: comfort ? Palette.companionTint : null,
        edge: comfort ? Palette.companionEdge : Palette.gold,
        child: Row(
          children: <Widget>[
            if (comfort)
              CompanionPortrait(kind: companion.kind, size: 46)
            else
              const Roundel(icon: 'lantern', color: Palette.goldDeep, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    comebackQuestName,
                    style: AppText.cardTitle.copyWith(color: Palette.slate),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comfort
                        ? '${companion.name} kept the camp warm. Welcome back.'
                        : 'Welcome back. The Vale waited, just as you left it.',
                    style: AppText.small.copyWith(color: Palette.slateSoft),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pending
                        ? 'Done. Undo if that was a slip.'
                        : comfort
                            ? '${rewardLabel(entry.quest, companion.name)} · '
                                '+$comfortBonusBond Bond'
                            : rewardLabel(entry.quest, companion.name),
                    style: AppText.small.copyWith(
                      color: comfort ? Palette.companionDeep : Palette.goldDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (pending)
              UndoButton(
                questName: entry.quest.name,
                onUndo: () => game.undo(entry.quest.id),
              )
            else
              CompleteButton(
                label: 'Complete ${entry.quest.name}',
                color: comfort ? Palette.companion : Palette.forest,
                onComplete: () => completeEntry(context, entry),
              ),
          ],
        ),
      ),
    );
  }
}

/// The offer to connect the calendar (DESIGN §9.3): made once, in context,
/// on the Dawn board. Never at first launch, and never again once answered.
class _CalendarOffer extends StatelessWidget {
  const _CalendarOffer();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    if (!game.calendarOfferDue) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ParchmentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const VIcon('calendar', size: 19, color: Palette.goldDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Today’s calendar, as quests?',
                    style: AppText.cardTitle.copyWith(color: Palette.slate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$appName can offer today’s calendar events here as '
              'suggested quests. It only reads your calendar and never '
              'changes it, and nothing is accepted for you.',
              style: AppText.small.copyWith(color: Palette.slateSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                PrimaryButton(
                  label: 'Connect calendar',
                  icon: 'calendar',
                  onPressed: () => game.connectCalendar(),
                ),
                QuietButton(
                  label: 'Not now',
                  onPressed: () => game.declineCalendar(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's calendar events as suggested quests to accept or dismiss
/// (DESIGN §9.3). Nothing is ever accepted or completed for the user.
class _Suggestions extends StatelessWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final suggestions = game.suggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          'From your calendar',
          icon: 'calendar',
          count: suggestions.length,
        ),
        for (final event in suggestions) ...<Widget>[
          _SuggestionCard(event: event),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.read(context);
    final title = event.title.trim().isEmpty
        ? commitmentFallbackName
        : event.title.trim();
    // An event that repeats a quest already on the board says so, and
    // Dismiss becomes the main button. Both choices stay.
    final match = game.boardQuestMatching(event);
    void accept() => game.acceptSuggestion(event);
    void dismiss() => game.dismissSuggestion(event);
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Roundel(
                icon: 'calendar',
                color: Palette.attribute(Attribute.order),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle.copyWith(color: Palette.slate),
                    ),
                    Text(
                      '${event.timeLabel} · suggested',
                      style: AppText.small.copyWith(
                        color: Palette.slateSoft,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (match != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Looks like “$match”, which is already on today’s board.',
              style: AppText.small.copyWith(
                color: Palette.slateSoft,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (match == null) ...<Widget>[
                PrimaryButton(label: 'Accept', icon: 'plus', onPressed: accept),
                QuietButton(label: 'Dismiss', onPressed: dismiss),
              ] else ...<Widget>[
                QuietButton(label: 'Accept', icon: 'plus', onPressed: accept),
                PrimaryButton(label: 'Dismiss', onPressed: dismiss),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneList extends StatelessWidget {
  const _DoneList({required this.entries});

  final List<BoardQuest> entries;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.read(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.forestNight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.onDark.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: <Widget>[
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: <Widget>[
                    VIcon(
                      entry.quest.track.travelsWithCompanion ? 'paw' : 'check',
                      size: 16,
                      color: entry.quest.track.travelsWithCompanion
                          ? Palette.dawnPeach
                          : Palette.goldBright,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.quest.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: Palette.onDark,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _earned(entry, game.companionName),
                      style: AppText.small.copyWith(
                        color: Palette.onDarkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _earned(BoardQuest entry, String companionName) {
    final c = entry.completion!;
    final parts = <String>[
      formatTimeOfDay(c.completedAt),
      if (c.xpAwarded > 0) '+${c.xpAwarded} XP',
      if (c.companionXpAwarded > 0) '$companionName +${c.companionXpAwarded}',
    ];
    return parts.join(' · ');
  }
}
