import 'package:flutter/material.dart';

import '../../export/markdown.dart' show thousands;
import '../../rules/day_key.dart';
import '../../rules/health_fields.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// Opens the Health Log. True if the form was saved.
Future<bool> openHealthLog(BuildContext context) async {
  final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const HealthLogScreen()),
  );
  return saved ?? false;
}

/// Health Log (DESIGN §8.7, §9.3): the fields the user chose, in one fast
/// form. The app stores exactly what is typed and writes it to the day's
/// vault note. It gives no advice, sets no targets and passes no judgement.
class HealthLogScreen extends StatefulWidget {
  const HealthLogScreen({super.key});

  @override
  State<HealthLogScreen> createState() => _HealthLogScreenState();
}

class _HealthLogScreenState extends State<HealthLogScreen> {
  final Map<String, TextEditingController> _text =
      <String, TextEditingController>{};
  final Map<String, bool> _ticked = <String, bool>{};
  bool _loaded = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final game = GameScope.read(context);
    for (final field in game.settings.healthFields) {
      final stored = game.healthToday[field.key]?.value ?? '';
      if (field.kind == HealthFieldKind.check) {
        _ticked[field.key] = stored.isNotEmpty;
        _text[field.key] = TextEditingController(text: decodeCheck(stored));
      } else {
        _text[field.key] = TextEditingController(text: stored);
      }
    }
    // The figures Health Connect supplies are read afresh as the log opens.
    game.refreshHealth();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final game = GameScope.read(context);
    final navigator = Navigator.of(context);
    final values = <String, String>{};
    for (final field in game.settings.healthFields) {
      // Steps that come from Health Connect are not typed here.
      if (field.key == stepsFieldKey && game.stepsConnected) continue;
      final typed = _text[field.key]?.text ?? '';
      if (field.kind == HealthFieldKind.check) {
        values[field.key] =
            (_ticked[field.key] ?? false) ? encodeCheck(typed) : '';
      } else {
        values[field.key] = typed;
      }
    }
    await game.saveHealthLog(values);
    if (navigator.mounted) navigator.pop(true);
  }

  Widget _field(GameController game, HealthField field) {
    final controller = _text[field.key]!;
    if (field.key == stepsFieldKey && game.stepsConnected) {
      final steps = game.stepsToday;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            const VIcon('boot', size: 20, color: Palette.moss),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                steps == null
                    ? 'Steps: nothing from Health Connect yet today.'
                    : 'Steps: ${thousands(steps)}, from Health Connect.',
                style: AppText.body.copyWith(color: Palette.slate),
              ),
            ),
          ],
        ),
      );
    }
    if (field.kind == HealthFieldKind.check) {
      final ticked = _ticked[field.key] ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ToggleRow(
            label: field.label,
            value: ticked,
            onChanged: (v) => setState(() => _ticked[field.key] = v),
          ),
          if (ticked)
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 6),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body.copyWith(color: Palette.slate),
                decoration: const InputDecoration(
                  labelText: 'Note (optional), such as the dose',
                ),
              ),
            ),
        ],
      );
    }
    final number = field.kind == HealthFieldKind.number;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        style: AppText.body.copyWith(color: Palette.slate),
        // The label sits on the edge whether or not the field is in use, so
        // the unit is always in view and never has to be guessed.
        decoration: InputDecoration(
          labelText: field.label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixText: field.unit.isEmpty ? null : field.unit,
        ),
      ),
    );
  }

  /// The day's average glucose as Health Connect has it. A number and its
  /// unit: nothing is said about what it means.
  String _glucoseLine(GameController game) {
    final entry = game.glucoseAverageToday;
    if (entry == null) {
      return 'Average glucose: nothing from Health Connect yet today.';
    }
    final readings = game.glucoseToday?.readings;
    final from = readings == null
        ? 'from Health Connect'
        : 'from ${thousands(readings)} '
            '${readings == 1 ? 'reading' : 'readings'} in Health Connect';
    return 'Average glucose today: ${entry.value} ${entry.unit}, $from.';
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final fields = game.settings.healthFields
        .where((f) => _text.containsKey(f.key))
        .toList();

    final form = <Widget>[
      Row(
        children: <Widget>[
          RoundIconButton(
            icon: 'close',
            semanticLabel: 'Close the Health Log',
            size: 40,
            background: Palette.forestNight.withValues(alpha: 0.5),
            foreground: Palette.onDark,
            edge: Palette.onDark.withValues(alpha: 0.25),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Health Log',
                  style: AppText.display.copyWith(
                    color: Palette.onDark,
                    fontSize: 26,
                  ),
                ),
                Text(
                  DayKey.friendly(game.day),
                  style: AppText.small.copyWith(color: Palette.onDarkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      ParchmentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Read from Health Connect, never typed here (DECISIONS D-71).
            if (game.glucoseConnected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    const VIcon('vial', size: 20, color: Palette.moss),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _glucoseLine(game),
                        style: AppText.body.copyWith(color: Palette.slate),
                      ),
                    ),
                  ],
                ),
              ),
            if (fields.isEmpty)
              Text(
                'No fields are chosen yet. Pick the ones you want in '
                'Settings, under Health.',
                style: AppText.body.copyWith(color: Palette.slateSoft),
              )
            else
              for (final field in fields) _field(game, field),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Save',
              icon: 'check',
              color: Palette.moss,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    ];
    final about = ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'YOURS, AS WRITTEN',
            style: AppText.label.copyWith(color: Palette.goldDeep),
          ),
          const SizedBox(height: 8),
          Text(
            'Every field is optional. What you type is stored exactly as '
            'typed and written into today’s note in your vault, nowhere '
            'else. The app offers no targets and no advice.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 6),
          Text(
            'Leave a field empty to clear it. Choose which fields appear in '
            'Settings.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
        ],
      ),
    );

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
          child: isExpanded(context)
              ? TwoPane(
                  start: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 0, 24),
                    children: form,
                  ),
                  end: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 66, 14, 24),
                    children: <Widget>[about],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                  children: <Widget>[...form, const SizedBox(height: 14), about],
                ),
        ),
      ),
    );
  }
}
