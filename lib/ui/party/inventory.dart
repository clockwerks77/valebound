import 'package:flutter/material.dart';

import '../../rules/companion_rules.dart';
import '../../rules/enums.dart';
import '../../rules/gear.dart';
import '../../rules/xp_curve.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../art/crests.dart';
import '../art/painted.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'party_sheet.dart';

// Inventory (DESIGN §8.4): gold, materials, cosmetic unlocks, companion gear
// and tricks. Everything here is cosmetic or a counter; nothing has a price.

/// The hero's side: the stores, portrait frames, banners and decorations.
class HeroInventory extends StatelessWidget {
  const HeroInventory({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final stores = game.stores;
    final gathered = <String>[
      for (final m in MaterialKind.values)
        '${m.label} ${game.materials[m] ?? 0}',
    ].join(' · ');

    return ParchmentCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('INVENTORY', style: AppText.label.copyWith(color: Palette.goldDeep)),
          const SizedBox(height: 2),
          Text(
            'The stores',
            style: AppText.heading.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _Stock(
                icon: 'coin',
                color: Palette.goldDeep,
                value: game.hero?.gold ?? 0,
                label: 'Gold',
              ),
              for (final m in MaterialKind.values)
                _Stock(
                  icon: materialIcon(m),
                  color: Palette.material(m),
                  value: stores[m] ?? 0,
                  label: m.label,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Gathered in all: $gathered. What is not in the stores has been '
            'built into the Vale.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          for (final kind in CosmeticKind.values) ...<Widget>[
            PaneHeading(kind.label),
            for (final c in heroCosmetics)
              if (c.kind == kind) _CosmeticRow(cosmetic: c),
          ],
        ],
      ),
    );
  }
}

class _CosmeticRow extends StatelessWidget {
  const _CosmeticRow({required this.cosmetic});

  final Cosmetic cosmetic;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final unlocked = game.cosmeticsUnlocked.contains(cosmetic.key);
    final inUse = switch (cosmetic.kind) {
      CosmeticKind.frame => game.frame == cosmetic.key,
      CosmeticKind.banner => game.banner == cosmetic.key,
      CosmeticKind.decoration => false,
    };
    final Color color = switch (cosmetic.kind) {
      CosmeticKind.frame => frameColor(cosmetic.key),
      CosmeticKind.banner => bannerColor(cosmetic.key),
      CosmeticKind.decoration => Palette.moss,
    };
    final String icon = switch (cosmetic.kind) {
      CosmeticKind.frame => 'frame',
      CosmeticKind.banner => 'banner',
      CosmeticKind.decoration => 'bunting',
    };
    final String state;
    if (!unlocked) {
      state = cosmetic.unlocksAt;
    } else if (cosmetic.kind == CosmeticKind.decoration) {
      state = 'On the map';
    } else {
      state = inUse ? 'In use' : 'Use';
    }
    final canUse =
        unlocked && !inUse && cosmetic.kind != CosmeticKind.decoration;
    return UnlockRow(
      icon: icon,
      color: color,
      name: cosmetic.name,
      line: cosmetic.line,
      state: state,
      unlocked: unlocked,
      highlighted: inUse,
      onTap: canUse ? () => game.equipCosmetic(cosmetic.key) : null,
    );
  }
}

/// The companion's side: gear to wear and the tricks learned.
class CompanionInventory extends StatelessWidget {
  const CompanionInventory({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final companion = game.companion!;
    final level = XpCurve.levelForXp(companion.totalXp);
    final worn = companion.gearEquipped;

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
                size: 56,
                gearIcon: game.gearWorn?.icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'GEAR AND TRICKS',
                      style: AppText.label.copyWith(color: Palette.companionDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${companion.name}’s things',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(color: Palette.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gifts arrive as your Bond grows. Gear is for show: it changes '
            'nothing but how ${companion.name} looks.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const PaneHeading('Gear', color: Palette.companionDeep),
          for (final g in companionGear)
            Builder(
              builder: (context) {
                final unlocked = game.gearUnlocked.contains(g.key);
                final wearing = worn == g.key;
                return UnlockRow(
                  icon: g.icon,
                  art: gearArt(g.key),
                  color: Palette.companion,
                  name: g.name,
                  line: g.line,
                  state: !unlocked
                      ? g.unlocksAt
                      : (wearing ? 'Wearing' : 'Wear'),
                  unlocked: unlocked,
                  highlighted: wearing,
                  onTap: unlocked
                      ? () => game.equipGear(wearing ? null : g.key)
                      : null,
                );
              },
            ),
          const PaneHeading('Tricks', color: Palette.companionDeep),
          for (final trick in companionTricks)
            TrickRow(trick: trick, unlocked: level >= trick.level),
        ],
      ),
    );
  }
}

/// One cosmetic or piece of gear: found or still to come.
class UnlockRow extends StatelessWidget {
  const UnlockRow({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.line,
    required this.state,
    required this.unlocked,
    this.highlighted = false,
    this.onTap,
    this.art,
  });

  final String icon;

  /// A picture of the thing, shown in place of [icon] once it is found.
  final String? art;
  final Color color;
  final String name;
  final String line;

  /// e.g. `In use`, `Use`, `Level 6`, `Bond 25`.
  final String state;
  final bool unlocked;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: <Widget>[
          if (art != null && unlocked)
            ArtMedallion(
              asset: art,
              size: 40,
              ring: highlighted ? Palette.goldDeep : Palette.parchmentEdge,
              fallback: const SizedBox(width: 40, height: 40),
            )
          else
          Opacity(
            opacity: unlocked ? 1 : 0.5,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? color : color.withValues(alpha: 0.22),
                border: Border.all(
                  color: highlighted ? Palette.goldDeep : Colors.transparent,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: VIcon(
                unlocked ? icon : 'lock',
                size: 17,
                color: unlocked ? Palette.parchment : Palette.slateSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: unlocked ? 1 : 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(
                      color: Palette.slate,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    line,
                    style: AppText.small.copyWith(
                      color: Palette.slateSoft,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? Palette.gold.withValues(alpha: 0.3)
                  : (onTap != null
                      ? Palette.forest
                      : Colors.white.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlighted
                    ? Palette.goldDeep
                    : (onTap != null ? Palette.gold : Palette.parchmentEdge),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                state,
                style: AppText.small.copyWith(
                  color: onTap != null && !highlighted
                      ? Palette.onDark
                      : Palette.slate,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$name. $line $state',
      child: ExcludeSemantics(
        child: onTap == null
            ? row
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: row,
              ),
      ),
    );
  }
}

class _Stock extends StatelessWidget {
  const _Stock({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final String icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Roundel(icon: icon, color: color, size: 36),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$value',
                  style: AppText.number.copyWith(color: Palette.slate),
                ),
                Text(
                  label,
                  style: AppText.small.copyWith(
                    color: Palette.slateSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
