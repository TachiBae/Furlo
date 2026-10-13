import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every form field takes its fill, borders and text styles from the
/// theme's inputDecorationTheme. A screen that sets its own fillColor or
/// OutlineInputBorder makes its fields look different from every other form,
/// and stops following the theme when the palette changes.
void main() {
  test('screens and widgets never restyle form fields themselves', () {
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('fillColor:') ||
              line.contains('OutlineInputBorder(')) {
            offenders.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
