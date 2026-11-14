import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/repository.dart';
import '../../data/seed.dart';
import '../../rules/day_key.dart';
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';
import 'quest_editor.dart';

/// Quest Log (DESIGN §8.5): every quest, create / edit / archive, and a
/// plain history of past days. On the opened Fold it is list + detail.
class QuestLogScreen extends StatefulWidget {
  const QuestLogScreen({super.key, this.leadingInset = 0});

  final double leadingInset;

  @override
  State<QuestLogScreen> createState() => _QuestLogScreenState();
}

class _QuestLogScreenState extends State<QuestLogScreen> {
  bool _history = false;
  String? _selectedId;
  bool _creating = false;
  int _editorGeneration = 0;

  void _open(QuestRow quest) {
    if (isExpanded(context)) {
      setState(() {
        _selectedId = quest.id;
        _creating = false;
        _editorGeneration++;
      });
    } else {
      openQuestEditor(context, quest: quest);
    }
  }

  void _new() {
    if (isExpanded(context)) {
      setState(() {
        _selectedId = null;
        _creating = true;
        _editorGeneration++;
      });
    } else {
      openQuestEditor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final list = _LogList(
      history: _history,
      selectedId: _selectedId,
      onToggle: (v) => setState(() => _history = v),
      onOpen: _open,
      onNew: _new,
    );
    if (!isExpanded(context)) return list;

    QuestRow? selected;
    for (final q in game.quests) {
      if (q.id == _selectedId) selected = q;
    }
    final Widget detail;
    if (selected != null || _creating) {
      detail = Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: ColoredBox(
            color: Palette.parchment,
            child: QuestEditor(
              key: ValueKey<String>(
                '${selected?.id ?? 'new'}-$_editorGeneration',
              ),
              quest: selected,
              showClose: false,
              onClose: () => setState(() {
                _selectedId = null;
                _creating = false;
              }),
            ),
          ),
        ),
      );
    } else {
      detail = const _DetailHint();
    }
    return TwoPane(
      leadingInset: widget.leadingInset,
      start: list,
      end: detail,
    );
  }
}

class _DetailHint extends StatelessWidget {
  const _DetailHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Choose a quest to see and change its details, or start a new one.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: Palette.onDarkSoft),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.history,
    required this.selectedId,
    required this.onToggle,
    required this.onOpen,
    required this.onNew,
  });

  final bool history;
  final String? selectedId;
  final ValueChanged<bool> onToggle;
  final ValueChanged<QuestRow> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    // The welcome-back quest is the app's own and comes and goes by itself.
    final own = game.quests.where((q) => q.systemKey != systemKeyComeback);
    final active = own.where((q) => q.active).toList();
    final archived = own.where((q) => !q.active).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Quest Log',
                style: AppText.display.copyWith(
                  color: Palette.onDark,
                  fontSize: 26,
                ),
              ),
            ),
            PrimaryButton(label: 'New quest', icon: 'plus', onPressed: onNew),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _Segment(
              label: 'Quests',
              selected: !history,
              onTap: () => onToggle(false),
            ),
            const SizedBox(width: 8),
            _Segment(
              label: 'Past days',
              selected: history,
              onTap: () => onToggle(true),
            ),
          ],
        ),
        if (!history) ...<Widget>[
          SectionHeader('Active', icon: 'board', count: active.length),
          for (final q in active) ...<Widget>[
            _QuestRowCard(
              quest: q,
              selected: q.id == selectedId,
              companionName: game.companionName,
              onTap: () => onOpen(q),
            ),
            const SizedBox(height: 8),
          ],
          if (archived.isNotEmpty) ...<Widget>[
            SectionHeader('Archived', icon: 'archive', count: archived.length),
            for (final q in archived) ...<Widget>[
              Opacity(
                opacity: 0.8,
                child: _QuestRowCard(
                  quest: q,
                  selected: q.id == selectedId,
                  companionName: game.companionName,
                  onTap: () => onOpen(q),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ] else ...<Widget>[
          const SectionHeader('Days you visited the Vale', icon: 'log'),
          if (game.history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                'Your days will gather here as you go.',
                style: AppText.body.copyWith(color: Palette.onDarkSoft),
              ),
            ),
          for (final day in game.history) ...<Widget>[
            _DayCard(summary: day, companionName: game.companionName),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Palette.parchment
            : Palette.forestNight.withValues(alpha: 0.4),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? Palette.gold
                : Palette.onDark.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                label,
                style: AppText.small.copyWith(
                  color: selected ? Palette.slate : Palette.onDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestRowCard extends StatelessWidget {
  const _QuestRowCard({
    required this.quest,
    required this.selected,
    required this.companionName,
    required this.onTap,
  });

  final QuestRow quest;
  final bool selected;
  final String companionName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final withCompanion = quest.track.travelsWithCompanion;
    final track = switch (quest.track) {
      Track.hero => 'Hero',
      Track.companion => 'With $companionName',
      Track.shared => 'Shared',
    };
    return ParchmentCard(
      tint: withCompanion ? Palette.companionTint : null,
      edge: selected
          ? Palette.gold
          : (withCompanion ? Palette.companionEdge : null),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Roundel(
            icon: quest.iconKey,
            color: Palette.attribute(quest.attribute),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    color: Palette.slate,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${scheduleOf(quest).describe()} · ${quest.difficulty.label} '
                  '· $track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: Palette.slateSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: VIcon('chevron', size: 16, color: Palette.slateFaint),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.summary, required this.companionName});

  final DaySummary summary;
  final String companionName;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${summary.quests} ${summary.quests == 1 ? 'quest' : 'quests'}',
      if (summary.heroXp > 0) '${summary.heroXp} XP',
      if (summary.companionXp > 0) '$companionName ${summary.companionXp} XP',
      if (summary.paces > 0)
        '${summary.paces} ${summary.paces == 1 ? 'Pace' : 'Paces'}',
    ];
    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DayKey.friendly(summary.day),
            style: AppText.cardTitle.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 3),
          Text(
            parts.join(' · '),
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
        ],
      ),
    );
  }
}
