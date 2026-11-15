import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repository.dart';
import '../../data/seed.dart';
import '../../device/device_port.dart';
import '../../export/markdown.dart' show thousands;
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../log/quest_editor.dart';
import '../widgets/common.dart';
import 'quest_actions.dart';

/// Opens the detail sheet for a quest on today's board: the larger controls
/// for its completion type, an optional note, "Later" and "Edit".
Future<void> showQuestSheet(BuildContext context, String questId) {
  if (isExpanded(context)) {
    // A full-width sheet would lay its buttons across the crease.
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Palette.forestNight.withValues(alpha: 0.7),
      builder: (context) => CreaseAware(
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: _QuestSheet(questId: questId, inDialog: true),
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _QuestSheet(questId: questId),
  );
}

class _QuestSheet extends StatefulWidget {
  const _QuestSheet({required this.questId, this.inDialog = false});

  final String questId;

  /// A dialog already makes room for the keyboard; a bottom sheet does not.
  final bool inDialog;

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
    await completeFromBoard(navigator.context, entry, note: note);
  }

  /// What the steps quest says about where its steps come from.
  String _stepsLine(GameController game) {
    if (game.stepsConnected) {
      final steps = game.stepsToday;
      return steps == null
          ? 'Steps fill in from Health Connect. Nothing has come through yet '
              'today; you can also mark it done yourself.'
          : '${thousands(steps)} steps so far today, from Health Connect. It '
              'completes itself at the target, or mark it done yourself.';
    }
    if (game.stepsAccess == StepsAccess.unavailable) {
      return 'Health Connect is not available on this device, so this one is '
          'yours to mark done.';
    }
    return 'Connect Health Connect and steps fill in by themselves. Either '
        'way, you can mark it done yourself.';
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final entry = _entry(game);
    final bottom =
        widget.inDialog ? 0.0 : MediaQuery.viewInsetsOf(context).bottom;
    if (entry == null) {
      return const SizedBox(height: 80);
    }
    final quest = entry.quest;
    final type = quest.completionType;
    final isSystem = quest.source == QuestSource.system;
    final isCampfire = quest.systemKey == systemKeyCampfire;
    // What it is for (Amendment v0.4 §1), and for a quest of the user's
    // own, a way to pin it to a goal.
    final line = game.lineFor(quest.id);
    final plan = line?.plan;
    final ownQuest = quest.planId == null &&
        (quest.source == QuestSource.manual ||
            quest.source == QuestSource.recurring ||
            quest.source == QuestSource.health);

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
                      game.titleFor(entry),
                      style: AppText.heading.copyWith(color: Palette.slate),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${quest.attribute.label} · ${game.worthFor(entry).label} · '
                      '${quest.track == Track.hero ? 'Hero' : quest.track == Track.shared ? 'Shared with ${game.companionName}' : 'With ${game.companionName}'}',
                      style: AppText.small.copyWith(color: Palette.slateSoft),
                    ),
                    Text(
                      rewardLabel(
                        quest,
                        game.companionName,
                        worth: game.worthFor(entry),
                      ),
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
          if (line != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              line.forLine,
              style: AppText.small.copyWith(
                color: Palette.slateSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (plan != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Tiny: ${plan.tiny}\nTarget: ${plan.target}\n'
              'Stretch: ${plan.stretch}',
              style: AppText.small.copyWith(color: Palette.slateSoft),
            ),
          ],
          if (ownQuest && game.goals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final goal in game.goals)
                  ChoicePill(
                    label: 'For: ${goal.text}',
                    selected: quest.goalId == goal.id,
                    onTap: () => game.pinQuestToGoal(
                      quest.id,
                      quest.goalId == goal.id ? null : goal.id,
                    ),
                  ),
              ],
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
            if (type == CompletionType.auto) ...<Widget>[
              Text(
                _stepsLine(game),
                style: AppText.small.copyWith(color: Palette.slateSoft),
              ),
              if (!game.stepsConnected &&
                  game.stepsAccess != StepsAccess.unavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: QuietButton(
                      label: 'Connect Health Connect',
                      icon: 'boot',
                      onPressed: () => game.connectSteps(),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (!isCampfire)
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: isCampfire
                  ? 'Close the day'
                  : type == CompletionType.confirm
                      ? 'I did this'
                      : 'Mark done',
              icon: isCampfire ? 'campfire' : 'check',
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
