import 'package:flutter/material.dart';

import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../board/board_screen.dart';
import '../celebrations.dart';
import '../health/health_note.dart';
import '../log/quest_log_screen.dart';
import '../map/map_panel.dart';
import '../party/party_sheet.dart';
import '../settings/settings_screen.dart';
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  GameController? _game;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _game?.removeListener(_onGame);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Marks the moments the app made by itself: a steps quest reaching its
  /// target, or being opened from Health Connect's "why" link.
  void _onGame() {
    final game = _game;
    if (!mounted || game == null || _marking) return;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final game = GameScope.read(context);
    if (state == AppLifecycleState.resumed) {
      // Coming back to the app may mean a new day has begun, more steps
      // walked, or a calendar that has changed.
      game.resumed();
    } else {
      // Leaving: commit anything still inside its Undo window.
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
          child: expanded ? _expanded() : _compact(),
        ),
      ),
      bottomNavigationBar: expanded
          ? null
          : _BottomNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
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
          child: _Rail(
            index: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
        ),
        Expanded(child: page),
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
