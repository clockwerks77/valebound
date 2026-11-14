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
                  'Health Connect and $appName',
                  style: AppText.heading.copyWith(color: Palette.slate),
                ),
                const SizedBox(height: 10),
                Text(
                  '$appName reads at most two things from Health Connect, '
                  'each only if you turn it on.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  'Steps: the day’s step count. It fills your steps quest '
                  'and goes into the day’s note in your vault.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  'Glucose: the readings another app has put there. $appName '
                  'shows their average for the day in the Health Log and '
                  'the day’s note. It is a number only, with no targets and '
                  'no advice.',
                  style: AppText.body.copyWith(color: Palette.slateSoft),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing else is read, nothing is written back, and nothing '
                  'leaves this device: the app makes no network calls. You '
                  'can disconnect either one at any time in Settings.',
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
