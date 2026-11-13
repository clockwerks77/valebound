import 'package:flutter/material.dart';

import '../../rules/enums.dart';
import '../../rules/journey.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../art/vista.dart';
import '../party/party_sheet.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// The Vale, as far as Phase 1 goes: a view of the sleeping valley with the
/// materials and Paces already earned. The illustrated World Map with
/// restoration and the Journey road replaces this in Phase 2 (DECISIONS.md
/// D-20); nothing counted here is thrown away when it does.
class ValePanel extends StatelessWidget {
  const ValePanel({super.key, this.showDiscoveries = true});

  final bool showDiscoveries;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final paces = game.world?.journeyPaces ?? 0;
    final companion = game.companionName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        SizedBox(
          height: 220,
          child: Vista(
            wake: 0.22,
            radius: 26,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'THE VALE',
                      style: AppText.label.copyWith(color: Palette.goldBright),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asleep, for now',
                      style: AppText.display.copyWith(
                        color: Palette.onDark,
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'A grey stillness lies over the valley. The map is still being '
            'drawn, but every quest you finish already counts toward waking '
            'it.',
            style: AppText.body.copyWith(color: Palette.onDarkSoft),
          ),
        ),
        const SectionHeader('Gathered so far', icon: 'timber'),
        ParchmentCard(
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              for (final m in MaterialKind.values)
                _Stock(
                  icon: materialIcon(m),
                  color: Palette.material(m),
                  value: game.materials[m] ?? 0,
                  label: m.label,
                ),
              _Stock(
                icon: 'coin',
                color: Palette.goldDeep,
                value: game.hero?.gold ?? 0,
                label: 'Gold',
              ),
            ],
          ),
        ),
        const SectionHeader('The road', icon: 'pace'),
        ParchmentCard(
          tint: Palette.companionTint,
          edge: Palette.companionEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$paces ${paces == 1 ? 'Pace' : 'Paces'} with $companion',
                style: AppText.cardTitle.copyWith(color: Palette.slate),
              ),
              const SizedBox(height: 3),
              Text(
                '${pacesToNextDiscovery(paces)} more to the next discovery. '
                'Small goals move you along the road, together.',
                style: AppText.small.copyWith(color: Palette.slateSoft),
              ),
              const SizedBox(height: 10),
              XpBar(
                fraction: pacesIntoStretch(paces) / pacesPerDiscovery,
                color: Palette.companion,
                track: Palette.companion.withValues(alpha: 0.18),
              ),
              if (showDiscoveries) ...<Widget>[
                const SizedBox(height: 12),
                DiscoveryLog(discoveries: game.discoveries),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The discoveries log by itself, for the second pane of the Map tab.
class JourneyLogPanel extends StatelessWidget {
  const JourneyLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 14, 14, 28),
      children: <Widget>[
        const SectionHeader('Discoveries', icon: 'lantern'),
        ParchmentCard(child: DiscoveryLog(discoveries: game.discoveries)),
      ],
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
