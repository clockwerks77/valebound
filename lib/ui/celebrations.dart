import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../rules/companion_rules.dart';
import '../rules/daily_still.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/journey.dart';
import '../rules/progression.dart';
import '../rules/still.dart';
import '../rules/world.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'adaptive.dart';
import 'art/crests.dart';
import 'art/painted.dart';
import 'widgets/common.dart';
import 'widgets/v_icon.dart';

/// Everything that should happen on screen after a quest is completed:
/// the reward chips, then any level-up or Discovery moment, one at a time.
///
/// [questId] names the quest just finished, so a Heroic or Boss quest can
/// wake its Still creature.
Future<void> celebrate(
  BuildContext context,
  CompletionOutcome outcome, {
  String? questId,
}) async {
  final game = GameScope.read(context);
  final companion = game.companion;
  final hero = game.hero;
  showRewardToast(
    context,
    outcome,
    companionName: game.companionName,
    still: questId != null && outcome.clearsStill ? stillFor(questId) : null,
    dailyStill: outcome.wokeDailyStill ? dailyStillFor(game.day) : null,
  );

  for (final index in outcome.newRestorationIndexes) {
    if (!context.mounted) return;
    await showRestoration(context, target: targetAt(index));
  }

  if (outcome.heroLevelledUp && hero != null && context.mounted) {
    await showHeroLevelUp(
      context,
      hero: hero,
      level: outcome.after.heroLevel,
    );
  }
  if (outcome.companionLevelledUp && companion != null && context.mounted) {
    await showCompanionLevelUp(
      context,
      companion: companion,
      level: outcome.after.companionLevel,
      bondBonus: outcome.bondBonus,
    );
  }
  for (final index in outcome.newDiscoveryIndexes) {
    if (!context.mounted) return;
    await showDiscovery(
      context,
      scene: sceneFor(index),
      number: index + 1,
      companion: companion,
    );
  }
}

// ---- Reward chips -------------------------------------------------------

class _Reward {
  const _Reward(this.icon, this.text, this.color);
  final String icon;
  final String text;
  final Color color;
}

List<_Reward> _rewardsFor(
  CompletionOutcome o,
  String companionName,
  StillCreature? still,
  StillCreature? dailyStill,
) {
  final a = o.award;
  return <_Reward>[
    if (still != null) _Reward('still', still.wakes, Palette.slateSoft),
    // The day's creature, woken by the third quest (DECISIONS D-70).
    if (dailyStill != null && o.dailyStillGift != null)
      _Reward(
        'still',
        'The ${dailyStill.name} woke: +${o.stillGiftGold} gold, '
            '+$dailyStillMaterials ${o.dailyStillGift!.label}',
        Palette.goldDeep,
      ),
    if (o.heroXpGained > 0)
      _Reward(
        attributeIcon(o.attribute),
        '+${o.heroXpGained} XP · ${o.attribute.label}',
        Palette.attribute(o.attribute),
      ),
    if (a.companionXp > 0)
      _Reward('paw', '$companionName +${a.companionXp} XP', Palette.companion),
    if (o.totalBond > 0)
      _Reward('bond', '+${o.totalBond} Bond', Palette.companionDeep),
    if (a.paces > 0)
      _Reward(
        'pace',
        a.paces == 1 ? '+1 Pace' : '+${a.paces} Paces',
        Palette.moss,
      ),
    if (a.materials > 0 && o.materialKind != null)
      _Reward(
        materialIcon(o.materialKind!),
        '+${a.materials} ${o.materialKind!.label}',
        Palette.material(o.materialKind!),
      ),
    if (o.sniffOutFound != null)
      _Reward(
        materialIcon(o.sniffOutFound!),
        '$companionName found 1 ${o.sniffOutFound!.label}',
        Palette.companion,
      ),
    if (o.fetchCarried != null)
      _Reward(
        materialIcon(o.fetchCarried!),
        '$companionName fetched 1 ${o.fetchCarried!.label}',
        Palette.companion,
      ),
    if (a.gold > 0) _Reward('coin', '+${a.gold} gold', Palette.goldDeep),
    for (final key in o.newGear)
      if (gearByKey(key) != null)
        _Reward(
          gearByKey(key)!.icon,
          'A gift for $companionName: ${gearByKey(key)!.name}',
          Palette.companionDeep,
        ),
    for (final key in o.newCosmetics)
      if (cosmeticByKey(key) != null)
        _Reward('star', 'New: ${cosmeticByKey(key)!.name}', Palette.goldDeep),
  ];
}

/// Shows the rewards for a moment near the bottom of the screen, clear of
/// the display crease, then lets them drift away.
void showRewardToast(
  BuildContext context,
  CompletionOutcome outcome, {
  required String companionName,
  StillCreature? still,
  StillCreature? dailyStill,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _RewardToast(
      rewards: _rewardsFor(outcome, companionName, still, dailyStill),
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _RewardToast extends StatefulWidget {
  const _RewardToast({required this.rewards, required this.onDone});

  final List<_Reward> rewards;
  final VoidCallback onDone;

  @override
  State<_RewardToast> createState() => _RewardToastState();
}

class _RewardToastState extends State<_RewardToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        // Stay within one side of a folded display.
        child: CreaseAware(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                media.padding.bottom + 96,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final appear = Curves.easeOutBack.transform(
                    (t / 0.16).clamp(0.0, 1.0),
                  );
                  final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2);
                  final rise = -28 * Curves.easeOut.transform(t);
                  return Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, rise + 18 * (1 - appear)),
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * appear,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final r in widget.rewards) _RewardChip(r),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip(this.reward);

  final _Reward reward;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.parchment,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Palette.gold, width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.forestNight.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            VIcon(reward.icon, size: 17, color: reward.color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                reward.text,
                style: AppText.small.copyWith(
                  color: Palette.slate,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Level-up: hero (full-screen fanfare) -------------------------------

Future<void> showHeroLevelUp(
  BuildContext context, {
  required CharacterRow hero,
  required int level,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Level up',
    barrierColor: Palette.forestNight.withValues(alpha: 0.975),
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (context, _, _) => _Fanfare(
      rayColor: Palette.goldBright,
      portrait: HeroPortrait(portraitId: hero.portraitId, size: 132),
      eyebrow: 'LEVEL UP',
      headline: 'Level $level',
      line: titleUnlockedAt(level) != null
          ? '${hero.name} earns the title ${titleUnlockedAt(level)}.'
          : 'Well travelled, ${hero.name}. The Vale is brighter for it.',
      button: 'Onward',
    ),
  );
}

// ---- Level-up: companion (smaller fanfare) ------------------------------

Future<void> showCompanionLevelUp(
  BuildContext context, {
  required CompanionRow companion,
  required int level,
  required int bondBonus,
}) {
  final Trick? trick =
      companionTricks.where((t) => t.level == level).firstOrNull;
  return showDialog<void>(
    context: context,
    barrierColor: Palette.forestNight.withValues(alpha: 0.78),
    builder: (context) => CreaseAware(
      child: Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Bounce(child: CompanionPortrait(kind: companion.kind, size: 96)),
              const SizedBox(height: 14),
              Text(
                '${companion.name} reached level $level',
                textAlign: TextAlign.center,
                style: AppText.heading.copyWith(color: Palette.slate),
              ),
              const SizedBox(height: 8),
              if (trick != null) ...<Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const VIcon('trick', size: 18, color: Palette.companion),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'New trick: ${trick.name}',
                        style: AppText.cardTitle.copyWith(
                          color: Palette.companionDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trick.description,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
              ] else
                Text(
                  'A small goal at a time, and look how far you have come '
                  'together.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
              if (bondBonus > 0) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '+$bondBonus Bond for a day of growing',
                  style: AppText.small.copyWith(color: Palette.companionDeep),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Good ${companion.kind == CompanionKind.clockworkSprite ? 'sprite' : 'friend'}',
                color: Palette.companion,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
      ),
    ),
  );
}

// ---- Restoration: the map moment ----------------------------------------

/// A place wakes (DESIGN §3A): shown once, when the materials for it are in.
Future<void> showRestoration(
  BuildContext context, {
  required RestorationTarget target,
}) {
  final villager = target.villager;
  return showDialog<void>(
    context: context,
    barrierColor: Palette.forestNight.withValues(alpha: 0.78),
    builder: (context) => CreaseAware(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Bounce(
                  child: Roundel(
                    icon: villager?.icon ?? 'lantern',
                    color: Palette.forest,
                    size: 76,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'RESTORED · ${regionByKey(target.region).name.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(color: Palette.goldDeep),
                ),
                const SizedBox(height: 6),
                Text(
                  target.name,
                  textAlign: TextAlign.center,
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 8),
                Text(
                  target.wakes,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                if (villager != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    '${villager.name} the ${villager.role.toLowerCase()} has '
                    'come home.',
                    textAlign: TextAlign.center,
                    style: AppText.small.copyWith(color: Palette.moss),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'The Vale wakes',
                  icon: 'sun',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---- Discovery card -----------------------------------------------------

Future<void> showDiscovery(
  BuildContext context, {
  required DiscoveryScene scene,
  required int number,
  CompanionRow? companion,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Palette.forestNight.withValues(alpha: 0.78),
    builder: (context) => CreaseAware(
      child: Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (DiscoveryPicture.exists(scene.key))
                DiscoveryPicture(sceneKey: scene.key)
              else
                const Roundel(icon: 'lantern', color: Palette.goldDeep, size: 72),
              const SizedBox(height: 12),
              Text(
                'DISCOVERY $number',
                style: AppText.label.copyWith(color: Palette.goldDeep),
              ),
              const SizedBox(height: 6),
              Text(
                scene.title,
                textAlign: TextAlign.center,
                style: AppText.heading.copyWith(color: Palette.slate),
              ),
              const SizedBox(height: 8),
              Text(
                scene.line,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: Palette.slateSoft),
              ),
              if (companion != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Found on the road with ${companion.name}.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: Palette.companionDeep),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Mark it with a lantern',
                icon: 'lantern',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
      ),
    ),
  );
}

// ---- Shared pieces ------------------------------------------------------

class _Fanfare extends StatefulWidget {
  const _Fanfare({
    required this.rayColor,
    required this.portrait,
    required this.eyebrow,
    required this.headline,
    required this.line,
    required this.button,
  });

  final Color rayColor;
  final Widget portrait;
  final String eyebrow;
  final String headline;
  final String line;
  final String button;

  @override
  State<_Fanfare> createState() => _FanfareState();
}

class _FanfareState extends State<_Fanfare> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _spin.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_spin, _enter]),
              builder: (context, _) => CustomPaint(
                painter: _RaysPainter(
                  angle: _spin.value * math.pi * 2,
                  reveal: Curves.easeOutCubic.transform(_enter.value),
                  color: widget.rayColor,
                  centreX: startPaneCentre(context),
                ),
              ),
            ),
            CreaseAware(
              child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _enter,
                          curve: Curves.elasticOut,
                        ),
                        child: widget.portrait,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.eyebrow,
                        style: AppText.label.copyWith(
                          color: Palette.goldBright,
                          fontSize: 13,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.headline,
                        textAlign: TextAlign.center,
                        style: AppText.display.copyWith(
                          color: Palette.onDark,
                          fontSize: 46,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.line,
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(
                          color: Palette.onDarkSoft,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 26),
                      PrimaryButton(
                        label: widget.button,
                        color: Palette.moss,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.angle,
    required this.reveal,
    required this.color,
    required this.centreX,
  });

  final double angle;
  final double reveal;
  final Color color;
  final double centreX;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(centreX, size.height * 0.36);
    final radius = size.longestSide * 0.9 * reveal;
    if (radius <= 0) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: 0.34),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a = angle + i * (math.pi * 2 / rays);
      const half = math.pi / rays * 0.42;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(a - half),
          center.dy + radius * math.sin(a - half),
        )
        ..lineTo(
          center.dx + radius * math.cos(a + half),
          center.dy + radius * math.sin(a + half),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    // Drifting motes of light.
    final mote = Paint();
    final random = math.Random(11);
    for (var i = 0; i < 36; i++) {
      final a = random.nextDouble() * math.pi * 2 + angle * (0.4 + random.nextDouble());
      final d = (0.12 + random.nextDouble() * 0.5) * size.shortestSide * reveal;
      final r = 1.0 + random.nextDouble() * 2.2;
      mote.color = color.withValues(alpha: 0.25 + random.nextDouble() * 0.5);
      canvas.drawCircle(
        Offset(center.dx + d * math.cos(a), center.dy + d * math.sin(a)),
        r,
        mote,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.reveal != reveal ||
      oldDelegate.centreX != centreX;
}

/// A single happy hop, played once.
class _Bounce extends StatelessWidget {
  const _Bounce({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, child) {
        final hop = math.sin(t * math.pi) * (1 - t) * 26;
        return Transform.translate(offset: Offset(0, -hop), child: child);
      },
      child: child,
    );
  }
}
