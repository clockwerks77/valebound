import 'package:flutter/material.dart';

import '../../data/repository.dart';
import '../../rules/classes.dart';
import '../../rules/combat.dart';
import '../../rules/encounter.dart';
import '../../rules/narrator.dart' show chapterClosedBy;
import '../../rules/world.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../art/crests.dart';
import '../art/painted.dart';
import '../celebrations.dart';
import '../feel.dart';
import '../motion.dart';
import '../story/story.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'class_choice.dart' show classIcon;

/// Opens today's encounter (Amendment v0.3 §3).
Future<void> openEncounter(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const EncounterScreen()),
  );
}

/// Opens the week's boss fight, from the Campfire (Amendment v0.3 §5).
Future<void> openBoss(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    RiseRoute<void>(builder: (_) => const EncounterScreen(boss: true)),
  );
}

enum _Stage { scout, fight, over }

/// One fight on one screen: the scout's report, the turns, and how it came
/// out. On the opened Fold the creature and its intent keep one pane and
/// the actions and the log the other; on the cover screen they stack, with
/// the actions under the thumb.
class EncounterScreen extends StatefulWidget {
  const EncounterScreen({super.key, this.boss = false});

  final bool boss;

  @override
  State<EncounterScreen> createState() => _EncounterScreenState();
}

class _EncounterScreenState extends State<EncounterScreen> {
  _Stage _stage = _Stage.scout;
  bool _heroic = false;
  Advantage? _advantage;
  Fight? _fight;
  bool _companionOn = true;
  bool _busy = false;
  final List<String> _log = <String>[];
  EncounterOutcome? _outcome;
  BossOutcome? _bossOutcome;

  // What the screen is about, fixed when it opens so a finished fight
  // still shows the creature it was fought against.
  late String _name;
  late EnemyType _type;
  late String? _art;
  late String _line;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stage != _Stage.scout || _fight != null) return;
    final game = GameScope.of(context);
    if (widget.boss) {
      final boss = game.bossState.boss;
      _name = boss.name;
      _type = boss.type;
      _art = null;
      _line = boss.line;
    } else {
      final enemy = game.enemyToday;
      _name = enemy.name;
      _type = enemy.type;
      _art = stillArt(enemy.art);
      _line = enemy.line;
    }
  }

  String get _capName => widget.boss ? _name : 'The $_name';

  void _begin() {
    final game = GameScope.of(context);
    final setup = widget.boss
        ? game.bossSetup(advantage: _advantage)
        : game.encounterSetup(heroic: _heroic);
    if (setup == null) return;
    Feel.done();
    setState(() {
      _fight = Fight(setup);
      _stage = _Stage.fight;
      _log
        ..clear()
        ..add('$_capName holds the road.');
    });
  }

  Future<void> _act(CombatAction action) async {
    final fight = _fight;
    if (fight == null || fight.over || _busy || !fight.canDo(action)) return;
    final game = GameScope.of(context);
    Feel.tap();
    final turn = fight.turn;
    final events = fight.act(
      action,
      companion: _companionOn && fight.companionReady,
    );
    final cls = fight.cls;
    setState(() {
      _log.add('TURN $turn');
      for (final e in events) {
        _log.add(_tell(e, cls, game.companionName));
      }
    });
    if (!fight.over) return;
    setState(() => _busy = true);
    Feel.moment();
    if (widget.boss) {
      _bossOutcome = await game.finishBoss(
        fight,
        spentMarks: _advantage != null,
      );
    } else {
      _outcome = await game.finishEncounter(fight);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = _Stage.over;
    });
  }

  Future<void> _leave() async {
    final restored = <int>[
      ...?_outcome?.newRestorationIndexes,
      ...?_bossOutcome?.newRestorationIndexes,
    ];
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    for (final index in restored) {
      if (!navigator.mounted) return;
      await showRestoration(navigator.context, target: targetAt(index));
      final closed = chapterClosedBy(index);
      if (closed != null && navigator.mounted) {
        await showChapterTurn(navigator.context, closed);
      }
    }
  }

  String _tell(CombatEvent e, HeroClass cls, String companion) {
    final n = e.amount;
    final dice = e.roll == 0
        ? ''
        : ' (d20: ${e.roll}${e.crit ? ', a critical' : ''})';
    final shield = e.blocked == 0 ? '' : ' Your Shield takes ${e.blocked}.';
    return switch (e.kind) {
      CombatEventKind.companionHit => '$companion strikes for $n.$dice',
      CombatEventKind.companionWide => '$companion’s blow goes wide.$dice',
      CombatEventKind.strikeHit => 'You strike for $n.$dice',
      CombatEventKind.strikeWide => 'Your strike goes wide.$dice',
      CombatEventKind.warded => 'Its ward takes the blow whole, and is gone.',
      CombatEventKind.defend =>
        'You brace, and gather yourself: +1 ${cls.resource}.',
      CombatEventKind.volley => '$companion’s volley hits for $n.',
      CombatEventKind.standFirm =>
        'You stand firm: +$n Shield, and every blow comes to you.',
      CombatEventKind.exploit => 'You find the gap: $n, and it is stunned.',
      CombatEventKind.trapSet => 'The trap is set. No hide will help it now.',
      CombatEventKind.salve => 'The salve mends $n HP.',
      CombatEventKind.bomb => 'The bomb goes off: $n.',
      CombatEventKind.smoke => 'Smoke rolls across the road.',
      CombatEventKind.trapBite => 'The trap bites for $n.',
      CombatEventKind.riposte => 'You answer the blow: $n.',
      CombatEventKind.enemyHit => n == 0 && e.blocked > 0
          ? 'It hits your Shield, which takes all ${e.blocked}.'
          : 'It hits you for $n.$shield',
      CombatEventKind.enemyHitCompanion => 'It goes for $companion: $n.',
      CombatEventKind.enemyCharge =>
        'It draws itself up. Something big is coming.',
      CombatEventKind.enemyBig => n == 0 && e.blocked > 0
          ? 'The big blow breaks on your Shield, which takes ${e.blocked}.'
          : 'The big blow lands: $n.$shield',
      CombatEventKind.enemyHeavy => n == 0 && e.blocked > 0
          ? 'A heavy blow, and your Shield takes all ${e.blocked}.'
          : 'A heavy blow: $n.$shield',
      CombatEventKind.enemySwarm => n == 0 && e.blocked > 0
          ? 'One of them hits your Shield: ${e.blocked}.'
          : 'One of them hits you for $n.$shield',
      CombatEventKind.enemyFortify => 'It settles deeper and mends $n HP.',
      CombatEventKind.enemyHex => 'A hex takes hold: your next blow is '
          'halved, and a little ${cls.resource} drains away.',
      CombatEventKind.enemyHexShrugged => 'Its hex slides off you.',
      CombatEventKind.enemyWard => 'A ward shimmers up around it.',
      CombatEventKind.enemyStopped => 'It does nothing this turn.',
      CombatEventKind.companionWinded =>
        '$companion is winded and sits the rest of this one out.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_stage) {
      _Stage.scout => _scout(context),
      _Stage.fight => _fighting(context),
      _Stage.over => _result(context),
    };
    return PopScope(
      // A fight in hand is finished, not walked out of half way.
      canPop: _stage != _Stage.fight && !_busy,
      child: Scaffold(
        backgroundColor: Palette.forestNight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Palette.skyDeep, Palette.forestNight],
              stops: <double>[0.0, 0.5],
            ),
          ),
          child: SafeArea(child: body),
        ),
      ),
    );
  }

  // ---- Pieces shared by the three stages --------------------------------

  Widget _heading(String label, {bool close = true}) => Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppText.label.copyWith(color: Palette.goldBright),
            ),
          ),
          if (close)
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
      );

  Widget _portrait(double size, {bool awake = false}) => ArtMedallion(
        asset: _art,
        size: size,
        ring: awake ? Palette.goldBright : Palette.stillGrey,
        fallback: Roundel(
          icon: widget.boss ? 'fog' : 'still',
          color: awake ? Palette.gold : Palette.stillGrey,
          size: size,
        ),
      );

  Widget _typeChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.onDark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Palette.onDark.withValues(alpha: 0.3)),
        ),
        child: Text(
          widget.boss ? 'Boss · ${_type.label}' : _type.label,
          style: AppText.small.copyWith(color: Palette.onDark, fontSize: 12),
        ),
      );

  // ---- The scout's report -----------------------------------------------

  Widget _scout(BuildContext context) {
    final game = GameScope.of(context);
    final cls = game.heroClass;
    if (cls == null) {
      return Center(
        child: Text(
          'Choose a class first.',
          style: AppText.body.copyWith(color: Palette.onDark),
        ),
      );
    }
    final effect = effectOf(cls, _type);
    final boss = game.bossState;
    final pouch = game.pouch;
    final carried = <String>[
      for (final kind in ItemKind.values)
        if ((pouch[kind] ?? 0) > 0) '${pouch[kind]} ${kind.label}',
    ];

    final about = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(widget.boss ? 'THE WEEKLY DELVE' : 'TODAY’S ENCOUNTER'),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            _portrait(72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.boss ? _name : withArticle(_name, capital: true),
                    style: AppText.display
                        .copyWith(color: Palette.onDark, fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  _typeChip(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _line,
          style: AppText.narrator.copyWith(color: Palette.onDark, fontSize: 16),
        ),
        if (widget.boss && boss.hpLeft != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'You have worn it down before. What you took off it is still '
            'off.',
            style: AppText.small.copyWith(color: Palette.onDarkSoft),
          ),
        ],
      ],
    );

    final report = ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SCOUT’S REPORT',
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 4),
          Text(
            '${_type.label}: ${_type.means}. For ${withArticle(cls.label)} '
            'this one is ${effect.label.toLowerCase()}.',
            style: AppText.cardTitle.copyWith(color: Palette.slate, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            scoutLine(cls, _type),
            style: AppText.small.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 6),
          Text(
            weaknessOf(_type),
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 8),
          Text(
            '${cls.resource} ${game.resourceNow} of $resourceCap, from '
            '${game.questsDone.isEmpty ? 'a day with no quests done yet' : 'today’s quests'}. '
            '${carried.isEmpty ? 'The pouch is empty.' : 'In the pouch: ${carried.join(', ')}.'}',
            style: AppText.small.copyWith(color: Palette.slate),
          ),
          if (widget.boss) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'You have $bossTurns turns. If it is still standing then, it '
              'holds, and what you took off it stays off for next week.',
              style: AppText.small.copyWith(color: Palette.slate),
            ),
          ],
        ],
      ),
    );

    final Widget choice;
    if (widget.boss) {
      choice = boss.canBuyAdvantage
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SPEND $advantageCost OF ${boss.marks} BOSS MARKS ON ONE',
                  style: AppText.label.copyWith(color: Palette.goldBright),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final a in Advantage.values)
                      ChoicePill(
                        label: a.label,
                        caption: a.does,
                        selected: _advantage == a,
                        color: Palette.moss,
                        onTap: () => setState(
                          () => _advantage = _advantage == a ? null : a,
                        ),
                      ),
                  ],
                ),
              ],
            )
          : Text(
              'Boss Marks: ${boss.marks} of $advantageCost for an opening '
              'advantage. Each daily encounter you win brings one.',
              style: AppText.small.copyWith(color: Palette.onDarkSoft),
            );
    } else {
      choice = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'HOW HARD',
            style: AppText.label.copyWith(color: Palette.goldBright),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoicePill(
                label: 'Standard',
                caption: 'The usual chest',
                selected: !_heroic,
                color: Palette.moss,
                onTap: () => setState(() => _heroic = false),
              ),
              ChoicePill(
                label: 'Heroic',
                caption: 'Tougher, for a chest half as big again',
                selected: _heroic,
                color: Palette.companionDeep,
                onTap: () => setState(() => _heroic = true),
              ),
            ],
          ),
        ],
      );
    }

    final begin = PrimaryButton(
      label: widget.boss ? 'Go in' : 'Meet it',
      icon: classIcon(cls),
      onPressed: _begin,
    );

    if (isExpanded(context)) {
      return TwoPane(
        start: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          children: <Widget>[about, const SizedBox(height: 14), choice],
        ),
        end: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: SingleChildScrollView(child: report)),
              const SizedBox(height: 10),
              begin,
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: <Widget>[
              about,
              const SizedBox(height: 12),
              report,
              const SizedBox(height: 12),
              choice,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: begin,
        ),
      ],
    );
  }

  // ---- The fight ----------------------------------------------------------

  String _intentLine(Fight f, String companion) {
    if (f.intentVeiled) return 'Something is gathering that you cannot read.';
    final exact = f.cls == HeroClass.sage;
    final dmg = exact && f.intentDamage > 0 ? ' (${f.intentDamage})' : '';
    return switch (f.intent) {
      EnemyIntent.hit => 'It means to hit you$dmg.',
      EnemyIntent.hitCompanion => f.taunt > 0 || f.companionHp <= 0
          ? 'It means to hit you$dmg.'
          : 'It is eyeing $companion$dmg.',
      EnemyIntent.heavy => 'A heavy blow is coming for you$dmg. Defend halves it.',
      EnemyIntent.charge => 'It is winding up. The big blow comes next turn.',
      EnemyIntent.big => 'The big blow lands this turn$dmg. Defend halves it.',
      EnemyIntent.fortify => 'It means to settle in and mend.',
      EnemyIntent.hex =>
        'It is weaving a hex. Defend, or your next blow is halved.',
      EnemyIntent.ward => 'It is raising a ward that will swallow one blow.',
      EnemyIntent.swarm => 'They all come at you at once$dmg.',
      EnemyIntent.swarmCompanion => 'They come at you, and one at $companion$dmg.',
      EnemyIntent.swarmAll => 'They are massing to rush you all together$dmg. '
          'Defend halves it.',
    };
  }

  Widget _enemyBlock(Fight f, String companion) {
    final states = <String>[
      if (f.bodies.length > 1) '${f.bodiesUp} of ${f.bodies.length} up',
      if (f.armoured) 'Thick hide',
      if (f.ward) 'Warded',
      if (f.trap > 0) 'Trapped (${f.trap})',
      if (f.boss) 'Phase ${f.bossPhase} of 3',
    ];
    final turnsLeft = f.turnLimit - f.turn + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _portrait(52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _capName,
                      maxLines: 1,
                      style: AppText.cardTitle
                          .copyWith(color: Palette.onDark, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Bar(
                    value: f.enemyHp,
                    max: f.enemyMax,
                    color: Palette.stillGrey,
                    label: '${f.enemyHp} / ${f.enemyMax}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          <String>[
            _type.label,
            ...states,
            'Turn ${f.turn}${f.boss ? ' · $turnsLeft left' : ''}',
          ].join(' · '),
          style: AppText.small.copyWith(color: Palette.onDarkSoft, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(
            color: Palette.forestNight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.gold.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ITS NEXT MOVE',
                style: AppText.label.copyWith(color: Palette.goldBright),
              ),
              const SizedBox(height: 3),
              Text(
                _intentLine(f, companion),
                style: AppText.body.copyWith(color: Palette.onDark, fontSize: 14.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partyBlock(Fight f, GameController game) {
    final hero = game.hero!;
    final companion = game.companion!;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            HeroPortrait(portraitId: hero.portraitId, size: 34, frame: game.frame),
            const SizedBox(width: 10),
            Expanded(
              child: _Bar(
                value: f.heroHp,
                max: f.heroMax,
                color: Palette.gold,
                label: 'You ${f.heroHp} / ${f.heroMax}'
                    '${f.shield > 0 ? ' · Shield ${f.shield}' : ''}'
                    '${f.dimmed ? ' · hexed' : ''}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            CompanionPortrait(kind: companion.kind, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: _Bar(
                value: f.companionHp,
                max: f.companionMax,
                color: Palette.companion,
                label: f.companionHp > 0
                    ? '${companion.name} ${f.companionHp} / ${f.companionMax}'
                    : '${companion.name} is winded',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _logBlock() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Palette.forestNight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: _log.length,
          itemBuilder: (context, i) {
            final line = _log[_log.length - 1 - i];
            final turn = line.startsWith('TURN ');
            return Padding(
              padding: EdgeInsets.only(top: turn ? 6 : 1),
              child: Text(
                line,
                style: turn
                    ? AppText.label.copyWith(color: Palette.goldBright)
                    : AppText.small
                        .copyWith(color: Palette.onDark, fontSize: 13),
              ),
            );
          },
        ),
      );

  Widget _actions(Fight f, GameController game) {
    final cls = f.cls;
    final abilityNote = cls == HeroClass.sage
        ? 'All your ${cls.resource} (2 or more)'
        : '$abilityCost ${cls.resource}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${cls.resource} ${f.resource} / $resourceCap',
                style: AppText.cardTitle
                    .copyWith(color: Palette.goldBright, fontSize: 14),
              ),
            ),
            if (f.companionHp > 0)
              ChoicePill(
                label: f.companionReady
                    ? '${game.companionName} joins in'
                    : '${game.companionName}: next turn',
                selected: _companionOn && f.companionReady,
                color: Palette.companion,
                icon: 'paw',
                onTap: () {
                  if (!f.companionReady) return;
                  setState(() => _companionOn = !_companionOn);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionTile(
                title: 'Strike',
                note: '${f.strikeDamage} · lands ${f.heroStrikeChance}%',
                icon: 'compass',
                onTap: _busy ? null : () => _act(CombatAction.strike),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                title: cls.ability,
                note: abilityNote,
                icon: classIcon(cls),
                strong: true,
                onTap: _busy || !f.canAbility
                    ? null
                    : () => _act(CombatAction.ability),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: _ActionTile(
                title: 'Defend',
                note: 'Halve it · +1 ${cls.resource}',
                icon: 'frame',
                onTap: _busy ? null : () => _act(CombatAction.defend),
              ),
            ),
            const SizedBox(width: 8),
            for (final kind in ItemKind.values) ...<Widget>[
              Expanded(
                flex: 2,
                child: _ItemTile(
                  kind: kind,
                  count: f.count(kind),
                  onTap: _busy || f.count(kind) == 0
                      ? null
                      : () => _act(kind.action),
                ),
              ),
              if (kind != ItemKind.values.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _fighting(BuildContext context) {
    final game = GameScope.of(context);
    final f = _fight!;
    final heading = _heading(
      widget.boss
          ? 'THE WEEKLY DELVE'
          : (f.heroic ? 'TODAY’S ENCOUNTER · HEROIC' : 'TODAY’S ENCOUNTER'),
      close: false,
    );
    if (isExpanded(context)) {
      return TwoPane(
        start: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              heading,
              const SizedBox(height: 12),
              _enemyBlock(f, game.companionName),
              const Spacer(),
              _partyBlock(f, game),
            ],
          ),
        ),
        end: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _logBlock()),
              const SizedBox(height: 10),
              _actions(f, game),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          heading,
          const SizedBox(height: 8),
          _enemyBlock(f, game.companionName),
          const SizedBox(height: 8),
          _partyBlock(f, game),
          const SizedBox(height: 8),
          Expanded(child: _logBlock()),
          const SizedBox(height: 8),
          _actions(f, game),
        ],
      ),
    );
  }

  // ---- How it came out --------------------------------------------------

  Widget _result(BuildContext context) {
    final game = GameScope.of(context);
    final f = _fight!;
    final cls = f.cls;
    final won = f.outcome == FightOutcome.won;
    final String title;
    final List<String> lines;
    final List<String> gains;
    if (widget.boss) {
      final out = _bossOutcome;
      if (out != null && out.woken) {
        title = '$_name wakes';
        lines = <String>[
          'It took the whole of it, and it is done. The stillness over '
              '${regionByKey(out.boss.region).name} lifts.',
        ];
        gains = <String>[
          '+$bossGold gold',
          '+$bossEachMaterial each of Timber, Stone and Star Shards',
          if (out.title != null) 'A title: ${out.title}',
        ];
      } else {
        final left = out?.left ?? f.enemyHp;
        title = '$_name held';
        lines = <String>[
          f.heroHp <= 0
              ? 'It wore you down on turn ${f.turn - 1}. You are back at '
                  'camp, whole, and so is ${game.companionName}.'
              : 'Seven turns were not enough this time.',
          'You took ${f.dealt} off it. It has $left of ${f.enemyMax} left, '
              'and that is where it will be next week.',
          'Next time: ${cls.plan}',
        ];
        gains = const <String>[];
      }
    } else if (won) {
      final chest = _outcome?.record.chest;
      title = '$_capName wakes';
      lines = <String>[
        'It blinks, shakes off the grey, and wanders away. The road is '
            'clear in ${f.turn} ${f.turn == 1 ? 'turn' : 'turns'}.',
      ];
      gains = chest == null
          ? const <String>[]
          : <String>[
              '+${chest.gold} gold',
              '+${chest.materials} ${chest.material.label}',
              'A ${chest.item.label} for the pouch',
              '+${chest.xp} XP each, for you and ${game.companionName}',
              'A Boss Mark (${_outcome?.marks ?? 0} in hand)',
            ];
    } else {
      // Amendment v0.3 §1: what happened in the fight and what to try
      // next. Nothing about the player's day.
      title = '$_capName held';
      lines = <String>[
        f.heroHp <= 0
            ? 'It held the road on turn ${f.turn - 1}. You are back at '
                'camp, whole, and so is ${game.companionName}.'
            : 'It outlasted you. You are back at camp, whole.',
        scoutLine(cls, _type),
        'Finish any quest for a Salve and another try today. The dice will '
            'fall the same way, so try a different plan. Or meet a new '
            'creature tomorrow.',
      ];
      gains = const <String>[];
    }

    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _heading(
          widget.boss ? 'THE WEEKLY DELVE' : 'TODAY’S ENCOUNTER',
          close: false,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            _portrait(72, awake: won),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style:
                    AppText.display.copyWith(color: Palette.onDark, fontSize: 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: AppText.body.copyWith(color: Palette.onDark),
            ),
          ),
      ],
    );
    final chestCard = gains.isEmpty
        ? const SizedBox.shrink()
        : ParchmentCard(
            edge: Palette.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.boss ? 'WHAT IT LEFT' : 'THE CHEST',
                  style: AppText.label.copyWith(color: Palette.goldDeep),
                ),
                const SizedBox(height: 6),
                for (final g in gains)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 3, right: 8),
                          child: VIcon('star', size: 13, color: Palette.goldDeep),
                        ),
                        Expanded(
                          child: Text(
                            g,
                            style: AppText.body.copyWith(color: Palette.slate),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    final leave = PrimaryButton(
      label: widget.boss ? 'Back to the fire' : 'Back to the board',
      icon: won ? 'sun' : null,
      onPressed: _leave,
    );

    if (isExpanded(context)) {
      return TwoPane(
        start: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
          children: <Widget>[head],
        ),
        end: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: SingleChildScrollView(child: chestCard)),
              const SizedBox(height: 10),
              leave,
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: <Widget>[head, const SizedBox(height: 6), chestCard],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: leave,
        ),
      ],
    );
  }
}

/// An HP bar with its numbers written on it.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.max,
    required this.color,
    required this.label,
  });

  final int value;
  final int max;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.small.copyWith(color: Palette.onDark, fontSize: 12.5),
        ),
        const SizedBox(height: 3),
        XpBar(
          fraction: fraction.toDouble(),
          color: color,
          track: Palette.onDark.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

/// One of the three main actions: large, and plainly off when it cannot be
/// used.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.note,
    required this.icon,
    required this.onTap,
    this.strong = false,
  });

  final String title;
  final String note;
  final String icon;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final fill = strong ? Palette.goldDeep : Palette.forest;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.gold.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: <Widget>[
                VIcon(icon, size: 22, color: Palette.goldBright),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: AppText.cardTitle
                              .copyWith(color: Palette.onDark, fontSize: 15.5),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          note,
                          maxLines: 1,
                          style: AppText.small.copyWith(
                            color: Palette.onDarkSoft,
                            fontSize: 11.5,
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
      ),
    );
  }
}

/// A consumable from the pouch, with how many are left.
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.kind, required this.count, required this.onTap});

  final ItemKind kind;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : 0.4,
      child: Material(
        color: Palette.forestDeep,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.onDark.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kind.label,
                    maxLines: 1,
                    style: AppText.small
                        .copyWith(color: Palette.onDark, fontSize: 11.5),
                  ),
                ),
                Text(
                  '$count',
                  style: AppText.cardTitle
                      .copyWith(color: Palette.goldBright, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
