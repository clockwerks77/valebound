import 'package:flutter/services.dart';

/// Where the vault folder stands right now.
class VaultStatus {
  const VaultStatus({this.chosen = false, this.available = false, this.name});

  /// A folder has been picked.
  final bool chosen;

  /// The picked folder can be written to at the moment.
  final bool available;

  /// The folder's display name, when the system will give it.
  final String? name;
}

/// The app's only door to files outside its own storage (DESIGN §11).
///
/// Everything goes through Android's Storage Access Framework: the user picks
/// a folder once, the permission is persisted, and the app only ever writes
/// inside that folder. It never reads, parses or deletes vault files.
abstract class VaultPort {
  Future<VaultStatus> status();

  /// Opens the system folder picker. Returns the status afterwards, whether
  /// or not a folder was chosen.
  Future<VaultStatus> pickFolder();

  /// Stops using the picked folder and releases the permission.
  Future<void> forgetFolder();

  /// Writes each `relative/path.md` to its content inside the picked folder,
  /// replacing files of the same name. True when every file was written.
  Future<bool> writeFiles(Map<String, String> files);

  /// Hands the same files to the system share sheet.
  Future<bool> shareFiles(Map<String, String> files);

  /// Asks where to save one document (the JSON backup) and writes it.
  Future<bool> saveDocument(String suggestedName, String content);

  /// Asks for one document and returns its text, or null if none was chosen.
  Future<String?> openDocument();
}

/// Used where there is no platform to talk to (tests, previews). Nothing is
/// ever written.
class NoVault implements VaultPort {
  const NoVault();

  @override
  Future<VaultStatus> status() async => const VaultStatus();

  @override
  Future<VaultStatus> pickFolder() async => const VaultStatus();

  @override
  Future<void> forgetFolder() async {}

  @override
  Future<bool> writeFiles(Map<String, String> files) async => false;

  @override
  Future<bool> shareFiles(Map<String, String> files) async => false;

  @override
  Future<bool> saveDocument(String suggestedName, String content) async =>
      false;

  @override
  Future<String?> openDocument() async => null;
}

/// Talks to `MainActivity.kt` over a method channel. Every call is guarded:
/// if the platform side is absent or reports a problem, the answer is simply
/// "not available", and the export waits quietly (DESIGN §11).
class ChannelVault implements VaultPort {
  const ChannelVault();

  static const MethodChannel _channel = MethodChannel('app.habit_adventure/vault');

  VaultStatus _status(Object? raw) {
    if (raw is! Map) return const VaultStatus();
    return VaultStatus(
      chosen: raw['chosen'] == true,
      available: raw['available'] == true,
      name: raw['name'] is String ? raw['name'] as String : null,
    );
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<VaultStatus> status() async => _status(await _call<Object>('status'));

  @override
  Future<VaultStatus> pickFolder() async =>
      _status(await _call<Object>('pickFolder'));

  @override
  Future<void> forgetFolder() async {
    await _call<Object>('forgetFolder');
  }

  @override
  Future<bool> writeFiles(Map<String, String> files) async =>
      await _call<bool>('writeFiles', <String, Object>{'files': files}) ??
      false;

  @override
  Future<bool> shareFiles(Map<String, String> files) async =>
      await _call<bool>('shareFiles', <String, Object>{'files': files}) ??
      false;

  @override
  Future<bool> saveDocument(String suggestedName, String content) async =>
      await _call<bool>(
        'saveDocument',
        <String, Object>{'name': suggestedName, 'content': content},
      ) ??
      false;

  @override
  Future<String?> openDocument() => _call<String>('openDocument');
}
