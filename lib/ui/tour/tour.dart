import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../widgets/common.dart';

/// The things on the board that the tour points at. The board wraps each in
/// a `KeyedSubtree` and knows nothing else about the tour.
abstract final class TourMark {
  static final GlobalKey party = GlobalKey(debugLabel: 'tour.party');
  static final GlobalKey restoring = GlobalKey(debugLabel: 'tour.restoring');
  static final GlobalKey road = GlobalKey(debugLabel: 'tour.road');
  static final GlobalKey sleeper = GlobalKey(debugLabel: 'tour.sleeper');
  static final GlobalKey quest = GlobalKey(debugLabel: 'tour.quest');
  static final GlobalKey companion = GlobalKey(debugLabel: 'tour.companion');
  static final GlobalKey campfire = GlobalKey(debugLabel: 'tour.campfire');
  static final GlobalKey newQuest = GlobalKey(debugLabel: 'tour.newQuest');
  static final GlobalKey tools = GlobalKey(debugLabel: 'tour.tools');
  static final GlobalKey nav = GlobalKey(debugLabel: 'tour.nav');
}

/// One bubble of a tour: what it says, and what it points at (nothing, for a
/// bubble that stands by itself).
class TourStep {
  const TourStep({required this.title, required this.body, this.target});

  final String title;
  final String body;
  final GlobalKey? target;
}

/// Shows [steps] one bubble at a time over whatever is on screen, dimming
/// everything but the thing each bubble points at. A step whose target is
/// not on the board today is passed over. Ends when the last bubble is
/// answered, or the tour is left early.
///
/// [doneLabel] is the button on the last bubble; [leaveLabel], when given,
/// is a quiet way out on every bubble but the last.
Future<void> runTour(
  BuildContext context,
  List<TourStep> steps, {
  String doneLabel = 'Done',
  String? leaveLabel,
}) {
  if (steps.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (context, _, _) => _TourView(
        steps: steps,
        doneLabel: doneLabel,
        leaveLabel: leaveLabel,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _TourView extends StatefulWidget {
  const _TourView({
    required this.steps,
    required this.doneLabel,
    required this.leaveLabel,
  });

  final List<TourStep> steps;
  final String doneLabel;
  final String? leaveLabel;

  @override
  State<_TourView> createState() => _TourViewState();
}

class _TourViewState extends State<_TourView> {
  int _index = 0;

  /// Where the current step's target sits on screen, once found.
  Rect? _target;

  /// False while a step's target is being scrolled into view.
  bool _ready = false;

  /// The list the board scrolls in, kept from the first target found, so a
  /// later target that is not built yet can be scrolled to.
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(0, 1));
  }

  /// Moves to step [index]. If its target is not on the board today, carries
  /// on in [direction] to the next one that is.
  Future<void> _show(int index, int direction) async {
    var i = index;
    while (i >= 0 && i < widget.steps.length) {
      final step = widget.steps[i];
      if (step.target == null) {
        _settle(i, null);
        return;
      }
      if (mounted) setState(() => _ready = false);
      final rect = await _find(step.target!);
      if (!mounted) return;
      if (rect != null) {
        _settle(i, rect);
        return;
      }
      i += direction;
    }
    if (!mounted) return;
    if (direction > 0) {
      // Nothing left to point at: the tour is over.
      Navigator.of(context).pop();
    } else {
      setState(() => _ready = true);
    }
  }

  void _settle(int index, Rect? rect) {
    if (!mounted) return;
    setState(() {
      _index = index;
      _target = rect;
      _ready = true;
    });
  }

  /// Brings [key]'s widget into view and returns where it is, or null when
  /// it is not on the board at all.
  Future<Rect?> _find(GlobalKey key) async {
    var found = key.currentContext;
    final scroll = _scroll;
    if (found == null && scroll != null && scroll.hasContentDimensions) {
      // Lists build only what is near the screen: look from the top down.
      scroll.jumpTo(scroll.minScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
      for (var hop = 0; hop < 24 && key.currentContext == null; hop++) {
        if (!mounted || !scroll.hasContentDimensions) return null;
        final next = scroll.pixels + scroll.viewportDimension * 0.7;
        if (scroll.pixels >= scroll.maxScrollExtent) break;
        scroll.jumpTo(
          next > scroll.maxScrollExtent ? scroll.maxScrollExtent : next,
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      found = key.currentContext;
    }
    if (found == null || !found.mounted) return null;
    _scroll ??= Scrollable.maybeOf(found)?.position;
    await Scrollable.ensureVisible(
      found,
      alignment: 0.3,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!found.mounted) return null;
    final box = found.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool get _last => _index == widget.steps.length - 1;

  void _next() {
    if (!_ready) return;
    if (_last) {
      Navigator.of(context).pop();
    } else {
      _show(_index + 1, 1);
    }
  }

  void _back() {
    if (!_ready || _index == 0) return;
    _show(_index - 1, -1);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final crease = creaseKeepOut(context);
    final hole = _ready ? _target?.inflate(6) : null;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          // The dimmed screen. It swallows taps, so nothing underneath can
          // be pressed by accident while a bubble is up.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _ScrimPainter(hole)),
            ),
          ),
          if (_ready)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _BubbleLayout(
                  target: _target,
                  crease: crease,
                  padding: media.padding,
                ),
                child: _Bubble(
                  key: ValueKey<int>(_index),
                  step: step,
                  count: widget.steps.length == 1
                      ? null
                      : '${_index + 1} of ${widget.steps.length}',
                  nextLabel: _last
                      ? widget.doneLabel
                      : (_index == 0 ? 'Show me' : 'Next'),
                  onNext: _next,
                  onBack: _index == 0 ? null : _back,
                  leaveLabel: _last ? null : widget.leaveLabel,
                  onLeave: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dims the screen and leaves a rounded window on the thing being shown.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Palette.forestNight.withValues(alpha: 0.78);
    final whole = Path()..addRect(Offset.zero & size);
    final window = hole;
    if (window == null) {
      canvas.drawPath(whole, scrim);
      return;
    }
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(18)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, whole, cut),
      scrim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.goldBright,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// Puts the bubble beside its target: below it when there is room, above it
/// otherwise, and always wholly on one side of the display crease.
class _BubbleLayout extends SingleChildLayoutDelegate {
  const _BubbleLayout({
    required this.target,
    required this.crease,
    required this.padding,
  });

  final Rect? target;

  /// The strip around the fold that must stay clear, if the screen has one.
  final Rect? crease;
  final EdgeInsets padding;

  static const double margin = 12;
  static const double gap = 14;
  static const double maxWidth = 340;

  /// Left and right edges of the pane the bubble belongs in.
  (double, double) _pane(Size size) {
    final keepOut = crease;
    if (keepOut == null) return (0, size.width);
    final onEnd = target != null && target!.center.dx > keepOut.center.dx;
    return onEnd ? (keepOut.right, size.width) : (0, keepOut.left);
  }

  /// Something as tall as the screen (the rail on the opened Fold) has no
  /// room above or below it, so the bubble stands beside it. This is the
  /// width there is for that, or null when the bubble goes above or below
  /// as usual.
  double? _besideRoom(Size size) {
    final aim = target;
    if (aim == null || aim.height <= size.height * 0.6) return null;
    final (_, right) = _pane(size);
    final room = right - margin - (aim.right + gap);
    return room >= 220 ? room : null;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final (left, right) = _pane(size);
    final room = _besideRoom(size) ?? right - left - margin * 2;
    final width = room < maxWidth ? room : maxWidth;
    final height = size.height - padding.vertical - margin * 2;
    return BoxConstraints(
      minWidth: width < 0 ? 0 : width,
      maxWidth: width < 0 ? 0 : width,
      maxHeight: height < 0 ? 0 : height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (left, right) = _pane(size);
    final top = padding.top + margin;
    final bottom = size.height - padding.bottom - margin;
    final aim = target;

    double clampX(double x) {
      final min = left + margin;
      final max = right - margin - childSize.width;
      if (max < min) return min;
      return x < min ? min : (x > max ? max : x);
    }

    if (aim == null) {
      return Offset(
        clampX((left + right - childSize.width) / 2),
        top + (bottom - top - childSize.height) / 2,
      );
    }
    final x = clampX(aim.center.dx - childSize.width / 2);
    final below = aim.bottom + gap;
    final above = aim.top - gap - childSize.height;
    final beside = aim.right + gap;
    if (_besideRoom(size) != null) {
      final middle = aim.center.dy - childSize.height / 2;
      final lowest = bottom - childSize.height;
      return Offset(
        beside,
        middle < top ? top : (middle > lowest ? lowest : middle),
      );
    }
    if (below + childSize.height <= bottom) return Offset(x, below);
    if (above >= top) return Offset(x, above);
    // No room above or below it: sit at the foot of the screen.
    final y = bottom - childSize.height;
    return Offset(x, y < top ? top : y);
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.target != target || old.crease != crease || old.padding != padding;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.step,
    required this.count,
    required this.nextLabel,
    required this.onNext,
    required this.onBack,
    required this.leaveLabel,
    required this.onLeave,
  });

  final TourStep step;
  final String? count;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final String? leaveLabel;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.parchment,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.gold, width: 1.4),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (count != null)
                  Text(
                    count!.toUpperCase(),
                    style: AppText.label.copyWith(color: Palette.goldDeep),
                  ),
                if (count != null) const SizedBox(height: 4),
                Text(
                  step.title,
                  style: AppText.title.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 6),
                Text(
                  step.body,
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    PrimaryButton(label: nextLabel, onPressed: onNext),
                    if (onBack != null)
                      QuietButton(label: 'Back', onPressed: onBack),
                    if (leaveLabel != null)
                      QuietButton(label: leaveLabel!, onPressed: onLeave),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
