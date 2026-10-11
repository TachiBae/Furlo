import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Copy cohesion guards.
///
/// Each of these pins a single wording so a second, subtly different phrasing
/// cannot reappear. The auth table in particular was previously duplicated in
/// two files, so changing one left the other stale.
void main() {
  final sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String readable(String path) => path.replaceAll(r'\', '/');

  Map<String, List<int>> matches(RegExp pattern) {
    final found = <String, List<int>>{};
    for (final file in sources) {
      final hits = <int>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) hits.add(i + 1);
      }
      if (hits.isNotEmpty) found[readable(file.path)] = hits;
    }
    return found;
  }

  test('the lib scan actually found the Dart sources', () {
    expect(sources.length, greaterThan(40));
  });

  test('the auth copy table is defined in exactly one place', () {
    final definitions = matches(RegExp(r'AuthErrorCode\.networkError\s*=>'));
    final total = definitions.values.fold<int>(0, (n, hits) => n + hits.length);
    expect(
      total,
      1,
      reason:
          'there must be one source of truth for auth copy, found:\n'
          '${definitions.entries.map((e) => '${e.key}:${e.value}').join('\n')}',
    );
  });

  test('there is one wording for the "check your connection" hint', () {
    final offenders = matches(
      RegExp(r'check your internet', caseSensitive: false),
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'use "Check your connection, then try again." instead:\n'
          '${offenders.entries.map((e) => '${e.key}:${e.value}').join('\n')}',
    );

    final canonical = matches(
      RegExp(r"Check your connection, then try again\."),
    );
    expect(
      canonical.values.fold<int>(0, (n, hits) => n + hits.length),
      1,
      reason: 'the hint should be defined once, not copied per screen',
    );
  });

  test('save buttons read plainly "Save"', () {
    final offenders = matches(
      RegExp(r"'Save (entry|record|vaccination|pet|vet|changes)'"),
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'use a plain "Save" so every form ends with the same verb:\n'
          '${offenders.entries.map((e) => '${e.key}:${e.value}').join('\n')}',
    );
  });

  test('delete confirmations are sentence-case questions', () {
    final titles = matches(RegExp(r"title: '(Delete[^']*)'"));
    expect(
      titles,
      isNotEmpty,
      reason: 'the delete-confirm titles should still be findable',
    );
    final offenders = <String>[];
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = RegExp(r"title: '(Delete[^']*)'").firstMatch(lines[i]);
        if (match == null) continue;
        final title = match.group(1)!;
        if (!RegExp(r'^Delete [a-z][a-z ]*\?$').hasMatch(title)) {
          offenders.add('${readable(file.path)}:${i + 1}  $title');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'delete confirmations should read "Delete <thing>?" in sentence '
          'case:\n${offenders.join('\n')}',
    );
  });

  test('load failures all use the same verb pattern', () {
    final offenders = <String>[];
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Only user-visible copy; diagnostics are logged, not shown.
        if (line.contains('logAppDiagnostic') || line.contains('debugPrint')) {
          continue;
        }
        final match = RegExp(
          r"'([A-Z][^']*(?:load|save|delete|update) failed[^']*)'",
        ).firstMatch(line);
        if (match != null) {
          offenders.add('${readable(file.path)}:${i + 1}  ${match.group(1)}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'user-visible failures use "<Thing> could not be loaded." rather '
          'than "<Thing> failed":\n${offenders.join('\n')}',
    );
  });
}
