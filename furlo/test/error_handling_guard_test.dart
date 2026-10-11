import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Error-handling guards.
///
/// An empty `catch` is the shape a bug hides in: the operation fails, the user
/// is told nothing, and nothing lands in the diagnostics either. This audit
/// found four; the guard stops a fifth from arriving unnoticed.
///
/// Scope note: the guard targets *empty* blocks, in every catch form. It
/// deliberately does not require a comment on every catch - most handlers here
/// correctly surface a message or set an error state, and demanding prose on
/// each one would be noise, not safety. A catch with a comment but no statement
/// is allowed: that is a documented, deliberate silence.
void main() {
  final sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String readable(String path) => path.replaceAll(r'\', '/');

  test('the lib scan actually found the Dart sources', () {
    expect(sources, isNotEmpty);
    expect(sources.length, greaterThan(40));
  });

  test('no catch block is empty on a single line', () {
    // Every catch form, not just the broad `catch (_)`.
    final empty = RegExp(r'catch\s*(\([^)]*\))?\s*on\s+[^{]+\{\s*\}');
    final bare = RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}');
    final offenders = <String>[];
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (empty.hasMatch(lines[i]) || bare.hasMatch(lines[i])) {
          offenders.add('${readable(file.path)}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a swallowed error must at least log a diagnostic or explain itself '
          'in a comment:\n${offenders.join('\n')}',
    );
  });

  test('no catch block is empty across multiple lines', () {
    final opener = RegExp(
      r'catch\s*(\([^)]*\))?\s*on\s+[^{]*\{\s*$|catch\s*\([^)]*\)\s*\{\s*$',
    );
    final offenders = <String>[];
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!opener.hasMatch(lines[i])) continue;
        // Only a block that closes immediately is empty. A comment on the
        // next line is a documented silence and is allowed.
        final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
        if (next == '}') {
          offenders.add('${readable(file.path)}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a swallowed error must at least log a diagnostic or explain itself '
          'in a comment:\n${offenders.join('\n')}',
    );
  });

  test('the guards actually inspect the catches in this tree', () {
    var catchCount = 0;
    for (final file in sources) {
      for (final line in file.readAsLinesSync()) {
        if (line.contains('catch')) catchCount++;
      }
    }
    expect(
      catchCount,
      greaterThan(40),
      reason:
          'the scan should be seeing the whole error-handling surface; if this '
          'drops, the guards above have stopped meaning anything',
    );
  });
}
