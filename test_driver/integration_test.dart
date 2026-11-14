import 'package:integration_test/integration_test_driver.dart';

/// Driver for running `integration_test/app_test.dart` against an APK that
/// was built ahead of time:
///
///   flutter build apk --debug --target integration_test/app_test.dart
///   flutter drive --use-application-binary=<that apk> \
///     --driver=test_driver/integration_test.dart -d <device>
Future<void> main() => integrationDriver();
