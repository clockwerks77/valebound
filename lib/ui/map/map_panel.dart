import 'package:flutter/material.dart';

import '../../rules/companion_rules.dart';
import '../../rules/enums.dart';
import '../../rules/journey.dart';
import '../../rules/still.dart';
import '../../rules/world.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../art/painted.dart';
import '../party/party_sheet.dart';
import '../story/chronicle_screen.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'vale_map.dart';

/// The World Map screen (DESIGN §8.2).
///
/// * Cover screen: the map, then what is being restored, the road, and the
///   places region by region.
/// * Opened Fold, Map tab: the map on one pane ([MapPane]) and the details
///   on the other ([MapDetails]).
/// * Opened Fold, Board tab: this panel beside the board, trimmed to the map,
///   the current restoration and the road ([brief]).
class MapPanel extends StatelessWidget {
  const MapPanel({super.key, this.brief = false});

  final bool brief;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        const _MapHeading(),
        const SizedBox(height: 10),
        const _TheMap(),
        if (!brief) ...const <Widget>[SizedBox(height: 10), MapLegend()],
        const SizedBox(height: 14),
        const TargetCard(),
        const SizedBox(height: 12),
        const RoadCard(),
        if (!brief) ...const <Widget>[
          StillCard(),
          SectionHeader('Places', icon: 'home'),
          PlacesCard(),
          SectionHeader('Discoveries', icon: 'lantern'),
          _DiscoveriesCard(),
        ],
      ],
    );
  }
}

/// The map by itself, for the start pane of the Map tab on the opened Fold.
class MapPane extends StatelessWidget {
  const MapPane({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 24),
      children: const <Widget>[
        _MapHeading(),
        SizedBox(height: 10),
        _TheMap(),
        SizedBox(height: 10),
        MapLegend(),
      ],
    );
  }
}

/// Everything about the map except the map, for the end pane.
class MapDetails extends StatelessWidget {
  const MapDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 14, 14, 24),
      children: const <Widget>[
        TargetCard(),
        SizedBox(height: 12),
        RoadCard(),
        StillCard(),
        SectionHeader('Places', icon: 'home'),
        PlacesCard(),
        SectionHeader('Discoveries', icon: 'lantern'),
        _DiscoveriesCard(),
      ],
    );
  }
}

class _MapHeading extends StatelessWidget {
  const _MapHeading();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final drafted = restorationTargets.length;
    final restored = game.restored;
    final String line;
    if (restored == 0) {
      line = 'Asleep, for now';
    } else if (restored >= drafted) {
      line = 'The Vale is awake';
    } else {
      line = '$restored of $drafted places awake';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'THE VALE',
                  style: AppText.label.copyWith(color: Palette.goldBright),
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  style: AppText.display
                      .copyWith(color: Palette.onDark, fontSize: 24),
                ),
                const SizedBox(height: 2),
                // Where the story has reached (DECISIONS D-76).
                Text(
                  game.storyTitle,
                  style: AppText.small.copyWith(color: Palette.onDarkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          RoundIconButton(
            icon: 'book',
            semanticLabel: 'Chronicle',
            size: 40,
            background: Palette.forestNight.withValues(alpha: 0.55),
            foreground: Palette.onDark,
            edge: Palette.onDark.withValues(alpha: 0.25),
            onPressed: () => openChronicle(context),
          ),
        ],
      ),
    );
  }
}

class _TheMap extends StatelessWidget {
  const _TheMap();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return ValeMap(
      restored: game.restored,
      paces: game.world?.journeyPaces ?? 0,
      discoveries: game.discoveries.length,
      scout: (game.companion?.level ?? 1) >= scoutLevel,
      stills: game.stillQuests.length,
      decorations: game.cosmeticsUnlocked,
    );
  }
}

/// What the marks on the map mean.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color fill, Color ring) => Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: ring, width: 1.6),
          ),
        );
    Widget item(Widget mark, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            mark,
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.small.copyWith(
                color: Palette.onDarkSoft,
                fontSize: 12,
              ),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        label: 'Map key: restored places are gold-ringed, the next one is '
            'pale, sleeping ones are grey. The tent is your camp and each '
            'gold light is a discovery.',
        child: ExcludeSemantics(
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              item(dot(Palette.forest, Palette.goldBright), 'Restored'),
              item(dot(Palette.parchment, Palette.gold), 'Next'),
              item(dot(const Color(0xFF8D9A9B), const Color(0xFFC9D2D0)), 'Asleep'),
              item(
                const VIcon('tent', size: 14, color: Palette.onDark),
                'Camp',
              ),
              item(dot(Palette.goldBright, Palette.forestNight), 'Discovery'),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next restoration target and its material cost (DESIGN §8.2).
class TargetCard extends StatelessWidget {
  const TargetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final target = game.target;
    final stores = game.stores;
    final region = regionByKey(target.region);
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ArtMedallion(
                asset: placeArt(target.key),
                size: 52,
                fallback: Roundel(
                  icon: target.villager?.icon ?? 'lantern',
                  color: Palette.forest,
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'WORKING TOWARD · ${region.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(color: Palette.goldDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title.copyWith(color: Palette.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final kind in MaterialKind.values)
            if (target.costOf(kind) > 0)
              _NeedRow(
                kind: kind,
                have: stores[kind] ?? 0,
                need: target.costOf(kind),
              ),
          const SizedBox(height: 4),
          Text(
            'Hero quests bring materials. When everything is here, it wakes.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
        ],
      ),
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.kind, required this.have, required this.need});

  final MaterialKind kind;
  final int have;
  final int need;

  @override
  Widget build(BuildContext context) {
    final shown = have > need ? need : have;
    final ready = have >= need;
    final color = Palette.material(kind);
    return Semantics(
      label: '${kind.label}: $shown of $need',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: <Widget>[
              VIcon(materialIcon(kind), size: 18, color: color),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: Text(
                  kind.label,
                  style: AppText.small.copyWith(
                    color: Palette.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: XpBar(
                  fraction: need == 0 ? 1 : shown / need,
                  color: color,
                  track: color.withValues(alpha: 0.18),
                  height: 7,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                child: Text(
                  '$shown / $need',
                  textAlign: TextAlign.right,
                  style: AppText.small.copyWith(
                    color: ready ? Palette.moss : Palette.slateSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Journey road: camp position, Paces and the next Discovery.
class RoadCard extends StatelessWidget {
  const RoadCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final paces = game.world?.journeyPaces ?? 0;
    final region = regions[regionIndexForPaces(paces)];
    final scouting = (game.companion?.level ?? 1) >= scoutLevel;
    final next = sceneFor(game.discoveries.length);
    final String camp;
    if (paces == 0) {
      camp = 'Camp is at the village gate.';
    } else if (paces >= roadPaces) {
      camp = 'Camp is at Old Lanternhall, and the road goes on.';
    } else {
      camp = 'Camp is in ${region.name}.';
    }
    return ParchmentCard(
      tint: Palette.companionTint,
      edge: Palette.companionEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const VIcon('tent', size: 20, color: Palette.companionDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$paces ${paces == 1 ? 'Pace' : 'Paces'} with '
                  '${game.companionName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(color: Palette.slate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$camp ${pacesToNextDiscovery(paces)} more to the next discovery.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 10),
          XpBar(
            fraction: pacesIntoStretch(paces) / pacesPerDiscovery,
            color: Palette.companion,
            track: Palette.companion.withValues(alpha: 0.18),
          ),
          if (scouting) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const VIcon('compass', size: 16, color: Palette.companionDeep),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${game.companionName} has scouted ahead: ${next.hint}.',
                    style: AppText.small.copyWith(
                      color: Palette.companionDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Still creatures on today's bigger quests (DESIGN §7). Shown only while
/// there are any.
class StillCard extends StatelessWidget {
  const StillCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final quests = game.stillQuests;
    if (quests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ParchmentCard(
        tint: const Color(0xFFEDEFEC),
        edge: Palette.stillGrey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'THE STILL, ON THE ROAD TODAY',
              style: AppText.label.copyWith(color: Palette.slateSoft),
            ),
            const SizedBox(height: 6),
            for (final entry in quests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const VIcon('still', size: 20, color: Palette.slateSoft),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${entry.quest.name}: ${stillFor(entry.quest.id).sits}',
                        style: AppText.small.copyWith(color: Palette.slate),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Finish the quest and its creature wakes and wanders off.',
              style: AppText.small.copyWith(color: Palette.slateSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every drafted place, region by region, asleep or awake.
class PlacesCard extends StatelessWidget {
  const PlacesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final restored = game.restored;
    var index = 0;
    final sections = <Widget>[];
    for (final region in regions) {
      final places = targetsIn(region.key);
      final awake = (regionWake(region.key, restored) * places.length).round();
      final rows = <Widget>[];
      for (final place in places) {
        final i = index++;
        rows.add(
          _PlaceRow(
            place: place,
            awake: i < restored,
            current: i == restored,
            villagerHome: i < restored ? place.villager : null,
          ),
        );
      }
      sections.add(
        Padding(
          padding: EdgeInsets.only(top: sections.isEmpty ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      region.name,
                      style: AppText.cardTitle.copyWith(color: Palette.slate),
                    ),
                  ),
                  Text(
                    '$awake of ${places.length} awake',
                    style: AppText.small.copyWith(color: Palette.slateSoft),
                  ),
                ],
              ),
              Text(
                region.blurb,
                style: AppText.small.copyWith(
                  color: Palette.slateSoft,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              ...rows,
            ],
          ),
        ),
      );
    }
    final lanterns = restored - restorationTargets.length;
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...sections,
          if (lanterns > 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '$lanterns more ${lanterns == 1 ? 'lantern' : 'lanterns'} lit '
              'along the road since.',
              style: AppText.small.copyWith(color: Palette.moss),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.awake,
    required this.current,
    required this.villagerHome,
  });

  final RestorationTarget place;
  final bool awake;
  final bool current;
  final Villager? villagerHome;

  @override
  Widget build(BuildContext context) {
    final String status;
    if (awake) {
      final v = villagerHome;
      status = v == null ? 'Awake' : '${v.name}, ${v.role.toLowerCase()}';
    } else if (current) {
      status = 'Being restored';
    } else {
      status = 'Asleep';
    }
    final color = awake
        ? Palette.moss
        : (current ? Palette.goldDeep : Palette.slateFaint);
    return Semantics(
      label: '${place.name}: $status',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.5),
          child: Row(
            children: <Widget>[
              ArtMedallion(
                asset: placeArt(place.key),
                size: 30,
                ring: awake ? Palette.gold : Palette.goldDeep,
                asleep: !awake && !current,
                fallback: SizedBox(
                  width: 30,
                  child: VIcon(
                    awake ? 'check' : (current ? 'sun' : 'moon'),
                    size: 15,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: awake || current ? Palette.slate : Palette.slateSoft,
                    fontSize: 14,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: AppText.small.copyWith(color: color, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveriesCard extends StatelessWidget {
  const _DiscoveriesCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return ParchmentCard(child: DiscoveryLog(discoveries: game.discoveries));
  }
}
