import 'package:flutter/material.dart';

import '../../rules/classes.dart';
import '../../rules/combat.dart';
import '../../rules/day_key.dart';
import '../../rules/encounter.dart' show withArticle;
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../feel.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// The icon that stands for each class.
String classIcon(HeroClass cls) => switch (cls) {
      HeroClass.ranger => 'compass',
      HeroClass.warden => 'frame',
      HeroClass.sage => 'book',
      HeroClass.artificer => 'trick',
      HeroClass.herald => 'bell',
    };

/// Choosing a class (Amendment v0.3 §2): at the start, on the first launch
/// of 0.7 for a hero who has none, and again for nothing at the weekly
/// Campfire. With [mustChoose] the screen cannot be left without a class.
Future<void> showClassChoice(BuildContext context, {bool mustChoose = false}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => ClassChoiceScreen(mustChoose: mustChoose)),
  );
}

class ClassChoiceScreen extends StatefulWidget {
  const ClassChoiceScreen({super.key, this.mustChoose = false});

  final bool mustChoose;

  @override
  State<ClassChoiceScreen> createState() => _ClassChoiceScreenState();
}

class _ClassChoiceScreenState extends State<ClassChoiceScreen> {
  HeroClass? _picked;
  bool _saving = false;

  Future<void> _confirm(HeroClass cls) async {
    if (_saving) return;
    setState(() => _saving = true);
    Feel.done();
    await GameScope.of(context).chooseClass(cls);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final current = game.heroClass;
    final picked = _picked ?? current ?? HeroClass.choices.first;
    final changing = current != null;
    final day = DayKey.weekdayLong[game.settings.delveWeekday - 1];

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                changing ? 'CHANGE YOUR CLASS' : 'CHOOSE YOUR CLASS',
                style: AppText.label.copyWith(color: Palette.goldBright),
              ),
            ),
            if (!widget.mustChoose)
              RoundIconButton(
                icon: 'close',
                semanticLabel: 'Close',
                size: 36,
                background: Palette.forestNight.withValues(alpha: 0.55),
                foreground: Palette.onDark,
                edge: Palette.onDark.withValues(alpha: 0.25),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'How will you meet the Still?',
          style: AppText.display.copyWith(color: Palette.onDark, fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'Your class is how you fight, and which of your quests make you '
          'stronger there. Any class can wake any creature. Nothing you '
          'have earned changes with it, and you can change it for nothing '
          'at the Campfire each $day.',
          style: AppText.small.copyWith(color: Palette.onDarkSoft),
        ),
      ],
    );

    final choices = <Widget>[
      for (final cls in HeroClass.choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ClassTile(
            cls: cls,
            selected: cls == picked,
            current: cls == current,
            onTap: () {
              Feel.tap();
              setState(() => _picked = cls);
            },
          ),
        ),
    ];

    final detail = _ClassDetail(cls: picked);
    final confirm = PrimaryButton(
      label: changing && picked == current
          ? 'Stay ${withArticle(picked.label)}'
          : 'Become ${withArticle(picked.label)}',
      icon: classIcon(picked),
      onPressed: _saving ? null : () => _confirm(picked),
    );

    final Widget body;
    if (isExpanded(context)) {
      body = TwoPane(
        start: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          children: <Widget>[heading, const SizedBox(height: 14), ...choices],
        ),
        end: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: SingleChildScrollView(child: detail)),
              const SizedBox(height: 10),
              confirm,
            ],
          ),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: <Widget>[
                heading,
                const SizedBox(height: 14),
                ...choices,
                const SizedBox(height: 4),
                detail,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: confirm,
          ),
        ],
      );
    }

    return PopScope(
      canPop: !widget.mustChoose,
      child: Scaffold(
        backgroundColor: Palette.forestNight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Palette.forestDeep, Palette.forestNight],
            ),
          ),
          child: SafeArea(child: body),
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.cls,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final HeroClass cls;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motion(context, Motion.quick),
      decoration: BoxDecoration(
        color: selected
            ? Palette.forest
            : Palette.forestDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? Palette.goldBright
              : Palette.onDark.withValues(alpha: 0.14),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: <Widget>[
                Roundel(
                  icon: classIcon(cls),
                  color: selected ? Palette.gold : Palette.moss,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        current ? '${cls.label} · yours now' : cls.label,
                        style: AppText.cardTitle
                            .copyWith(color: Palette.onDark, fontSize: 16),
                      ),
                      Text(
                        '${cls.role} · ${cls.home.label}',
                        style: AppText.small
                            .copyWith(color: Palette.onDarkSoft, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const VIcon('check', size: 20, color: Palette.goldBright),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a class is, in full: used when choosing and on the Party Sheet.
class _ClassDetail extends StatelessWidget {
  const _ClassDetail({required this.cls});

  final HeroClass cls;

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      child: ClassFacts(cls: cls),
    );
  }
}

/// Role, resource, passive, ability and how the class fares against each
/// kind of creature. Sits on parchment.
class ClassFacts extends StatelessWidget {
  const ClassFacts({super.key, required this.cls});

  final HeroClass cls;

  @override
  Widget build(BuildContext context) {
    Widget fact(String label, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: AppText.label.copyWith(color: Palette.goldDeep)),
              const SizedBox(height: 2),
              Text(text, style: AppText.small.copyWith(color: Palette.slate)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${cls.label} · ${cls.role}',
          style: AppText.cardTitle.copyWith(color: Palette.slate),
        ),
        fact(cls.resource.toUpperCase(), 'From ${cls.feeds}. Every other '
            'quest you finish adds a little too.'),
        fact('ALWAYS', cls.passive),
        fact(cls.ability.toUpperCase(), cls.abilityLine),
        fact('HOW TO PLAY IT', cls.plan),
        const SizedBox(height: 10),
        Text('AGAINST', style: AppText.label.copyWith(color: Palette.goldDeep)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final type in EnemyType.values)
              _MatchChip(type: type, effect: effectOf(cls, type)),
          ],
        ),
      ],
    );
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.type, required this.effect});

  final EnemyType type;
  final Effect effect;

  @override
  Widget build(BuildContext context) {
    final color = switch (effect) {
      Effect.strong => Palette.moss,
      Effect.normal => Palette.slateSoft,
      Effect.hard => Palette.companionDeep,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${type.label}: ${effect.label}',
        style: AppText.small.copyWith(color: color, fontSize: 12.5),
      ),
    );
  }
}
