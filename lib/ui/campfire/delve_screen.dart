import 'package:flutter/material.dart';

import '../../data/repository.dart';
import '../../rules/day_key.dart';
import '../../rules/delve.dart';
import '../../rules/enums.dart';
import '../../rules/world.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'campfire_screen.dart' show CampScene;

/// Opens the weekly Delve over the Campfire.
Future<void> openDelve(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    RiseRoute<void>(builder: (_) => const DelveScreen()),
  );
}

/// The weekly Delve (DESIGN §3B, §4.2): one screen, resolved from the week's
/// quests. Cleared, Scouted or Rested; the party comes home with something
/// every time, and nothing is ever taken.
class DelveScreen extends StatefulWidget {
  const DelveScreen({super.key});

  @override
  State<DelveScreen> createState() => _DelveScreenState();
}

class _DelveScreenState extends State<DelveScreen> {
  DelveWaiting? _waiting;
  DelveResult? _result;
  bool _loaded = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _waiting = GameScope.read(context).delve;
    }
  }

  Future<void> _enter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await GameScope.read(context).enterDelve();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final waiting = _waiting;
    final result = _result;
    final site = result?.site ?? waiting?.site ?? '';
    final delveDay = result?.delveDay ?? waiting?.delveDay;
    final supplies = result?.supplies ?? waiting?.supplies;

    final content = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: RoundIconButton(
          icon: 'close',
          semanticLabel: 'Back to the Campfire',
          size: 40,
          background: Palette.forestNight.withValues(alpha: 0.5),
          foreground: Palette.onDark,
          edge: Palette.onDark.withValues(alpha: 0.25),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'THE WEEKLY DELVE',
        style: AppText.label.copyWith(color: Palette.goldBright),
      ),
      const SizedBox(height: 4),
      Text(
        site.isEmpty ? 'No Delve is open tonight' : site,
        style: AppText.display.copyWith(color: Palette.onDark, fontSize: 25),
      ),
      if (delveDay != null) ...<Widget>[
        const SizedBox(height: 4),
        Text(
          'For the week ending ${DayKey.friendly(delveDay)}.',
          style: AppText.small.copyWith(color: Palette.onDarkSoft),
        ),
      ],
      const SizedBox(height: 14),
      if (supplies != null) _SuppliesCard(supplies: supplies),
      const SizedBox(height: 12),
      if (result != null)
        _ResultCard(result: result, companionName: game.companionName)
      else if (waiting != null) ...<Widget>[
        Text(
          'Whatever the week was like, the party comes home with something.',
          style: AppText.body.copyWith(color: Palette.onDark),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            PrimaryButton(
              label: 'Enter the Delve',
              icon: 'cave',
              color: Palette.moss,
              onPressed: _busy ? null : _enter,
            ),
            QuietButton(
              label: 'Not tonight',
              color: Palette.onDark,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
      if (result != null) ...<Widget>[
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryButton(
            label: 'Back to camp',
            icon: 'campfire',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
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
          child: isExpanded(context)
              ? TwoPane(
                  start: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 0, 24),
                    children: content,
                  ),
                  end: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 24),
                    children: const <Widget>[CampScene()],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                  children: content,
                ),
        ),
      ),
    );
  }
}

class _SuppliesCard extends StatelessWidget {
  const _SuppliesCard({required this.supplies});

  final DelveSupplies supplies;

  @override
  Widget build(BuildContext context) {
    Widget row(String icon, String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              VIcon(icon, size: 17, color: Palette.goldDeep),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(color: Palette.slate, fontSize: 14.5),
                ),
              ),
              Text(
                '$value',
                style: AppText.number.copyWith(color: Palette.slate, fontSize: 17),
              ),
            ],
          ),
        );
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WHAT THE WEEK GATHERED',
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 6),
          row('bag', 'Provisions, from your own quests', supplies.provisions),
          row('pace', 'Trail marks, from your companion’s', supplies.trailMarks),
          row('key', 'Keys, from Heroic and Boss quests', supplies.keys),
          row('sun', 'Days on the road', supplies.daysActive),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.companionName});

  final DelveResult result;
  final String companionName;

  @override
  Widget build(BuildContext context) {
    final reward = result.reward;
    return ParchmentCard(
      edge: Palette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.tier.label.toUpperCase(),
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 6),
          Text(
            delveLine(result.tier, companionName),
            style: AppText.cardTitle.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              _Brought('coin', '+${reward.gold} gold', Palette.goldDeep),
              for (final kind in MaterialKind.values)
                _Brought(
                  materialIcon(kind),
                  '+${reward.eachMaterial} ${kind.label}',
                  Palette.material(kind),
                ),
            ],
          ),
          for (final index in result.newRestorationIndexes)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  const VIcon('sun', size: 17, color: Palette.goldDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Restored: ${targetAt(index).name}, in '
                      '${regionByKey(targetAt(index).region).name}.',
                      style: AppText.body.copyWith(color: Palette.slate),
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

class _Brought extends StatelessWidget {
  const _Brought(this.icon, this.text, this.color);

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        VIcon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppText.body.copyWith(
            color: Palette.slate,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}
