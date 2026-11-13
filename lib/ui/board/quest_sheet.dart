import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repository.dart';
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../log/quest_editor.dart';
import '../widgets/common.dart';
import 'quest_actions.dart';

/// Opens the detail sheet for a quest on today's board: the larger controls
/// for its completion type, an optional note, "Later" and "Edit".
Future<void> showQuestSheet(BuildContext context, String questId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _QuestSheet(questId: questId),
  );
}

class _QuestSheet extends StatefulWidget {
  const _QuestSheet({required this.questId});

  final String questId;

  @override
  State<_QuestSheet> createState() => _QuestSheetState();
}

class _QuestSheetState extends State<_QuestSheet> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _minutes = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _minutes.dispose();
    super.dispose();
  }

  BoardQuest? _entry(GameController game) {
    for (final b in game.board) {
      if (b.quest.id == widget.questId) return b;
    }
    return null;
  }

  Future<void> _complete(BoardQuest entry) async {
    final navigator = Navigator.of(context);
    final note = _note.text;
    navigator.pop();
    await completeEntry(navigator.context, entry, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final entry = _entry(game);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    if (entry == null) {
      return const SizedBox(height: 80);
    }
    final quest = entry.quest;
    final type = quest.completionType;
    final isSystem = quest.source == QuestSource.system;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Roundel(
                icon: quest.iconKey,
                color: Palette.attribute(quest.attribute),
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      quest.name,
                      style: AppText.heading.copyWith(color: Palette.slate),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quest.attribute.label} · ${quest.difficulty.label} · '
                      '${quest.track == Track.hero ? 'Hero' : quest.track == Track.shared ? 'Shared with ${game.companionName}' : 'With ${game.companionName}'}',
                      style: AppText.small.copyWith(color: Palette.slateSoft),
                    ),
                    Text(
                      rewardLabel(quest, game.companionName),
                      style: AppText.small.copyWith(
                        color: Palette.goldDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (quest.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              quest.notes,
              style: AppText.body.copyWith(color: Palette.slateSoft),
            ),
          ],
          const SizedBox(height: 18),
          if (entry.isDone)
            Text(
              'Done today at ${formatTimeOfDay(entry.completion!.completedAt)}.',
              textAlign: TextAlign.center,
              style: AppText.cardTitle.copyWith(color: Palette.moss),
            )
          else if (type == CompletionType.timer) ...<Widget>[
            Center(child: TimerControl(entry: entry, large: true)),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Add minutes by hand',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                QuietButton(
                  label: 'Add',
                  icon: 'plus',
                  onPressed: () {
                    final minutes = int.tryParse(_minutes.text) ?? 0;
                    if (minutes > 0) {
                      _minutes.clear();
                      game.addTimerMinutes(quest.id, minutes);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            // The user is the referee (DESIGN §6.2).
            PrimaryButton(
              label: 'Count it anyway',
              icon: 'check',
              onPressed: () => _complete(entry),
            ),
          ] else if (type == CompletionType.count) ...<Widget>[
            Center(child: CountStepper(entry: entry, large: true)),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Count it anyway',
              icon: 'check',
              onPressed: () => _complete(entry),
            ),
          ] else ...<Widget>[
            if (type == CompletionType.auto)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Steps will fill in by themselves once Health Connect is '
                  'linked. Until then, mark it done yourself.',
                  style: AppText.small.copyWith(color: Palette.slateSoft),
                ),
              ),
            if (!isSystem)
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: isSystem ? 'Close the day' : 'Mark done',
              icon: isSystem ? 'campfire' : 'check',
              onPressed: () => _complete(entry),
            ),
          ],
          if (!entry.isDone && !isSystem) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: QuietButton(
                    label: entry.isSetAside ? 'Back to Now' : 'Later today',
                    icon: 'later',
                    onPressed: () {
                      game.setAside(quest.id, aside: !entry.isSetAside);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuietButton(
                    label: 'Edit quest',
                    icon: 'edit',
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      openQuestEditor(navigator.context, quest: quest);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
