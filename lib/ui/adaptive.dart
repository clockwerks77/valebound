import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Layout by window size class, never by device model (DESIGN §9.1).
///
/// * Compact, under 600dp wide: the Fold's cover screen. Single column.
/// * Expanded, 600dp and up: the opened Fold. Two panes.
const double expandedBreakpoint = 600;

/// Clear space kept on each side of the display crease.
const double creasePadding = 12;

/// Gutter between the two panes when there is no crease.
const double paneGutter = 24;

bool isExpanded(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= expandedBreakpoint;

/// The vertical fold or hinge that splits the screen left/right, if any.
Rect? verticalCrease(BuildContext context) {
  final media = MediaQuery.of(context);
  return creaseIn(media.displayFeatures, media.size);
}

Rect? creaseIn(List<DisplayFeature> features, Size size) {
  for (final f in features) {
    final splits = f.type == DisplayFeatureType.fold ||
        f.type == DisplayFeatureType.hinge;
    if (!splits) continue;
    final b = f.bounds;
    final spansHeight = b.top <= 0.5 && b.bottom >= size.height - 0.5;
    final insideWidth = b.left > 0 && b.right < size.width;
    if (spansHeight && insideWidth) return b;
  }
  return null;
}

/// The strip around the crease that must stay free of anything critical.
Rect? creaseKeepOut(BuildContext context) {
  final crease = verticalCrease(context);
  if (crease == null) return null;
  return Rect.fromLTRB(
    crease.left - creasePadding,
    crease.top,
    crease.right + creasePadding,
    crease.bottom,
  );
}

/// Two panes side by side, split exactly at the display crease when there is
/// one, so no primary action, XP bar or button ever sits on it.
///
/// [leadingInset] is the width of anything to the left of this widget (the
/// navigation rail), so the split still lands on the physical crease.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.start,
    required this.end,
    this.leadingInset = 0,
  });

  final Widget start;
  final Widget end;
  final double leadingInset;

  @override
  Widget build(BuildContext context) {
    final crease = verticalCrease(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        double startWidth;
        double gap;
        if (crease != null) {
          startWidth = crease.left - creasePadding - leadingInset;
          gap = crease.width + creasePadding * 2;
        } else {
          gap = paneGutter;
          startWidth = (constraints.maxWidth - gap) / 2;
        }
        final maxStart = constraints.maxWidth - gap;
        if (startWidth > maxStart) startWidth = maxStart;
        if (startWidth < 0) startWidth = 0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: startWidth, child: start),
            SizedBox(width: gap),
            Expanded(child: end),
          ],
        );
      },
    );
  }
}

/// Keeps a dialog, sheet or toast entirely on one side of the crease.
///
/// Flutter's own dialogs only step aside for a hinge that has width or is
/// half-folded; a Fold lying flat reports a zero-width fold, and a centred
/// dialog would put its buttons right on it. This confines [child] to the
/// start pane (or the end pane) whenever a vertical crease is present.
class CreaseAware extends StatelessWidget {
  const CreaseAware({super.key, required this.child, this.preferEnd = false});

  final Widget child;
  final bool preferEnd;

  @override
  Widget build(BuildContext context) {
    final crease = verticalCrease(context);
    if (crease == null) return child;
    final width = MediaQuery.sizeOf(context).width;
    final padding = preferEnd
        ? EdgeInsets.only(left: crease.right + creasePadding)
        : EdgeInsets.only(right: width - crease.left + creasePadding);
    return Padding(padding: padding, child: child);
  }
}

/// Horizontal centre of the start pane, or of the screen without a crease.
double startPaneCentre(BuildContext context) {
  final crease = verticalCrease(context);
  final width = MediaQuery.sizeOf(context).width;
  return crease == null ? width / 2 : (crease.left - creasePadding) / 2;
}
