import 'package:flutter/foundation.dart';

/// Emits fixed, non-sensitive diagnostics during development only.
void logAppDiagnostic(String message) {
  if (kReleaseMode) return;
  debugPrint(message);
}
