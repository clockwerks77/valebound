import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../board/board_screen.dart';
import '../celebrations.dart';
import '../encounter/class_choice.dart';
import '../feel.dart';
import '../health/health_note.dart';
import '../log/quest_log_screen.dart';
import '../map/map_panel.dart';
import '../motion.dart';
import '../party/party_sheet.dart';
import '../settings/settings_screen.dart';
import '../story/story.dart';
import '../tour/tour.dart';
import '../tour/tours.dart';
import '../widgets/v_icon.dart';

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final String icon;
}

/// DESIGN §9.1: Board, Map, Character, Log.
const List<_Destination> _destinations = <_Destination>[
  _Destination('Board', 'board'),
  _Destination('Map', 'map'),
  _Destination('Character', 'party'),
  _Destination('Log', 'log'),
];

const double railWidth = 68;

/// The frame around every screen.
///
/// * Cover screen (compact): one column with bottom navigation.
/// * Opened Fold (expanded): a slim rail and two panes that meet at the
///   crease: Board + Map, hero + companion, Log list + detail.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;
  GameController? _game;
  bool _marking = false;
  bool _touring = false;
  Timer? _healthTimer;

  /// Plays as a destination is chosen: the new screen fades up into place.
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: Motion.standard,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchHealth();
  }

  /// While the app is in front, Health Connect is read again every few
  /// minutes, so steps and glucose keep up without leaving and returning.
  void _watchHealth() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      GameController.healthRefreshEvery,
      (_) => _game?.refreshHealth(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      _game = GameScope.read(context)..addListener(_onGame);
      // Anything that happened while the app was opening.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onGame());
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _arrive.dispose();
    _game?.removeListener(_onGame);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Marks the moments the app made by itself: a steps quest reaching its
  /// target, or being opened from Health Connect's "why" link.
  void _onGame() {
    final game = _game;
    if (!mounted || game == null) return;
    // The prologue, told once; then the tour of the board, on the first
    // run and whenever it is asked for again.
    if (!_touring && game.hasProfile) {
      final prologue = game.takePrologueRequest();
      final tour = game.takeTourRequest();
      // A hero with no class yet, new or from before 0.7, chooses one
      // (Amendment v0.3 §2).
      final choose = game.needsClass;
      if (prologue || tour || choose) {
        _touring = true;
        _welcome(prologue: prologue, tour: tour, chooseClass: choose);
      }
    }
    if (_marking) return;
    final done = game.takeAutoCompletions();
    final reason = game.launchReason;
    if (done.isEmpty && reason == null) return;
    game.launchReason = null;
    _marking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        for (final auto in done) {
          if (!navigator.mounted) return;
          await celebrate(navigator.context, auto.outcome, questId: auto.questId);
        }
        if (reason == 'health_rationale' && navigator.mounted) {
          await showHealthNote(navigator.context);
        }
      } finally {
        _marking = false;
      }
    });
  }

  /// Tells the prologue (DECISIONS D-76), then walks the board with a
  /// bubble on each part (DECISIONS D-72). Either may be asked for alone.
  Future<void> _welcome({
    required bool prologue,
    required bool tour,
    bool chooseClass = false,
  }) async {
    final game = _game;
    try {
      if (!mounted || game == null) return;
      if (_index != 0) setState(() => _index = 0);
      await WidgetsBinding.instance.endOfFrame;
      if (prologue) {
        if (!mounted) return;
        await showPrologue(context, companionName: game.companionName);
        await game.finishPrologue();
      }
      if (chooseClass) {
        if (!mounted) return;
        await showClassChoice(context, mustChoose: true);
      }
      if (tour) {
        if (!mounted) return;
        await runTour(
          context,
          boardTour(game.companionName),
          leaveLabel: 'Skip the tour',
        );
        await game.finishTour();
      }
    } finally {
      _touring = false;
    }
  }

  /// Moves to a destination and, the first time, says what it is.
  void _select(int index) {
    if (index != _index) {
      Feel.tap();
      if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
        _arrive.forward(from: 0);
      }
    }
    setState(() => _index = index);
    final hint = switch (index) {
      1 => HintId.map,
      2 => HintId.party,
      3 => HintId.log,
      _ => null,
    };
    if (hint == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showHintOnce(context, hint);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final game = GameScope.read(context);
    if (state == AppLifecycleState.resumed) {
      // Coming back to the app may mean a new day has begun, more steps
      // walked, or a calendar that has changed.
      game.resumed();
      _watchHealth();
    } else {
      // Leaving: commit anything still inside its Undo window, and stop
      // asking Health Connect until the app is back in front.
      _healthTimer?.cancel();
      _healthTimer = null;
      game.flushPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = isExpanded(context);
    return Scaffold(
      backgroundColor: Palette.forestDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Palette.forest, Palette.forestDeep, Palette.forestNight],
            stops: <double>[0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: expanded,
          child: expanded ? _expanded() : _arriving(_compact()),
        ),
      ),
      bottomNavigationBar: expanded
          ? null
          : KeyedSubtree(
              key: TourMark.nav,
              child: _BottomNav(index: _index, onSelect: _select),
            ),
    );
  }

  /// [child], fading up a few pixels whenever a destination is chosen.
  Widget _arriving(Widget child) {
    final curved = CurvedAnimation(parent: _arrive, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  Widget _compact() {
    return IndexedStack(
      index: _index,
      children: const <Widget>[
        BoardScreen(),
        MapPanel(),
        PartySheetScreen(),
        QuestLogScreen(),
      ],
    );
  }

  Widget _expanded() {
    final Widget page = switch (_index) {
      0 => const TwoPane(
          leadingInset: railWidth,
          start: BoardScreen(),
          end: MapPanel(brief: true),
        ),
      1 => const TwoPane(
          leadingInset: railWidth,
          start: MapPane(),
          end: MapDetails(),
        ),
      2 => const PartySheetScreen(leadingInset: railWidth),
      _ => const QuestLogScreen(leadingInset: railWidth),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: railWidth,
          child: KeyedSubtree(
            key: TourMark.nav,
            child: _Rail(index: _index, onSelect: _select),
          ),
        ),
        Expanded(child: _arriving(page)),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.forestNight,
        border: Border(
          top: BorderSide(color: Palette.gold.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.forestNight.withValues(alpha: 0.7),
        border: Border(
          right: BorderSide(color: Palette.gold.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 14),
          for (var i = 0; i < _destinations.length; i++)
            SizedBox(
              height: 72,
              child: _NavItem(
                destination: _destinations[i],
                selected: i == index,
                onTap: () => onSelect(i),
              ),
            ),
          const Spacer(),
          SizedBox(
            height: 64,
            child: _NavItem(
              destination: const _Destination('Settings', 'settings'),
              selected: false,
              onTap: () => openSettings(context),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.goldBright : Palette.onDarkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? Palette.gold.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: VIcon(destination.icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
