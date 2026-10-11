/// User-facing copy that appears in more than one place.
///
/// Sharing the literal is what stops two screens from drifting into two
/// slightly different ways of saying the same thing. One-off strings stay at
/// their call site; only genuinely repeated copy belongs here.
class AppCopy {
  AppCopy._();

  /// Shown beneath a load failure wherever the likeliest cause is the
  /// connection. Used by every record screen's error state and by the app
  /// shell, so the advice reads identically everywhere.
  static const String checkConnection =
      'Check your connection, then try again.';
}
