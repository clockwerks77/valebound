import 'package:flutter/material.dart';

import '../../rules/narrator.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../art/painted.dart';
import '../art/vista.dart';
import '../feel.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// One page of story: a picture, and the narrator's words beneath it
/// (DECISIONS D-76).
class StoryLeaf {
  const StoryLeaf({
    required this.label,
    required this.text,
    required this.picture,
    this.title,
  });

  /// Small capitals over the page: "PROLOGUE", "CHAPTER ONE".
  final String label;

  /// A heading in the display serif, on the pages that open a chapter.
  final String? title;

  /// The narrator's words.
  final String text;
  final Widget picture;
}

/// The picture for a story page: the illustrated scene when there is one,
/// and a valley painted in code until then (ASSETS.md).
class StoryPicture extends StatelessWidget {
  const StoryPicture({super.key, required this.artKey, required this.wake});

  /// Key into [storyArt].
  final String artKey;

  /// How awake the code-drawn valley is, 0 (grey and asleep) to 1. Only
  /// used when the page has no painting.
  final double wake;

  /// The painting for this page, if it has one.
  String? get asset => storyArt[artKey];

  @override
  Widget build(BuildContext context) {
    final lantern = artKey == StoryScene.gateLantern.name;
    final fallback = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Vista(wake: wake),
        // The one lantern still burning, at the gate: beside the roofs,
        // where the village is, whatever shape the picture takes.
        if (lantern)
          LayoutBuilder(
            builder: (context, box) => Stack(
              children: <Widget>[
                Positioned(
                  left: box.maxWidth * 0.33 - _Glow.size / 2,
                  top: box.maxHeight * 0.69 - _Glow.size / 2,
                  child: const _Glow(),
                ),
              ],
            ),
          ),
      ],
    );
    final asset = this.asset;
    if (asset == null) return fallback;
    return ArtPicture(
      asset: asset,
      alignment: storyFocus(artKey),
      fallback: fallback,
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  static const double size = 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            Palette.goldBright.withValues(alpha: 0.85),
            Palette.gold.withValues(alpha: 0.28),
            Palette.gold.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.34, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: const VIcon('lantern', size: 30, color: Color(0xFFFFF6DC)),
    );
  }
}

/// How awake the valley looks behind each page of the prologue.
double _wakeFor(StoryScene scene) => switch (scene) {
      // First light on the hill, before the grey comes into view.
      StoryScene.lastHill => 0.9,
      StoryScene.sleepingVale => 0.0,
      StoryScene.gateLantern => 0.0,
      StoryScene.stillness => 0.0,
      StoryScene.road => 0.45,
    };

/// The prologue, then the page that opens Chapter One.
List<StoryLeaf> prologueLeaves(String companionName) {
  final first = chapters.first;
  return <StoryLeaf>[
    for (final page in prologuePages(companionName))
      StoryLeaf(
        label: 'PROLOGUE',
        text: page.text,
        picture: StoryPicture(
          artKey: page.scene.name,
          wake: _wakeFor(page.scene),
        ),
      ),
    StoryLeaf(
      label: first.label.toUpperCase(),
      title: first.regionName,
      text: first.opens,
      picture: StoryPicture(artKey: '${first.region}_asleep', wake: 0.1),
    ),
  ];
}

/// The pages for the moment a region's last place wakes: the chapter that
/// closes, and the one that opens after it.
List<StoryLeaf> chapterTurnLeaves(Chapter closed) {
  final next = chapterAfter(closed);
  return <StoryLeaf>[
    StoryLeaf(
      label: closed.label.toUpperCase(),
      title: next == null ? 'The Vale wakes' : '${closed.regionName} wakes',
      text: closed.wakes,
      picture: StoryPicture(artKey: '${closed.region}_awake', wake: 1),
    ),
    if (next != null)
      StoryLeaf(
        label: next.label.toUpperCase(),
        title: next.regionName,
        text: next.opens,
        picture: StoryPicture(artKey: '${next.region}_asleep', wake: 0.1),
      ),
  ];
}

/// Tells the prologue. Returns when it has been read to the end or left.
Future<void> showPrologue(
  BuildContext context, {
  required String companionName,
}) {
  return showStory(
    context,
    prologueLeaves(companionName),
    lastLabel: 'Begin',
    skipLabel: 'Skip',
  );
}

/// A chapter closes and the next one opens.
Future<void> showChapterTurn(BuildContext context, Chapter closed) {
  final last = chapterAfter(closed) == null;
  return showStory(
    context,
    chapterTurnLeaves(closed),
    lastLabel: last ? 'The Vale is awake' : 'Onward',
  );
}

/// Shows story pages one at a time, full screen, over everything.
Future<void> showStory(
  BuildContext context,
  List<StoryLeaf> leaves, {
  String lastLabel = 'Continue',
  String? skipLabel,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: motion(context, const Duration(milliseconds: 520)),
      reverseTransitionDuration:
          motion(context, const Duration(milliseconds: 380)),
      pageBuilder: (context, animation, secondary) => _StoryView(
        leaves: leaves,
        lastLabel: lastLabel,
        skipLabel: skipLabel,
      ),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// Between the picture and the words on the cover screen.
const double _plateGap = 18;

/// Room kept under the picture on the cover screen: a title and the five
/// lines of the longest page.
const double _wordsRoom = 204;

class _StoryView extends StatefulWidget {
  const _StoryView({
    required this.leaves,
    required this.lastLabel,
    required this.skipLabel,
  });

  final List<StoryLeaf> leaves;
  final String lastLabel;
  final String? skipLabel;

  @override
  State<_StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<_StoryView> {
  int _index = 0;
  bool _fetched = false;

  bool get _last => _index >= widget.leaves.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fetched) return;
    _fetched = true;
    // Have every page's painting ready before it is turned to.
    for (final leaf in widget.leaves) {
      final picture = leaf.picture;
      final asset = picture is StoryPicture ? picture.asset : null;
      if (asset != null) precacheImage(AssetImage(asset), context);
    }
  }

  void _next() {
    if (_last) {
      Navigator.of(context).maybePop();
      return;
    }
    Feel.tap();
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final leaf = widget.leaves[_index];
    final expanded = isExpanded(context);
    final skip = widget.skipLabel;

    final picture = AnimatedSwitcher(
      duration: motion(context, const Duration(milliseconds: 700)),
      child: KeyedSubtree(
        key: ValueKey<int>(_index),
        child: SizedBox.expand(child: leaf.picture),
      ),
    );

    final top = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            leaf.label,
            style: AppText.label.copyWith(color: Palette.goldBright),
          ),
        ),
        if (skip != null && !_last)
          QuietButton(
            label: skip,
            color: Palette.onDark,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ],
    );

    final words = AnimatedSwitcher(
      duration: motion(context, const Duration(milliseconds: 460)),
      switchInCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey<int>(_index),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leaf.title != null) ...<Widget>[
            Text(
              leaf.title!,
              style: AppText.display.copyWith(
                color: Palette.onDark,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            leaf.text,
            style: AppText.narrator.copyWith(
              color: Palette.onDark,
              fontSize: 21,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    final bottom = Row(
      children: <Widget>[
        Expanded(
          child: _Dots(count: widget.leaves.length, index: _index),
        ),
        PrimaryButton(
          label: _last ? widget.lastLabel : 'Continue',
          icon: _last ? 'sun' : null,
          onPressed: _next,
        ),
      ],
    );

    final Widget body;
    if (expanded) {
      // The opened Fold: the picture on one pane, the words on the other,
      // so nothing is read or pressed across the crease.
      body = SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TwoPane(
            start: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: picture,
            ),
            end: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  top,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(child: words),
                    ),
                  ),
                  bottom,
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // The cover screen: the picture as a plate above, the words beneath
      // it on the dark, so neither dims the other. The paintings are tall
      // (3:4). A screen with room shows one whole; a shorter screen keeps
      // room for the longest page of words and cuts the picture to its
      // subject.
      body = SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              top,
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final whole = box.maxWidth * 4 / 3;
                    final room = box.maxHeight - _plateGap - _wordsRoom;
                    final plate = room.clamp(120.0, whole).toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: plate,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: picture,
                          ),
                        ),
                        const SizedBox(height: _plateGap),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: words,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              bottom,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Palette.forestNight,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Palette.forestDeep, Palette.forestNight],
          ),
        ),
        child: body,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        children: <Widget>[
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: motion(context, const Duration(milliseconds: 260)),
              margin: const EdgeInsets.only(right: 6),
              width: i == index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == index
                    ? Palette.goldBright
                    : Palette.onDark.withValues(alpha: i < index ? 0.55 : 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
