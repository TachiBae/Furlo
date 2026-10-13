import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/utils/app_theme.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// WCAG AA (4.5:1) for the readable text/background pairs the app uses.
void main() {
  final palettes = {
    'default': AppPalette.defaultTheme,
    'light': AppPalette.light,
    'dark': AppPalette.dark,
  };
  for (final MapEntry(key: name, value: p) in palettes.entries) {
    group('$name palette', () {
      final pairs = {
        'body text on surface': (p.textPrimary, p.surface),
        'body text on background': (p.textPrimary, p.bg),
        'secondary/placeholder text on surface': (p.textSecondary, p.surface),
        'secondary/placeholder text on background': (p.textSecondary, p.bg),
        'chip text on surfaceAlt': (p.textPrimary, p.surfaceAlt),
        'text on primary buttons': (p.textOnPrimary, p.primary),
        'danger text on surface': (p.danger, p.surface),
      };
      for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
        test(label, () {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$label is ${contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }
}
