import 'package:flutter/material.dart';

import '../../rules/companion_rules.dart';
import '../../rules/enums.dart';
import '../../rules/gear.dart';
import '../../rules/journey.dart';
import '../../rules/xp_curve.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../art/crests.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'inventory.dart';

/// Party Sheet (DESIGN §8.3): hero and companion as a pair, with the
/// Inventory (§8.4) one tap away.
///
/// Cover screen: stacked cards. Opened Fold: hero on one pane, companion on
/// the other, the showcase for the two-pane layout. The Inventory splits the
/// same way: the hero's things on one pane, the companion's on the other.
class PartySheetScreen extends StatefulWidget {
  const PartySheetScreen({super.key, this.leadingInset = 0});

  final double leadingInset;

  @override
  State<PartySheetScreen> createState() => _PartySheetScreenState();
}

class _PartySheetScreenState extends State<PartySheetScreen> {
  bool _inventory = false;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    if (game.hero == null || game.companion == null) {
      return const SizedBox.shrink();
    }
    final toggle = Row(
      children: <Widget>[
        _SheetTab(
          label: 'Party',
          icon: 'party',
          selected: !_inventory,
          onTap: () => setState(() => _inventory = false),
        ),
        const SizedBox(width: 8),
        _SheetTab(
          label: 'Inventory',
          icon: 'bag',
          selected: _inventory,
          onTap: () => setState(() => _inventory = true),
        ),
      ],
    );
    final Widget first = _inventory ? const HeroInventory() : const HeroPane();
    final Widget second =
        _inventory ? const CompanionInventory() : const CompanionPane();
    if (isExpanded(context)) {
      return TwoPane(
        leadingInset: widget.leadingInset,
        start: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 0, 24),
          children: <Widget>[toggle, const SizedBox(height: 12), first],
        ),
        end: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 14, 24),
          // Level with the card on the other pane.
          children: <Widget>[const SizedBox(height: 56), second],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: <Widget>[
        toggle,
        const SizedBox(height: 12),
        first,
        const SizedBox(height: 16),
        second,
      ],
    );
  }
}

/// Party | Inventory, on the dark background: gold when chosen.
class _SheetTab extends StatelessWidget {
  const _SheetTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.goldBright : Palette.onDarkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? Palette.gold.withValues(alpha: 0.22)
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? Palette.gold
                : Palette.onDark.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  VIcon(icon, size: 18, color: color),
                  const SizedBox(width: 7),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: AppText.small.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaneHeading extends StatelessWidget {
  const PaneHeading(this.text, {super.key, this.color = Palette.slateSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(text.toUpperCase(), style: AppText.label.copyWith(color: color)),
    );
  }
}

class HeroPane extends StatelessWidget {
  const HeroPane({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hero = game.hero!;
    final companion = game.companion!;
    final progress = XpCurve.progress(hero.totalXp);
    final title = titleForLevel(progress.level);

    return ParchmentCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              HeroPortrait(
                portraitId: hero.portraitId,
                size: 84,
                frame: game.frame,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        VIcon('banner', size: 15, color: bannerColor(game.banner)),
                        const SizedBox(width: 5),
                        Text(
                          'HERO',
                          style: AppText.label.copyWith(color: Palette.goldDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hero.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display.copyWith(
                        color: Palette.slate,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      title,
                      style: AppText.small.copyWith(
                        color: Palette.slateSoft,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LevelRow(
            label: 'Level ${progress.level}',
            progress: progress,
            color: Palette.gold,
          ),
          const PaneHeading('Attributes'),
          for (final a in Attribute.values)
            _AttributeRow(
              attribute: a,
              xp: game.attributeXp[a] ?? 0,
              starred: companion.kind.affinity == a,
              companionName: companion.name,
            ),
          const PaneHeading('Totals'),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = ((constraints.maxWidth - 20) / 3).floorToDouble();
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _Tile(
                    width: width,
                    icon: 'check',
                    value: '${game.completionCount}',
                    label: 'Quests done',
                  ),
                  _Tile(
                    width: width,
                    icon: 'star',
                    value: '${hero.totalXp}',
                    label: 'Total XP',
                  ),
                  _Tile(
                    width: width,
                    icon: 'coin',
                    value: '${hero.gold}',
                    label: 'Gold',
                  ),
                  for (final m in MaterialKind.values)
                    _Tile(
                      width: width,
                      icon: materialIcon(m),
                      value: '${game.stores[m] ?? 0}',
                      label: m.label,
                    ),
                ],
              );
            },
          ),
          const PaneHeading('Titles earned'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final t in game.titles.isEmpty ? <String>[title] : game.titles)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: t == title
                        ? Palette.gold.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: t == title ? Palette.goldDeep : Palette.parchmentEdge,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(
                      t,
                      style: AppText.small.copyWith(
                        color: Palette.slate,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CompanionPane extends StatelessWidget {
  const CompanionPane({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final companion = game.companion!;
    final progress = XpCurve.progress(companion.totalXp);
    final paces = game.world?.journeyPaces ?? 0;
    final nextMilestone = nextBondMilestone(companion.bond);
    final previous = previousBondMilestone(companion.bond);
    final bondFraction = nextMilestone == null
        ? 1.0
        : (companion.bond - previous) / (nextMilestone - previous);

    return ParchmentCard(
      radius: 24,
      tint: Palette.companionTint,
      edge: Palette.companionEdge,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CompanionPortrait(
                kind: companion.kind,
                size: 84,
                gearIcon: game.gearWorn?.icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'COMPANION · ${companion.kind.label.toUpperCase()}',
                      style: AppText.label.copyWith(color: Palette.companionDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display.copyWith(
                        color: Palette.slate,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      companion.kind.temperament,
                      style: AppText.small.copyWith(
                        color: Palette.slateSoft,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LevelRow(
            label: 'Level ${progress.level}',
            progress: progress,
            color: Palette.companion,
            unit: 'Companion XP',
          ),
          const SizedBox(height: 14),
          // Bond: a meter that only ever rises (DESIGN §7A.3).
          Row(
            children: <Widget>[
              const VIcon('bond', size: 20, color: Palette.companionDeep),
              const SizedBox(width: 8),
              Text(
                'Bond ${companion.bond}',
                style: AppText.cardTitle.copyWith(color: Palette.slate),
              ),
              const Spacer(),
              Text(
                nextMilestone == null
                    ? 'Every gift found'
                    : 'Next gift at $nextMilestone',
                style: AppText.small.copyWith(color: Palette.slateSoft),
              ),
            ],
          ),
          const SizedBox(height: 6),
          XpBar(
            fraction: bondFraction,
            color: Palette.companionDeep,
            track: Palette.companion.withValues(alpha: 0.18),
          ),
          const PaneHeading('Tricks', color: Palette.companionDeep),
          for (final trick in companionTricks)
            TrickRow(trick: trick, unlocked: progress.level >= trick.level),
          const PaneHeading('Gear', color: Palette.companionDeep),
          Text(
            _gearLine(game.gearWorn, game.gearUnlocked.length, companion.name),
            style: AppText.body.copyWith(color: Palette.slate, fontSize: 14),
          ),
          if (progress.level >= oldFriendLevel) ...<Widget>[
            const PaneHeading('Old friends', color: Palette.companionDeep),
            OldFriends(
              portraitId: game.hero!.portraitId,
              frame: game.frame,
              kind: companion.kind,
              caption: '${game.hero!.name} and ${companion.name}, '
                  '$paces Paces together.',
            ),
          ],
          const PaneHeading('The road together', color: Palette.companionDeep),
          Row(
            children: <Widget>[
              const VIcon('pace', size: 18, color: Palette.companionDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$paces ${paces == 1 ? 'Pace' : 'Paces'} walked · '
                  '${pacesToNextDiscovery(paces)} to the next discovery',
                  style: AppText.body.copyWith(color: Palette.slate, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          XpBar(
            fraction: pacesIntoStretch(paces) / pacesPerDiscovery,
            color: Palette.moss,
            track: Palette.moss.withValues(alpha: 0.18),
            height: 6,
          ),
          const SizedBox(height: 10),
          DiscoveryLog(discoveries: game.discoveries),
        ],
      ),
    );
  }
}

String _gearLine(GearItem? worn, int found, String name) {
  if (found == 0) {
    return 'No gear yet. The first gift comes at Bond ${bondMilestones.first}.';
  }
  final count = '$found of ${companionGear.length} pieces found.';
  return worn == null
      ? '$count Choose one for $name in the Inventory.'
      : 'Wearing the ${worn.name}. $count';
}

/// The Old Friend scene (DESIGN §7A.3, companion level 10): the two of you,
/// side by side.
class OldFriends extends StatelessWidget {
  const OldFriends({
    super.key,
    required this.portraitId,
    required this.kind,
    required this.caption,
    this.frame,
  });

  final String portraitId;
  final String? frame;
  final CompanionKind kind;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Palette.skyDeep, Palette.forestDeep],
        ),
        border: Border.all(color: Palette.gold),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 76,
              width: 132,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    child: HeroPortrait(
                      portraitId: portraitId,
                      size: 76,
                      frame: frame,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: CompanionPortrait(kind: kind, size: 76),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(color: Palette.onDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Journey discoveries, in the order they were found.
class DiscoveryLog extends StatelessWidget {
  const DiscoveryLog({super.key, required this.discoveries, this.onDark = false});

  final List<String> discoveries;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final text = onDark ? Palette.onDark : Palette.slate;
    final soft = onDark ? Palette.onDarkSoft : Palette.slateSoft;
    if (discoveries.isEmpty) {
      return Text(
        'No discoveries yet. Every tenth Pace finds one.',
        style: AppText.small.copyWith(color: soft),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < discoveries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                VIcon(
                  'lantern',
                  size: 18,
                  color: onDark ? Palette.goldBright : Palette.goldDeep,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sceneByKey(discoveries[i], i).title,
                        style: AppText.cardTitle.copyWith(color: text, fontSize: 14.5),
                      ),
                      Text(
                        sceneByKey(discoveries[i], i).line,
                        style: AppText.small.copyWith(color: soft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.progress,
    required this.color,
    this.unit = 'XP',
  });

  final String label;
  final LevelProgress progress;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final detail = progress.xpForLevel == 0
        ? 'Top level'
        : '${progress.xpIntoLevel} / ${progress.xpForLevel} $unit';
    return Semantics(
      label: '$label, $detail',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(label, style: AppText.heading.copyWith(color: Palette.slate)),
                const Spacer(),
                Text(detail, style: AppText.small.copyWith(color: Palette.slateSoft)),
              ],
            ),
            const SizedBox(height: 7),
            XpBar(
              fraction: progress.fraction,
              color: color,
              height: 10,
              track: color.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.attribute,
    required this.xp,
    required this.starred,
    required this.companionName,
  });

  final Attribute attribute;
  final int xp;
  final bool starred;
  final String companionName;

  @override
  Widget build(BuildContext context) {
    final color = Palette.attribute(attribute);
    final progress = XpCurve.progress(xp);
    return Semantics(
      label: '${attribute.label}, level ${progress.level}, $xp XP'
          '${starred ? ', $companionName’s favourite' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: <Widget>[
              Roundel(icon: attributeIcon(attribute), color: color, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          attribute.label,
                          style: AppText.cardTitle.copyWith(
                            color: Palette.slate,
                            fontSize: 14.5,
                          ),
                        ),
                        if (starred) ...<Widget>[
                          const SizedBox(width: 5),
                          const VIcon('affinity', size: 13, color: Palette.companion),
                        ],
                        const Spacer(),
                        Text(
                          'Lv ${progress.level}',
                          style: AppText.small.copyWith(
                            color: Palette.slateSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    XpBar(
                      fraction: progress.fraction,
                      color: color,
                      height: 6,
                      track: color.withValues(alpha: 0.16),
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

class _Tile extends StatelessWidget {
  const _Tile({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  final double width;
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.parchmentEdge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              VIcon(icon, size: 16, color: Palette.goldDeep),
              const SizedBox(height: 5),
              Text(value, style: AppText.number.copyWith(color: Palette.slate, fontSize: 19)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: Palette.slateSoft, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrickRow extends StatelessWidget {
  const TrickRow({super.key, required this.trick, required this.unlocked});

  final Trick trick;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${trick.name}, ${unlocked ? 'learned' : 'at level ${trick.level}'}. '
          '${trick.description}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Opacity(
            opacity: unlocked ? 1 : 0.62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? Palette.companion
                        : Palette.companion.withValues(alpha: 0.16),
                  ),
                  alignment: Alignment.center,
                  child: VIcon(
                    unlocked ? 'trick' : 'lock',
                    size: 15,
                    color: unlocked ? Palette.parchment : Palette.companionDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        unlocked
                            ? trick.name
                            : '${trick.name} · level ${trick.level}',
                        style: AppText.cardTitle.copyWith(
                          color: Palette.slate,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        trick.description,
                        style: AppText.small.copyWith(
                          color: Palette.slateSoft,
                          fontSize: 12.5,
                        ),
                      ),
                      if (unlocked && !tricksInPlay.contains(trick.key))
                        Text(
                          'Learned. It joins the game with the comeback quest.',
                          style: AppText.small.copyWith(
                            color: Palette.companionDeep,
                            fontSize: 12.5,
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
