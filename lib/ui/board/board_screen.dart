import 'package:flutter/material.dart';

import '../../data/repository.dart';
import '../../rules/day_key.dart';
import '../../rules/enums.dart';
import '../../rules/journey.dart';
import '../../rules/xp_curve.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../art/crests.dart';
import '../art/vista.dart';
import '../log/quest_editor.dart';
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
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
          children: <Widget>[
            const DawnHeader(),
            if (now.isNotEmpty) ...<Widget>[
              SectionHeader('Now', icon: 'sun', count: now.length),
              for (final entry in now) ...<Widget>[
                QuestCard(entry: entry),
                const SizedBox(height: 10),
              ],
            ] else
              const _QuietLine(
                'Nothing waiting for you right now. The day is yours.',
              ),
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
            if (campfire != null && !campfire.isDone) ...<Widget>[
              const SectionHeader('Day’s end', icon: 'campfire'),
              QuestCard(entry: campfire),
            ],
            if (done.isNotEmpty) ...<Widget>[
              SectionHeader('Done', icon: 'check', count: done.length),
              _DoneList(entries: done),
            ],
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: PrimaryButton(
            label: 'Quest',
            icon: 'plus',
            onPressed: () => openQuestEditor(context),
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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'DAWN IN THE VALE',
                style: AppText.label.copyWith(color: Palette.goldBright),
              ),
              const SizedBox(height: 4),
              Text(
                DayKey.friendly(game.day),
                style: AppText.display.copyWith(
                  color: Palette.onDark,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${game.questsDoneToday} of ${game.questsTotalToday} quests '
                'done today',
                style: AppText.small.copyWith(color: Palette.onDarkSoft),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _PartyBadge(
                      portrait: HeroPortrait(
                        portraitId: hero.portraitId,
                        size: 44,
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
              const SizedBox(height: 10),
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
                    Text(
                      xpText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(
                        color: Palette.onDarkSoft,
                        fontSize: 11,
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

/// Slim world-progress + journey strip.
class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final paces = game.world?.journeyPaces ?? 0;
    final toNext = pacesToNextDiscovery(paces);
    return _Frost(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const VIcon('pace', size: 16, color: Palette.goldBright),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$paces ${paces == 1 ? 'Pace' : 'Paces'} on the road · '
                  '$toNext to the next discovery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: Palette.onDark,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          XpBar(
            fraction: pacesIntoStretch(paces) / pacesPerDiscovery,
            color: Palette.companion,
            height: 5,
            track: Palette.onDark.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: <Widget>[
              for (final m in MaterialKind.values)
                StatChip(
                  icon: materialIcon(m),
                  value: '${game.materials[m] ?? 0}',
                  label: m.label,
                  iconColor: Palette.sage,
                ),
              StatChip(
                icon: 'coin',
                value: '${game.hero?.gold ?? 0}',
                label: 'Gold',
                iconColor: Palette.goldBright,
              ),
            ],
          ),
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
              Row(
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
    final Widget action = switch (quest.completionType) {
      CompletionType.count => CountStepper(entry: entry),
      CompletionType.timer => TimerControl(entry: entry),
      _ => CompleteButton(
          label: 'Complete ${quest.name}',
          color: companionStyle ? Palette.companion : Palette.forest,
          onComplete: () => completeEntry(context, entry),
        ),
    };

    return ParchmentCard(
      tint: companionStyle ? Palette.companionTint : null,
      edge: companionStyle ? Palette.companionEdge : null,
      padding: EdgeInsets.fromLTRB(12, companionStyle ? 9 : 12, 10, companionStyle ? 9 : 12),
      onTap: () => showQuestSheet(context, quest.id),
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
                  rewardLabel(quest, game.companionName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: companionStyle ? Palette.companionDeep : Palette.goldDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
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
