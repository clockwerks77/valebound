import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/repository.dart';
import '../../rules/awards.dart';
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../celebrations.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// Completes a quest and plays whatever it earned.
Future<void> completeEntry(
  BuildContext context,
  BoardQuest entry, {
  String? note,
}) async {
  final game = GameScope.read(context);
  // The card that was tapped moves to "Done" and leaves the tree, so hold on
  // to the root navigator, which stays put.
  final navigator = Navigator.of(context, rootNavigator: true);
  final outcome = entry.quest.completionType == CompletionType.timer
      ? await game.completeTimer(entry)
      : await game.complete(entry.quest.id, note: note);
  if (outcome != null && navigator.mounted) {
    await celebrate(navigator.context, outcome);
  }
}

/// What a quest will award, in a few words.
String rewardLabel(QuestRow quest, String companionName) {
  final a = awardFor(difficulty: quest.difficulty, track: quest.track);
  return switch (quest.track) {
    Track.hero => '+${a.heroXp} XP',
    Track.companion => '$companionName +${a.companionXp} XP',
    Track.shared => '$companionName +${a.companionXp} · you +${a.heroXp}',
  };
}

/// The one-tap completion control. A gold ring that fills as it is pressed.
class CompleteButton extends StatefulWidget {
  const CompleteButton({
    super.key,
    required this.onComplete,
    required this.label,
    this.color = Palette.forest,
    this.size = 48,
  });

  final Future<void> Function() onComplete;
  final String label;
  final Color color;
  final double size;

  @override
  State<CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<CompleteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  bool _busy = false;

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _fill.forward();
    await widget.onComplete();
    if (mounted) {
      setState(() => _busy = false);
      _fill.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _press,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_fill.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      Colors.white.withValues(alpha: 0.55),
                      widget.color,
                      t,
                    ),
                    border: Border.all(
                      color: Color.lerp(Palette.goldDeep, Palette.gold, t)!,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: VIcon(
                      'check',
                      size: widget.size * 0.5,
                      color: Color.lerp(
                        Palette.goldDeep.withValues(alpha: 0.45),
                        Palette.goldBright,
                        t,
                      )!,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// − n/target + for count quests. Completes on reaching the target.
class CountStepper extends StatelessWidget {
  const CountStepper({super.key, required this.entry, this.large = false});

  final BoardQuest entry;
  final bool large;

  Future<void> _set(BuildContext context, int value) async {
    final game = GameScope.read(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final outcome = await game.setCount(entry, value);
    if (outcome != null && navigator.mounted) {
      await celebrate(navigator.context, outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = entry.quest.target ?? 0;
    final value = entry.banked;
    final button = large ? 48.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RoundIconButton(
          icon: 'minus',
          size: button,
          semanticLabel: 'One fewer for ${entry.quest.name}',
          background: Colors.white.withValues(alpha: 0.55),
          foreground: Palette.slate,
          edge: Palette.parchmentEdge,
          onPressed: value <= 0 ? null : () => _set(context, value - 1),
        ),
        SizedBox(
          width: large ? 84 : 58,
          child: Text(
            target > 0 ? '$value / $target' : '$value',
            textAlign: TextAlign.center,
            style: AppText.number.copyWith(
              color: Palette.slate,
              fontSize: large ? 26 : 17,
            ),
          ),
        ),
        RoundIconButton(
          icon: 'plus',
          size: button,
          semanticLabel: 'One more for ${entry.quest.name}',
          onPressed: () => _set(context, value + 1),
        ),
      ],
    );
  }
}

/// Rebuilds once a second while [active], for running timers.
class SecondsTicker extends StatefulWidget {
  const SecondsTicker({
    super.key,
    required this.active,
    required this.builder,
    this.onTick,
  });

  final bool active;
  final WidgetBuilder builder;
  final VoidCallback? onTick;

  @override
  State<SecondsTicker> createState() => _SecondsTickerState();
}

class _SecondsTickerState extends State<SecondsTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SecondsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        widget.onTick?.call();
      });
    } else if (!widget.active && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Start/pause and the running clock for a timer quest. When the target is
/// reached the quest completes itself.
class TimerControl extends StatefulWidget {
  const TimerControl({super.key, required this.entry, this.large = false});

  final BoardQuest entry;
  final bool large;

  @override
  State<TimerControl> createState() => _TimerControlState();
}

class _TimerControlState extends State<TimerControl> {
  bool _completing = false;

  void _checkTarget() {
    final entry = widget.entry;
    final target = entry.timerTargetSeconds;
    if (_completing || target <= 0 || entry.isDone) return;
    final game = GameScope.read(context);
    if (entry.timerSeconds(game.now) >= target) {
      _completing = true;
      completeEntry(context, entry);
    }
  }

  @override
  void initState() {
    super.initState();
    // A timer may have reached its target while the app was closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.entry.timerRunning) _checkTarget();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final running = entry.timerRunning;
    return SecondsTicker(
      active: running,
      onTick: _checkTarget,
      builder: (context) {
        final game = GameScope.read(context);
        final seconds = entry.timerSeconds(game.now);
        final target = entry.timerTargetSeconds;
        final clock = target > 0
            ? '${formatClock(seconds)} / ${formatClock(target)}'
            : formatClock(seconds);
        final button = RoundIconButton(
          icon: running ? 'pause' : 'play',
          size: widget.large ? 64 : 44,
          semanticLabel: running
              ? 'Pause ${entry.quest.name}'
              : 'Start ${entry.quest.name}',
          background: running ? Palette.goldDeep : Palette.forest,
          onPressed: () => running
              ? game.pauseTimer(entry.quest.id)
              : game.startTimer(entry.quest.id),
        );
        final text = Text(
          clock,
          style: AppText.number.copyWith(
            color: Palette.slate,
            fontSize: widget.large ? 30 : 14.5,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        );
        if (widget.large) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[text, const SizedBox(height: 14), button],
          );
        }
        // On a card: the button with a short reading beneath it, so the
        // quest's name keeps its room.
        final idle = !running && seconds == 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            button,
            const SizedBox(height: 3),
            Text(
              idle ? '${entry.quest.target ?? 0} min' : formatClock(seconds),
              style: AppText.small.copyWith(
                color: Palette.slateSoft,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
