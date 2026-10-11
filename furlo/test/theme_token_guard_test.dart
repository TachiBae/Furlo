import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to contain raw design values.
///
/// `app_theme.dart` defines the tokens themselves. `export_service.dart`
/// styles a printable PDF document — a separate medium with its own page
/// palette that is never rendered through the app theme.
const _tokenDefinitionFiles = {
  'lib/utils/app_theme.dart',
  'lib/services/export_service.dart',
};

/// `Colors.transparent` is the explicit "no colour" sentinel rather than a
/// design colour, so it does not have — and does not need — a theme token.
final _noColourSentinel = RegExp(r'Colors\.transparent');

String _normalise(String path) => path.replaceAll(r'\', '/');

List<File> _libSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

List<String> _offenders(
  List<File> files,
  bool Function(String line) violates, {
  bool Function(String path) skip = _neverSkip,
}) {
  final found = <String>[];
  for (final file in files) {
    final path = _normalise(file.path);
    if (skip(path)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (violates(lines[i])) {
        found.add('$path:${i + 1}  ${lines[i].trim()}');
      }
    }
  }
  return found;
}

bool _neverSkip(String path) => false;

void main() {
  final sources = _libSources();

  test('the lib scan actually found the Dart sources', () {
    expect(sources, isNotEmpty);
    expect(sources.length, greaterThan(40));
    expect(
      sources.map((file) => _normalise(file.path)),
      containsAll(<String>[
        'lib/utils/app_theme.dart',
        'lib/screens/home/home_screen.dart',
      ]),
    );
  });

  test('no raw fontSize literal outside the typography tokens', () {
    final fontSize = RegExp(r'fontSize:\s*[0-9]');
    final offenders = _offenders(
      sources,
      fontSize.hasMatch,
      skip: _tokenDefinitionFiles.contains,
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Use an AppTypography token instead of a raw fontSize:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no raw Color(...) literal outside the theme palette', () {
    final offenders = _offenders(
      sources,
      (line) => line.contains('Color(0x') || line.contains('Color(0X'),
      skip: (path) => path == 'lib/utils/app_theme.dart',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Use an AppPalette token instead of a raw Color:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no Colors.* usage outside the theme palette', () {
    final anyColorsReference = RegExp(r'\bColors\.');
    final offenders = _offenders(sources, (line) {
      final withoutSentinel = line.replaceAll(_noColourSentinel, '');
      return anyColorsReference.hasMatch(withoutSentinel);
    }, skip: (path) => path == 'lib/utils/app_theme.dart');
    expect(
      offenders,
      isEmpty,
      reason:
          'Use context.appColors (or Colors.transparent) instead of Colors.*:\n'
          '${offenders.join('\n')}',
    );
  });
}
