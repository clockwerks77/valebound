import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database.dart';
import '../../data/repository.dart';
import '../../rules/awards.dart';
import '../../rules/day_key.dart';
import '../../rules/enums.dart';
import '../../rules/schedule.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../board/quest_actions.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// Opens the quest creator / editor: a dialog inside one pane when the Fold
/// is open, a full page on the cover screen.
Future<void> openQuestEditor(BuildContext context, {QuestRow? quest}) {
  if (isExpanded(context)) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierColor: Palette.forestNight.withValues(alpha: 0.7),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 660),
          child: QuestEditor(
            quest: quest,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (pageContext) => Scaffold(
        backgroundColor: Palette.parchment,
        body: SafeArea(
          child: QuestEditor(
            quest: quest,
            onClose: () => Navigator.of(pageContext).pop(),
          ),
        ),
      ),
    ),
  );
}

enum _When { daily, weekdays, weekly, today, custom }

/// Create or edit a quest. Built to be fast (DESIGN §6.3): name, tap an
/// attribute, tap a difficulty, tap a schedule, save. Everything else sits
/// under "More options".
class QuestEditor extends StatefulWidget {
  const QuestEditor({
    super.key,
    this.quest,
    required this.onClose,
    this.showClose = true,
  });

  final QuestRow? quest;
  final VoidCallback onClose;
  final bool showClose;

  @override
  State<QuestEditor> createState() => _QuestEditorState();
}

class _QuestEditorState extends State<QuestEditor> {
  late QuestDraft _draft;
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _interval;
  late final TextEditingController _notes;
  bool _more = false;
  bool _doneAlready = false;
  bool _saving = false;

  bool get _isNew => widget.quest == null;

  @override
  void initState() {
    super.initState();
    final quest = widget.quest;
    _draft = quest == null ? QuestDraft() : QuestDraft.fromRow(quest);
    _name = TextEditingController(text: _draft.name);
    _target = TextEditingController(text: _draft.target?.toString() ?? '');
    _interval = TextEditingController(
      text: _draft.schedule.intervalDays?.toString() ?? '',
    );
    _notes = TextEditingController(text: _draft.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _interval.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _today => DayKey.of(GameScope.read(context).now);

  _When get _when {
    final s = _draft.schedule;
    switch (s.type) {
      case ScheduleType.daily:
        return _When.daily;
      case ScheduleType.weekdays:
        if (s.weekdays.length == 5 &&
            s.weekdays.containsAll(const <int>{1, 2, 3, 4, 5})) {
          return _When.weekdays;
        }
        return _When.custom;
      case ScheduleType.weekly:
        return _When.weekly;
      case ScheduleType.oneOff:
        return s.anchorDay == _today ? _When.today : _When.custom;
      case ScheduleType.interval:
        return _When.custom;
    }
  }

  void _setWhen(_When value) {
    final today = _today;
    setState(() {
      switch (value) {
        case _When.daily:
          _draft.schedule = const Schedule.daily();
        case _When.weekdays:
          _draft.schedule = const Schedule.workdays();
        case _When.weekly:
          _draft.schedule = Schedule.weeklyOn(DayKey.weekday(today));
        case _When.today:
          _draft.schedule = Schedule.once(today);
        case _When.custom:
          _more = true;
      }
      if (value != _When.today) _doneAlready = false;
    });
  }

  void _toggleWeekday(int day) {
    final current = _draft.schedule;
    final days = <int>{
      if (current.type == ScheduleType.weekdays ||
          current.type == ScheduleType.weekly)
        ...current.weekdays,
    };
    if (!days.remove(day)) days.add(day);
    setState(() {
      _draft.schedule = days.isEmpty
          ? const Schedule.daily()
          : Schedule.onWeekdays(days);
    });
  }

  Future<void> _save() async {
    _draft
      ..name = _name.text
      ..notes = _notes.text;
    final needsTarget = _draft.completionType == CompletionType.count ||
        _draft.completionType == CompletionType.timer ||
        _draft.completionType == CompletionType.auto;
    _draft.target = needsTarget ? int.tryParse(_target.text) : null;
    if (needsTarget && (_draft.target ?? 0) <= 0) {
      _draft.target = _draft.completionType == CompletionType.timer ? 15 : 1;
    }
    if (!_draft.isValid || _saving) return;
    setState(() => _saving = true);
    final game = GameScope.read(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final id = await game.saveQuest(_draft);
    BoardQuest? entry;
    if (_doneAlready) {
      for (final b in game.board) {
        if (b.quest.id == id) entry = b;
      }
    }
    widget.onClose();
    if (entry != null && navigator.mounted) {
      await completeEntry(navigator.context, entry);
    }
  }

  Future<void> _setActive(bool active) async {
    final quest = widget.quest;
    if (quest == null) return;
    await GameScope.read(context).setQuestActive(quest.id, active: active);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final companion = game.companionName;
    final quest = widget.quest;
    final when = _when;
    final type = _draft.completionType;
    final preview = _draft.attribute == null
        ? null
        : _previewLine(_draft, companion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _isNew ? 'New quest' : 'Edit quest',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
              ),
              if (widget.showClose)
                RoundIconButton(
                  icon: 'close',
                  semanticLabel: 'Close',
                  background: Colors.transparent,
                  foreground: Palette.slateSoft,
                  edge: Colors.transparent,
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _name,
                  autofocus: _isNew && widget.showClose,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: AppText.cardTitle.copyWith(
                    color: Palette.slate,
                    fontSize: 19,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What is the quest?',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const _FieldLabel('Attribute'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final a in Attribute.values)
                      ChoicePill(
                        label: a.label,
                        icon: attributeIcon(a),
                        color: Palette.attribute(a),
                        selected: _draft.attribute == a,
                        onTap: () => setState(() => _draft.attribute = a),
                      ),
                  ],
                ),
                const _FieldLabel('Difficulty'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final d in Difficulty.values)
                      ChoicePill(
                        label: d.label,
                        caption: '${d.xp}',
                        color: Palette.goldDeep,
                        selected: _draft.difficulty == d,
                        onTap: () => setState(() => _draft.difficulty = d),
                      ),
                  ],
                ),
                const _FieldLabel('Who carries it'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoicePill(
                      label: 'Hero',
                      icon: 'party',
                      selected: _draft.track == Track.hero,
                      onTap: () => setState(() => _draft.track = Track.hero),
                    ),
                    ChoicePill(
                      label: companion,
                      icon: 'paw',
                      color: Palette.companion,
                      selected: _draft.track == Track.companion,
                      onTap: () =>
                          setState(() => _draft.track = Track.companion),
                    ),
                    ChoicePill(
                      label: 'Shared',
                      icon: 'bond',
                      color: Palette.companionDeep,
                      selected: _draft.track == Track.shared,
                      onTap: () => setState(() => _draft.track = Track.shared),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Small, kind, easy-to-drop goals live with your companion.',
                  style: AppText.small.copyWith(color: Palette.slateSoft),
                ),
                if (preview != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: AppText.small.copyWith(
                      color: Palette.goldDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const _FieldLabel('When'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoicePill(
                      label: 'Daily',
                      selected: when == _When.daily,
                      onTap: () => _setWhen(_When.daily),
                    ),
                    ChoicePill(
                      label: 'Weekdays',
                      selected: when == _When.weekdays,
                      onTap: () => _setWhen(_When.weekdays),
                    ),
                    ChoicePill(
                      label: when == _When.weekly
                          ? _draft.schedule.describe()
                          : 'Weekly',
                      selected: when == _When.weekly,
                      onTap: () => _setWhen(_When.weekly),
                    ),
                    ChoicePill(
                      label: 'Just today',
                      selected: when == _When.today,
                      onTap: () => _setWhen(_When.today),
                    ),
                    if (when == _When.custom)
                      ChoicePill(
                        label: _draft.schedule.describe(),
                        selected: true,
                        onTap: () => _setWhen(_When.custom),
                      ),
                  ],
                ),
                if (_isNew && when == _When.today)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _CheckRow(
                      label: 'I already did this',
                      value: _doneAlready,
                      onChanged: (v) => setState(() => _doneAlready = v),
                    ),
                  ),
                const SizedBox(height: 14),
                QuietButton(
                  label: _more ? 'Fewer options' : 'More options',
                  icon: _more ? 'minus' : 'plus',
                  onPressed: () => setState(() => _more = !_more),
                ),
                if (_more) ...<Widget>[
                  const _FieldLabel('How it is completed'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final t in const <CompletionType>[
                        CompletionType.tap,
                        CompletionType.count,
                        CompletionType.timer,
                      ])
                        ChoicePill(
                          label: t.label,
                          icon: switch (t) {
                            CompletionType.count => 'plus',
                            CompletionType.timer => 'clock',
                            _ => 'check',
                          },
                          selected: type == t,
                          onTap: () => setState(() {
                            _draft.completionType = t;
                          }),
                        ),
                      if (type == CompletionType.auto)
                        ChoicePill(
                          label: 'Auto (steps)',
                          icon: 'boot',
                          selected: true,
                          onTap: () {},
                        ),
                    ],
                  ),
                  if (type == CompletionType.count ||
                      type == CompletionType.timer ||
                      type == CompletionType.auto) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _target,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: switch (type) {
                            CompletionType.timer => 'Minutes',
                            CompletionType.auto => 'Steps',
                            _ => 'How many',
                          },
                        ),
                      ),
                    ),
                  ],
                  const _FieldLabel('On these days'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (var d = 1; d <= 7; d++)
                        ChoicePill(
                          label: DayKey.weekdayShort[d - 1],
                          selected: (_draft.schedule.type ==
                                      ScheduleType.weekdays ||
                                  _draft.schedule.type ==
                                      ScheduleType.weekly) &&
                              _draft.schedule.weekdays.contains(d),
                          onTap: () => _toggleWeekday(d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Or every N days',
                      ),
                      onChanged: (text) {
                        final n = int.tryParse(text) ?? 0;
                        if (n > 0) {
                          setState(() {
                            _draft.schedule = Schedule.every(n, from: _today);
                          });
                        }
                      },
                    ),
                  ),
                  const _FieldLabel('Icon'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final icon in questIconChoices)
                        Semantics(
                          button: true,
                          selected: _draft.iconKey == icon,
                          label: 'Icon $icon',
                          child: GestureDetector(
                            onTap: () => setState(() => _draft.iconKey = icon),
                            child: Opacity(
                              opacity: _draft.iconKey == icon ? 1 : 0.45,
                              child: Roundel(
                                icon: icon,
                                size: 44,
                                color: _draft.attribute == null
                                    ? Palette.slateSoft
                                    : Palette.attribute(_draft.attribute!),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const _FieldLabel('Notes'),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Anything worth remembering',
                    ),
                  ),
                ],
              ],
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
                if (quest != null) ...<Widget>[
                  QuietButton(
                    label: quest.active ? 'Archive' : 'Restore',
                    icon: 'archive',
                    onPressed: () => _setActive(!quest.active),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: _isNew
                        ? (_doneAlready ? 'Save and mark done' : 'Add quest')
                        : 'Save',
                    icon: 'check',
                    onPressed:
                        (_name.text.trim().isEmpty || _draft.attribute == null)
                            ? null
                            : _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _previewLine(QuestDraft draft, String companion) {
    final a = awardFor(difficulty: draft.difficulty, track: draft.track);
    final attribute = draft.attribute!.label;
    return switch (draft.track) {
      Track.hero => 'You earn ${a.heroXp} XP in $attribute.',
      Track.companion =>
        '$companion earns ${a.companionXp} XP, 1 Bond and '
            '${a.paces == 1 ? '1 Pace' : '${a.paces} Paces'}.',
      Track.shared =>
        '$companion earns ${a.companionXp} XP; you earn ${a.heroXp} in '
            '$attribute.',
    };
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(
        text.toUpperCase(),
        style: AppText.label.copyWith(color: Palette.slateSoft),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: value ? Palette.forest : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value ? Palette.gold : Palette.parchmentEdge,
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: value
                    ? const VIcon('check', size: 16, color: Palette.goldBright)
                    : null,
              ),
              const SizedBox(width: 10),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: AppText.body.copyWith(color: Palette.slate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
