import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../adaptive.dart';
import '../widgets/common.dart';

/// What the app reads from Health Connect and why. Shown when Health
/// Connect's own "why does this app want access" link opens the app, and
/// from Settings.
Future<void> showHealthNote(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => CreaseAware(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Steps and $appName',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 10),
                Text(
                  'If you connect Health Connect, $appName reads one thing: '
                  'today’s step count. It fills your steps quest and is '
                  'written into today’s note in your vault.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing else is read, nothing is written back, and nothing '
                  'leaves this device: the app makes no network calls. You '
                  'can disconnect at any time in Settings, and the quest '
                  'still works with a tap.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
