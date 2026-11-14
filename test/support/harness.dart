import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/app.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/export/vault_port.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/state/game_controller.dart';
import 'package:habit_adventure/ui/art/painted.dart';

/// Screen sizes for the test matrix in DESIGN §9.1. The two Fold sizes come
/// from the Galaxy Z Fold 8's published panel resolutions (1248×1972 cover,
/// 2448×1848 inner) at a density of 3.0. The layout itself only looks at
/// window size classes, so the exact figures are not load-bearing.
class TestDevice {
  const TestDevice(this.name, this.size, {this.crease = false});
  final String name;
  final Size size;

  /// A vertical fold down the middle, as the opened Fold reports.
  final bool crease;

  static const double pixelRatio = 3.0;
  static const TestDevice compactPhone =
      TestDevice('compact_phone', Size(360, 760));
  static const TestDevice foldCover = TestDevice('fold_cover', Size(416, 657));
  static const TestDevice foldOpen =
      TestDevice('fold_open', Size(816, 616), crease: true);
}

void useDevice(WidgetTester tester, TestDevice device) {
  tester.view.devicePixelRatio = TestDevice.pixelRatio;
  tester.view.physicalSize = device.size * TestDevice.pixelRatio;
  if (device.crease) {
    tester.view.displayFeatures = <ui.DisplayFeature>[
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(device.size.width / 2, 0, 0, device.size.height),
        type: ui.DisplayFeatureType.fold,
        state: ui.DisplayFeatureState.postureFlat,
      ),
    ];
  }
  addTearDown(tester.view.reset);
}

bool _fontsLoaded = false;

/// Loads the bundled fonts so screenshots show real type, not test boxes.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await family('Fraunces', <String>[
    'Fraunces-SemiBold.ttf',
    'Fraunces-Bold.ttf',
  ]);
  await family('Figtree', <String>[
    'Figtree-Regular.ttf',
    'Figtree-Medium.ttf',
    'Figtree-SemiBold.ttf',
    'Figtree-Bold.ttf',
  ]);
  _fontsLoaded = true;
}

/// A vault folder held in memory, standing in for the Android side.
class MemoryVault implements VaultPort {
  MemoryVault({this.chosen = false, this.available = true, this.name = 'Quest Log'});

  bool chosen;
  bool available;
  String name;

  /// What is "in the folder": relative path to content.
  final Map<String, String> files = <String, String>{};
  int writes = 0;
  Map<String, String>? shared;
  String? savedName;
  String? savedDocument;

  /// What the document picker will hand back.
  String? documentToOpen;

  @override
  Future<VaultStatus> status() async => VaultStatus(
        chosen: chosen,
        available: chosen && available,
        name: chosen && available ? name : null,
      );

  @override
  Future<VaultStatus> pickFolder() async {
    chosen = true;
    return status();
  }

  @override
  Future<void> forgetFolder() async {
    chosen = false;
  }

  @override
  Future<bool> writeFiles(Map<String, String> newFiles) async {
    if (!chosen || !available) return false;
    writes++;
    files.addAll(newFiles);
    return true;
  }

  @override
  Future<bool> shareFiles(Map<String, String> files) async {
    shared = Map<String, String>.of(files);
    return files.isNotEmpty;
  }

  @override
  Future<bool> saveDocument(String suggestedName, String content) async {
    savedName = suggestedName;
    savedDocument = content;
    return true;
  }

  @override
  Future<String?> openDocument() async => documentToOpen;
}

/// A device held in memory, standing in for the Android side: a calendar,
/// a step counter and a reminder list the test controls.
class MemoryDevice implements DevicePort {
  MemoryDevice({
    this.calendarPermission = false,
    this.grantCalendar = true,
    this.steps = StepsAccess.notConnected,
    this.grantSteps = true,
    this.stepCount,
    this.notifications = false,
    this.grantNotifications = true,
    this.launchReason,
  });

  bool calendarPermission;

  /// What the user answers when asked for the calendar.
  bool grantCalendar;
  List<DeviceCalendar> calendarList = const <DeviceCalendar>[
    DeviceCalendar(id: '1', name: 'Personal', account: 'adam'),
    DeviceCalendar(id: '2', name: 'Work', account: 'adam'),
  ];
  List<CalendarEvent> events = <CalendarEvent>[];

  StepsAccess steps;

  /// What the user answers when asked for steps.
  bool grantSteps;
  int? stepCount;
  int stepReads = 0;

  bool notifications;
  bool grantNotifications;
  List<ReminderRequest> reminders = const <ReminderRequest>[];
  int reminderSyncs = 0;
  String? launchReason;

  @override
  Future<bool> calendarGranted() async => calendarPermission;

  @override
  Future<bool> requestCalendar() async {
    calendarPermission = calendarPermission || grantCalendar;
    return calendarPermission;
  }

  @override
  Future<List<DeviceCalendar>> calendars() async =>
      calendarPermission ? calendarList : const <DeviceCalendar>[];

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime start, DateTime end) async {
    if (!calendarPermission) return const <CalendarEvent>[];
    return <CalendarEvent>[
      for (final e in events)
        if (e.begin.isBefore(end) && e.end.isAfter(start)) e,
    ];
  }

  @override
  Future<StepsAccess> stepsAccess() async => steps;

  @override
  Future<StepsAccess> requestSteps() async {
    if (steps == StepsAccess.notConnected && grantSteps) {
      steps = StepsAccess.connected;
    }
    return steps;
  }

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    stepReads++;
    return steps == StepsAccess.connected ? stepCount : null;
  }

  @override
  Future<bool> notificationsAllowed() async => notifications;

  @override
  Future<bool> requestNotifications() async {
    notifications = notifications || grantNotifications;
    return notifications;
  }

  @override
  Future<bool> syncReminders(List<ReminderRequest> next) async {
    reminders = List<ReminderRequest>.of(next);
    reminderSyncs++;
    return true;
  }

  @override
  Future<String?> takeLaunchReason() async {
    final reason = launchReason;
    launchReason = null;
    return reason;
  }
}

/// A running app on an in-memory database with a clock the test controls.
class TestApp {
  TestApp(this.now);

  DateTime now;
  late final AppDatabase db;
  late final GameRepository repo;
  late final GameController game;

  static Future<TestApp> start(
    WidgetTester tester, {
    required DateTime now,
    bool withProfile = true,
    bool withHistory = false,
    VaultPort? vault,
    DevicePort? device,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final app = TestApp(now);
    app.db = AppDatabase(NativeDatabase.memory());
    app.repo = GameRepository(app.db, clock: () => app.now);
    app.game = GameController(
      app.repo,
      vault: vault ?? const NoVault(),
      device: device ?? const NoDevice(),
    );
    addTearDown(app.db.close);

    await tester.runAsync(() async {
      if (withProfile) {
        if (withHistory) {
          await app._seedHistory();
        } else {
          await app.repo.createProfile(
            heroName: 'Adam',
            portraitId: 'wayfarer',
            companionName: 'Babs',
            companionKind: CompanionKind.hound,
            activateFiveMinuteReset: true,
          );
        }
      }
      await app.game.init();
    });

    await tester.pumpWidget(HabitAdventureApp(controller: app.game));
    // Decode the illustrated art before the first frame is judged, so
    // screenshots show the portraits and not an empty ring.
    final context = tester.element(find.byType(HabitAdventureApp));
    await tester.runAsync(() async {
      for (final asset in allPaintedAssets) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();
    return app;
  }

  Future<String> _id(String name) async {
    final quests = await repo.allQuests();
    return quests.firstWhere((q) => q.name == name).id;
  }

  /// Thirteen ordinary days before "today", then a morning's progress, so
  /// screenshots show a party that has been travelling for a while.
  Future<void> _seedHistory() async {
    final today = now;
    now = DateTime(today.year, today.month, today.day - 13, 8);
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    for (var back = 13; back >= 1; back--) {
      now = DateTime(today.year, today.month, today.day - back, 8, 10);
      await repo.ensureDawn();
      await repo.completeQuest(await _id('Morning Health Check'));
      now = now.add(const Duration(hours: 1));
      await repo.completeQuest(await _id('Walk Babs'));
      now = now.add(const Duration(hours: 3));
      await repo.completeQuest(await _id('Play / Train with Babs'));
      now = now.add(const Duration(hours: 5));
      await repo.completeQuest(await _id('7,000 Steps'));
      if (back.isEven) {
        now = now.add(const Duration(hours: 3));
        await repo.completeQuest(await _id('Campfire Review'));
      }
    }
    now = today;
    await repo.ensureDawn();
    await repo.saveQuest(
      QuestDraft(
        name: 'Glasses of water',
        iconKey: 'cup',
        attribute: Attribute.vitality,
        difficulty: Difficulty.minor,
        completionType: CompletionType.count,
        target: 8,
      ),
    );
    await repo.setCount(await _id('Glasses of water'), 3);
    now = DateTime(today.year, today.month, today.day, 7, 40);
    await repo.completeQuest(await _id('Morning Health Check'));
    now = DateTime(today.year, today.month, today.day, 8, 25);
    await repo.completeQuest(await _id('Walk Babs'));
    now = today;
  }

  /// Lets database work started by a tap finish, then settles animations.
  ///
  /// Done in several rounds, because one can start the other: a tapped quest
  /// waits out its five-second Undo window (an animation) before it is
  /// committed (database work), and committing starts the reward toast.
  Future<void> settle(WidgetTester tester) async {
    for (var round = 0; round < 8; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    }
  }
}

/// Scrolls the first list until [target] is built and sits mid-screen, clear
/// of the floating "Quest" button.
Future<void> reveal(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView).first;
  for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.4);
  await tester.pumpAndSettle();
}
