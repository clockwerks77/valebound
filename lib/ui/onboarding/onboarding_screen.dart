import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../art/crests.dart';
import '../art/vista.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// First run: name the hero, choose a companion (DESIGN §7A.1), and meet the
/// starter quests.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _heroName = TextEditingController();
  final TextEditingController _companionName = TextEditingController();
  String _portrait = heroPortraits.first.id;
  CompanionKind? _kind;
  bool _fiveMinuteReset = false;
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _heroName.dispose();
    _companionName.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _heroName.text.trim().isNotEmpty,
        1 => _kind != null && _companionName.text.trim().isNotEmpty,
        _ => true,
      };

  /// The one-tap preset for this build: a hound named Babs.
  void _chooseBabs() {
    setState(() {
      _kind = CompanionKind.hound;
      _companionName.text = 'Babs';
    });
  }

  Future<void> _next() async {
    if (!_canContinue || _saving) return;
    FocusScope.of(context).unfocus();
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    await GameScope.read(context).createProfile(
      heroName: _heroName.text,
      portraitId: _portrait,
      companionName: _companionName.text,
      companionKind: _kind!,
      activateFiveMinuteReset: _fiveMinuteReset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = isExpanded(context);
    final form = _Form(
      step: _step,
      canContinue: _canContinue && !_saving,
      onBack: _step == 0 ? null : () => setState(() => _step--),
      onNext: _next,
      child: switch (_step) {
        0 => _heroStep(),
        1 => _companionStep(),
        _ => _questsStep(),
      },
    );
    return Scaffold(
      backgroundColor: Palette.forestDeep,
      body: SafeArea(
        child: expanded
            ? TwoPane(start: const _Welcome(tall: true), end: form)
            : Column(
                children: <Widget>[
                  const SizedBox(height: 150, child: _Welcome(tall: false)),
                  Expanded(child: form),
                ],
              ),
      ),
    );
  }

  Widget _heroStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Who walks the Vale?', style: AppText.heading),
        const SizedBox(height: 6),
        Text(
          'Your real day is the adventure. Name your hero and pick a look.',
          style: AppText.body.copyWith(color: Palette.slateSoft),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _heroName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: AppText.cardTitle.copyWith(fontSize: 19),
          decoration: const InputDecoration(hintText: 'Hero name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _ChoiceGrid(
          columns: 4,
          children: <Widget>[
            for (final p in heroPortraits)
              _PortraitChoice(
                label: p.label,
                selected: _portrait == p.id,
                onTap: () => setState(() => _portrait = p.id),
                child: HeroPortrait(portraitId: p.id, size: 56),
              ),
          ],
        ),
      ],
    );
  }

  Widget _companionStep() {
    final kind = _kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Choose your companion', style: AppText.heading),
        const SizedBox(height: 6),
        Text(
          'Small, kind, easy-to-drop goals live with your companion. They '
          'level up beside you, on their own track.',
          style: AppText.body.copyWith(color: Palette.slateSoft),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'A hound named Babs',
          icon: 'paw',
          color: Palette.companion,
          onPressed: _chooseBabs,
        ),
        const SizedBox(height: 16),
        Text('OR CHOOSE A KIND', style: AppText.label.copyWith(color: Palette.slateSoft)),
        const SizedBox(height: 10),
        _ChoiceGrid(
          columns: 3,
          children: <Widget>[
            for (final k in CompanionKind.values)
              _PortraitChoice(
                label: k.label,
                selected: _kind == k,
                accent: Palette.companion,
                onTap: () => setState(() => _kind = k),
                child: CompanionPortrait(kind: k, size: 62),
              ),
          ],
        ),
        if (kind != null) ...<Widget>[
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.companionTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.companionEdge),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${kind.label}: ${kind.temperament}',
                      style: AppText.body.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const VIcon('affinity', size: 14, color: Palette.companion),
                  const SizedBox(width: 4),
                  Text(
                    kind.affinity.label,
                    style: AppText.small.copyWith(
                      color: Palette.companionDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _companionName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: AppText.cardTitle.copyWith(fontSize: 19),
          decoration: const InputDecoration(hintText: 'Companion name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          'Every kind is equal. The star marks a favourite attribute, for '
          'flavour only.',
          style: AppText.small.copyWith(color: Palette.slateSoft),
        ),
      ],
    );
  }

  Widget _questsStep() {
    final name = _companionName.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Your first quests', style: AppText.heading),
        const SizedBox(height: 6),
        Text(
          'These start you off. Rename, change or archive any of them in the '
          'Quest Log.',
          style: AppText.body.copyWith(color: Palette.slateSoft),
        ),
        const SizedBox(height: 14),
        const _SeedLine('paw', 'Walk Babs', 'Shared · daily'),
        const _SeedLine('ball', 'Play / Train with Babs', 'Companion · 10 minutes'),
        const _SeedLine('boot', '7,000 Steps', 'Hero · daily'),
        const _SeedLine('sprig', 'Morning Health Check', 'Hero · daily'),
        const _SeedLine('brush', 'Painting / Craft Block', 'Hero · weekends'),
        const _SeedLine('vial', 'Weekly Injection (Mounjaro)', 'Hero · Saturdays'),
        const _SeedLine('campfire', 'Campfire Review', 'Closes each day'),
        const SizedBox(height: 14),
        ParchmentCard(
          tint: Palette.companionTint,
          edge: Palette.companionEdge,
          onTap: () => setState(() => _fiveMinuteReset = !_fiveMinuteReset),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _fiveMinuteReset
                      ? Palette.companion
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Palette.companionEdge, width: 1.4),
                ),
                alignment: Alignment.center,
                child: _fiveMinuteReset
                    ? const VIcon('check', size: 16, color: Palette.parchment)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Add Five-Minute Reset',
                      style: AppText.cardTitle,
                    ),
                    Text(
                      'A tidy, a stretch or a reset of one small space, '
                      'carried by ${name.isEmpty ? 'your companion' : name}.',
                      style: AppText.small.copyWith(color: Palette.slateSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.tall});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, tall ? 0 : 14, tall ? 14 : 0),
      child: Vista(
        wake: 0.5,
        radius: 26,
        child: Align(
          alignment: tall ? Alignment.topLeft : Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  appName.toUpperCase(),
                  style: AppText.label.copyWith(color: Palette.goldBright),
                ),
                const SizedBox(height: 4),
                Text(
                  'A sleeping valley is waiting',
                  style: AppText.display.copyWith(
                    color: Palette.onDark,
                    fontSize: tall ? 30 : 22,
                  ),
                ),
                if (tall) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Your habits, health targets and plans become quests. '
                    'Finish them and the Vale wakes, a lantern at a time.',
                    style: AppText.body.copyWith(color: Palette.onDark),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.step,
    required this.canContinue,
    required this.onBack,
    required this.onNext,
    required this.child,
  });

  final int step;
  final bool canContinue;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: ColoredBox(
          color: Palette.parchment,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                          decoration: BoxDecoration(
                            color: i <= step ? Palette.gold : Palette.parchmentEdge,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Palette.slate),
                    child: child,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Palette.parchmentShade,
                  border: Border(top: BorderSide(color: Palette.parchmentEdge)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: <Widget>[
                      if (onBack != null) ...<Widget>[
                        QuietButton(label: 'Back', onPressed: onBack),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: PrimaryButton(
                          label: step == 2 ? 'Begin at Dawn' : 'Continue',
                          icon: step == 2 ? 'sun' : null,
                          onPressed: canContinue ? onNext : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitChoice extends StatelessWidget {
  const _PortraitChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.accent = Palette.goldDeep,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accent : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                child,
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.replaceAll(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: AppText.small.copyWith(
                      color: Palette.slate,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
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

/// Lays choices out in equal columns across the available width.
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width =
            ((constraints.maxWidth - gap * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: <Widget>[
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SeedLine extends StatelessWidget {
  const _SeedLine(this.icon, this.name, this.detail);

  final String icon;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          VIcon(icon, size: 20, color: Palette.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.cardTitle.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail,
            style: AppText.small.copyWith(color: Palette.slateSoft, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
