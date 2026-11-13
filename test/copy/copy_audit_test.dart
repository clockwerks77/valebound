import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DESIGN §6.4 copy audit and §13 IP guardrails.
///
/// Every string literal in `lib/` is treated as potentially user-facing and
/// checked for guilt, shame or loss language and for any banned property
/// name. Comments are not scanned; they never reach the screen.

/// Pulls the contents of every string literal out of Dart source, skipping
/// line and block comments.
List<String> stringLiterals(String source) {
  final out = <String>[];
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? n : end + 2;
    } else if (c == "'" || c == '"') {
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      i += quote.length;
      final buffer = StringBuffer();
      while (i < n && !source.startsWith(quote, i)) {
        if (source[i] == r'\' && i + 1 < n) {
          buffer.write(source[i + 1]);
          i += 2;
        } else {
          buffer.write(source[i]);
          i++;
        }
      }
      i += quote.length;
      out.add(buffer.toString());
    } else {
      i++;
    }
  }
  return out;
}

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final literals = <String, List<String>>{
    for (final f in files) f.path: stringLiterals(f.readAsStringSync()),
  };

  test('the scan covers the app', () {
    expect(files.length, greaterThan(20));
    final all = literals.values.expand((l) => l).toList();
    expect(all, contains('Walk Babs'));
    expect(all.length, greaterThan(300));
  });

  test('the literal scanner skips comments and reads strings', () {
    const sample = '''
      // "not a string", it's a comment
      /* 'nor this' */
      final a = 'one';
      final b = "two";
      final c = 'it\\'s';
    ''';
    expect(stringLiterals(sample), <String>['one', 'two', "it's"]);
  });

  test('no guilt, shame or loss language (DESIGN §6.4)', () {
    final banned = <RegExp>[
      RegExp(r'streak\s+broken', caseSensitive: false),
      RegExp(r'\bstreaks?\b', caseSensitive: false),
      RegExp(r'\bfail(ed|ure|ures|s|ing)?\b', caseSensitive: false),
      RegExp(r'\bmissed\b', caseSensitive: false),
      RegExp(r'missed\s+out', caseSensitive: false),
      RegExp(r'\blost\b', caseSensitive: false),
      RegExp(r'\bbehind\b', caseSensitive: false),
      RegExp(r'\bpenalt(y|ies)\b', caseSensitive: false),
      RegExp(r'\boverdue\b', caseSensitive: false),
      RegExp(r'\bshame\b', caseSensitive: false),
      RegExp(r'\bguilt(y)?\b', caseSensitive: false),
      RegExp(r'you (broke|forgot|skipped)', caseSensitive: false),
    ];
    final hits = <String>[];
    literals.forEach((path, strings) {
      for (final s in strings) {
        for (final pattern in banned) {
          if (pattern.hasMatch(s)) hits.add('$path: "$s" (${pattern.pattern})');
        }
      }
    });
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no banned property names or vocabulary (DESIGN §13)', () {
    final banned = <RegExp>[
      RegExp(r'\bnintendo\b', caseSensitive: false),
      RegExp(r'\bzelda\b', caseSensitive: false),
      RegExp(r'\bhyrule\b', caseSensitive: false),
      RegExp(r'\btriforce\b', caseSensitive: false),
      RegExp(r'master\s+sword', caseSensitive: false),
      RegExp(r'\brupees?\b', caseSensitive: false),
      RegExp(r'heart\s+containers?', caseSensitive: false),
      RegExp(r'\bganon', caseSensitive: false),
      // The character name, capitalised as a word by itself.
      RegExp(r'\bLink\b'),
      RegExp(r'world of warcraft', caseSensitive: false),
    ];
    final hits = <String>[];
    literals.forEach((path, strings) {
      for (final s in strings) {
        for (final pattern in banned) {
          if (pattern.hasMatch(s)) hits.add('$path: "$s" (${pattern.pattern})');
        }
      }
    });
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('the app makes no network calls and bundles no network package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final package in <String>[
      'http:',
      'dio:',
      'firebase',
      'sentry',
      'google_fonts',
      'analytics',
      'crashlytics',
      'web_socket',
    ]) {
      expect(pubspec.contains(package), isFalse, reason: package);
    }
    for (final f in files) {
      final source = f.readAsStringSync();
      expect(source.contains("import 'dart:io'"), isFalse, reason: f.path);
      expect(source.contains('HttpClient'), isFalse, reason: f.path);
      expect(source.contains('package:http'), isFalse, reason: f.path);
      expect(source.contains('http://'), isFalse, reason: f.path);
      expect(source.contains('https://'), isFalse, reason: f.path);
    }
  });
}
