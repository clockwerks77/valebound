import 'package:flutter/services.dart';

import '../rules/reminders.dart';

/// One of the device's calendars (DESIGN §9.3).
class DeviceCalendar {
  const DeviceCalendar({required this.id, required this.name, this.account = ''});
  final String id;
  final String name;
  final String account;
}

/// One event on the device calendar today. Read only: the app never changes
/// a calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.begin,
    required this.end,
    this.allDay = false,
    this.calendarId = '',
  });

  /// Identifies this occurrence: the event's id and its start time.
  final String id;
  final String title;
  final DateTime begin;
  final DateTime end;
  final bool allDay;
  final String calendarId;

  /// e.g. `10:30 – 11:15`, or `All day`.
  String get timeLabel {
    if (allDay) return 'All day';
    final from = formatReminderTime(begin.hour, begin.minute);
    final to = formatReminderTime(end.hour, end.minute);
    return from == to ? from : '$from – $to';
  }
}

/// Where steps from Health Connect stand.
enum StepsAccess {
  /// This device has no Health Connect the app can read.
  unavailable,

  /// It is there, and the user has not allowed steps to be read.
  notConnected,

  /// Steps can be read.
  connected,
}

/// One reminder to schedule: the only notification the app sends.
class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// The app's door to the device's calendar, Health Connect and local
/// notifications (DESIGN §9.3, §6.1). Everything here is optional: each
/// answer has a "not available" form and the app works without any of it.
/// Nothing here touches the network.
abstract class DevicePort {
  Future<bool> calendarGranted();

  /// Asks for `READ_CALENDAR`. True if it is granted afterwards.
  Future<bool> requestCalendar();
  Future<List<DeviceCalendar>> calendars();

  /// Events that overlap the span, soonest first.
  Future<List<CalendarEvent>> eventsBetween(DateTime start, DateTime end);

  Future<StepsAccess> stepsAccess();

  /// Asks Health Connect for permission to read steps.
  Future<StepsAccess> requestSteps();

  /// Total steps in the span, or null if they cannot be read.
  Future<int?> stepsBetween(DateTime start, DateTime end);

  Future<bool> notificationsAllowed();
  Future<bool> requestNotifications();

  /// Replaces every scheduled reminder with [reminders].
  Future<bool> syncReminders(List<ReminderRequest> reminders);

  /// Why the app was opened, when it was opened for a reason of its own
  /// (`health_rationale`: from Health Connect's "why does this app want
  /// access" link). Answered once, then null.
  Future<String?> takeLaunchReason();
}

/// Used where there is no platform to talk to (tests, previews): nothing is
/// available, and the app carries on with its manual fallbacks.
class NoDevice implements DevicePort {
  const NoDevice();

  @override
  Future<bool> calendarGranted() async => false;

  @override
  Future<bool> requestCalendar() async => false;

  @override
  Future<List<DeviceCalendar>> calendars() async => const <DeviceCalendar>[];

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime start, DateTime end) async =>
      const <CalendarEvent>[];

  @override
  Future<StepsAccess> stepsAccess() async => StepsAccess.unavailable;

  @override
  Future<StepsAccess> requestSteps() async => StepsAccess.unavailable;

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async => null;

  @override
  Future<bool> notificationsAllowed() async => false;

  @override
  Future<bool> requestNotifications() async => false;

  @override
  Future<bool> syncReminders(List<ReminderRequest> reminders) async => false;

  @override
  Future<String?> takeLaunchReason() async => null;
}

/// Talks to `DeviceChannel.kt` over a method channel. Every call is guarded:
/// if the platform side is absent or reports a problem, the answer is simply
/// "not available".
class ChannelDevice implements DevicePort {
  const ChannelDevice();

  static const MethodChannel _channel =
      MethodChannel('app.habit_adventure/device');

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Map<String, int> _span(DateTime start, DateTime end) => <String, int>{
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      };

  StepsAccess _access(String? raw) => switch (raw) {
        'connected' => StepsAccess.connected,
        'notConnected' => StepsAccess.notConnected,
        _ => StepsAccess.unavailable,
      };

  @override
  Future<bool> calendarGranted() async =>
      await _call<bool>('calendarGranted') ?? false;

  @override
  Future<bool> requestCalendar() async =>
      await _call<bool>('requestCalendar') ?? false;

  @override
  Future<List<DeviceCalendar>> calendars() async {
    final raw = await _call<List<Object?>>('calendars');
    return <DeviceCalendar>[
      for (final item in raw ?? const <Object?>[])
        if (item is Map && item['id'] != null)
          DeviceCalendar(
            id: '${item['id']}',
            name: '${item['name'] ?? ''}',
            account: '${item['account'] ?? ''}',
          ),
    ];
  }

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime start, DateTime end) async {
    final raw = await _call<List<Object?>>('events', _span(start, end));
    final events = <CalendarEvent>[];
    for (final item in raw ?? const <Object?>[]) {
      if (item is! Map) continue;
      final begin = item['begin'];
      final finish = item['end'];
      if (item['id'] == null || begin is! int || finish is! int) continue;
      events.add(
        CalendarEvent(
          id: '${item['id']}@$begin',
          title: '${item['title'] ?? ''}',
          begin: DateTime.fromMillisecondsSinceEpoch(begin),
          end: DateTime.fromMillisecondsSinceEpoch(finish),
          allDay: item['allDay'] == true,
          calendarId: '${item['calendarId'] ?? ''}',
        ),
      );
    }
    events.sort((a, b) => a.begin.compareTo(b.begin));
    return events;
  }

  @override
  Future<StepsAccess> stepsAccess() async =>
      _access(await _call<String>('stepsAccess'));

  @override
  Future<StepsAccess> requestSteps() async =>
      _access(await _call<String>('requestSteps'));

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) =>
      _call<int>('steps', _span(start, end));

  @override
  Future<bool> notificationsAllowed() async =>
      await _call<bool>('notificationsAllowed') ?? false;

  @override
  Future<bool> requestNotifications() async =>
      await _call<bool>('requestNotifications') ?? false;

  @override
  Future<bool> syncReminders(List<ReminderRequest> reminders) async =>
      await _call<bool>('syncReminders', <String, Object>{
        'reminders': <Map<String, Object>>[
          for (final r in reminders)
            <String, Object>{
              'id': r.id,
              'at': r.at.millisecondsSinceEpoch,
              'title': r.title,
              'body': r.body,
            },
        ],
      }) ??
      false;

  @override
  Future<String?> takeLaunchReason() => _call<String>('takeLaunchReason');
}
