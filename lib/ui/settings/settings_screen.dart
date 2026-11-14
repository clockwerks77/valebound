import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../export/export_service.dart';
import '../../export/markdown.dart';
import '../../rules/enums.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../art/crests.dart';
import '../campfire/campfire_screen.dart' show exportStatusLine;
import '../widgets/common.dart';
import '../widgets/v_icon.dart';

/// Opens Settings over whatever screen is showing.
Future<void> openSettings(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
  );
}

/// Settings (DESIGN §8.8): the vault folder and export controls, the party,
/// the JSON backup, and the about note. Calendar, Health Connect and the
/// reminder join this screen with the features they belong to.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _exportMessage;
  String? _backupMessage;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say({String? export, String? backup}) {
    if (!mounted) return;
    setState(() {
      if (export != null) _exportMessage = export;
      if (backup != null) _backupMessage = backup;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    if (game.hero == null || game.companion == null) {
      return const Scaffold(backgroundColor: Palette.forestDeep);
    }
    final vault = _VaultCard(
      busy: _busy,
      message: _exportMessage,
      onPick: () => _run(() async {
        await game.pickVaultFolder();
        _say(export: exportStatusLine(game.export));
      }),
      onExport: () => _run(() async {
        await game.exportNow();
        _say(export: exportStatusLine(game.export));
      }),
      onShare: () => _run(() async {
        final shared = await game.shareExport();
        _say(
          export: shared
              ? 'Handed to the share sheet.'
              : 'Sharing is not available on this device right now.',
        );
      }),
      onForget: () => _run(() async {
        await game.forgetVaultFolder();
        _say(export: 'The folder is no longer used. Its files stay as they are.');
      }),
    );
    final backup = _BackupCard(
      busy: _busy,
      message: _backupMessage,
      onSave: () => _run(() async {
        final saved = await game.saveBackup();
        _say(backup: saved ? 'Backup saved.' : 'No backup was saved.');
      }),
      onRestore: () async {
        final go = await _confirmRestore(context);
        if (go != true) return;
        await _run(() async {
          final result = await game.restoreBackup();
          _say(backup: result?.message ?? 'No file was chosen.');
        });
      },
    );
    const party = _PartyCard();
    const about = _AboutCard();

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
                    children: <Widget>[
                      const _Heading(),
                      vault,
                      const SizedBox(height: 14),
                      backup,
                    ],
                  ),
                  end: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 66, 14, 24),
                    children: const <Widget>[party, SizedBox(height: 14), about],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                  children: <Widget>[
                    const _Heading(),
                    vault,
                    const SizedBox(height: 14),
                    party,
                    const SizedBox(height: 14),
                    backup,
                    const SizedBox(height: 14),
                    about,
                  ],
                ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: <Widget>[
          RoundIconButton(
            icon: 'close',
            semanticLabel: 'Close settings',
            size: 40,
            background: Palette.forestNight.withValues(alpha: 0.5),
            foreground: Palette.onDark,
            edge: Palette.onDark.withValues(alpha: 0.25),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Text(
            'Settings',
            style: AppText.display.copyWith(color: Palette.onDark, fontSize: 26),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.title);

  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          VIcon(icon, size: 19, color: Palette.goldDeep),
          const SizedBox(width: 8),
          Text(title, style: AppText.title.copyWith(color: Palette.slate)),
        ],
      ),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.busy,
    required this.message,
    required this.onPick,
    required this.onExport,
    required this.onShare,
    required this.onForget,
  });

  final bool busy;
  final String? message;
  final VoidCallback onPick;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final export = game.export;
    final chosen = export.vaultStatus.chosen;
    final String status = switch (export.state) {
      ExportState.noFolder => 'No vault folder chosen',
      ExportState.waiting => 'Export waiting for vault folder',
      ExportState.upToDate => export.vaultStatus.name == null
          ? 'Writing to your vault folder'
          : 'Writing to “${export.vaultStatus.name}”',
    };
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle('folder', 'Vault export'),
          Text(status, style: AppText.cardTitle.copyWith(color: Palette.slate)),
          const SizedBox(height: 6),
          Text(
            'Pick the folder once: a Quest Log folder inside your vault is the '
            'idea. The app writes $characterSheetFile, $questsFile and one '
            'note per day in $dailyFolder. It never reads, changes or removes '
            'anything else there.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (chosen)
                QuietButton(
                  label: 'Change folder',
                  icon: 'folder',
                  onPressed: busy ? null : onPick,
                )
              else
                PrimaryButton(
                  label: 'Choose vault folder',
                  icon: 'folder',
                  onPressed: busy ? null : onPick,
                ),
              if (chosen)
                QuietButton(
                  label: 'Export now',
                  icon: 'save',
                  onPressed: busy ? null : onExport,
                ),
              QuietButton(
                label: 'Share…',
                icon: 'share',
                onPressed: busy ? null : onShare,
              ),
              if (chosen)
                QuietButton(
                  label: 'Stop using this folder',
                  onPressed: busy ? null : onForget,
                ),
            ],
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              message!,
              style: AppText.small.copyWith(color: Palette.moss),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.busy,
    required this.message,
    required this.onSave,
    required this.onRestore,
  });

  final bool busy;
  final String? message;
  final VoidCallback onSave;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle('archive', 'Backup'),
          Text(
            'One JSON file holding everything: quests, history, your hero, '
            'your companion and the Vale. Keep a copy somewhere safe.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              QuietButton(
                label: 'Save a backup',
                icon: 'save',
                onPressed: busy ? null : onSave,
              ),
              QuietButton(
                label: 'Restore from a backup',
                icon: 'open',
                onPressed: busy ? null : onRestore,
              ),
            ],
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              message!,
              style: AppText.small.copyWith(color: Palette.moss),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool?> _confirmRestore(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreaseAware(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Restore from a backup?',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 8),
                Text(
                  'Restoring replaces everything on this device with what is '
                  'in the backup file. To keep today as well, save a backup '
                  'first.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    QuietButton(
                      label: 'Keep what is here',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    PrimaryButton(
                      label: 'Choose a backup',
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PartyCard extends StatelessWidget {
  const _PartyCard();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final hero = game.hero!;
    final companion = game.companion!;
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle('party', 'Your party'),
          Row(
            children: <Widget>[
              HeroPortrait(
                portraitId: hero.portraitId,
                size: 46,
                frame: game.frame,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hero.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(color: Palette.slate),
                ),
              ),
              QuietButton(
                label: 'Rename',
                icon: 'edit',
                onPressed: () => _renameHero(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              CompanionPortrait(kind: companion.kind, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${companion.name} · ${companion.kind.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(color: Palette.slate),
                ),
              ),
              QuietButton(
                label: 'Change',
                icon: 'edit',
                color: Palette.companionDeep,
                onPressed: () => _changeCompanion(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A companion’s name and kind can change at any time. Their level, '
            'Bond, tricks, gear and every Pace come with them.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
        ],
      ),
    );
  }
}

Future<void> _renameHero(BuildContext context) async {
  final game = GameScope.read(context);
  final controller = TextEditingController(text: game.hero?.name ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (context) => CreaseAware(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your hero’s name',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.body.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save name',
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (name != null && name.isNotEmpty) await game.renameHero(name);
}

Future<void> _changeCompanion(BuildContext context) async {
  final game = GameScope.read(context);
  final current = game.companion;
  if (current == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => CreaseAware(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _CompanionEditor(
            name: current.name,
            kind: current.kind,
            onSave: (name, kind) async {
              final navigator = Navigator.of(context);
              await game.changeCompanion(name: name, kind: kind);
              if (navigator.mounted) navigator.pop();
            },
          ),
        ),
      ),
    ),
  );
}

class _CompanionEditor extends StatefulWidget {
  const _CompanionEditor({
    required this.name,
    required this.kind,
    required this.onSave,
  });

  final String name;
  final CompanionKind kind;
  final Future<void> Function(String name, CompanionKind kind) onSave;

  @override
  State<_CompanionEditor> createState() => _CompanionEditorState();
}

class _CompanionEditorState extends State<_CompanionEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.name);
  late CompanionKind _kind = widget.kind;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CompanionPortrait(kind: _kind, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A new chapter',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Same friend, new chapter. Everything you have earned together '
            'stays exactly as it is.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: AppText.body.copyWith(color: Palette.slate),
            decoration: const InputDecoration(hintText: 'Companion’s name'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final kind in CompanionKind.values)
                ChoicePill(
                  label: kind.label,
                  selected: _kind == kind,
                  color: Palette.companion,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _kind.temperament,
            style: AppText.small.copyWith(color: Palette.companionDeep),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Begin the new chapter',
            color: Palette.companion,
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              widget.onSave(name, _kind);
            },
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardTitle('info', 'About'),
          Text(
            '$appName · version $appVersion',
            style: AppText.cardTitle.copyWith(color: Palette.slate),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything stays on this device. The app makes no network calls '
            'and has no analytics, no ads, no crash reporting and no '
            'accounts. The only files it writes outside its own storage are '
            'the ones you ask for: the vault export and the backup.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
          const SizedBox(height: 8),
          Text(
            'An original work. Its world, names, creatures, icons and art '
            'were made for this app and belong to no other game.',
            style: AppText.small.copyWith(color: Palette.slateSoft),
          ),
        ],
      ),
    );
  }
}
