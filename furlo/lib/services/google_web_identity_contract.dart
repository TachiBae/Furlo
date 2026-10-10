/// Outcome of a Google Identity Services prompt "moment" callback.
///
/// Kept platform-neutral (no JS interop) so the mapping is unit-testable.
enum GisMomentOutcome {
  /// The in-page chooser is showing — wait for the credential callback.
  shown,

  /// Nothing was displayed (no session, FedCM unavailable, blocked) — the
  /// caller should fall back to the popup-window flow.
  fallback,

  /// The user dismissed the chooser — treat as a cancelled sign-in.
  cancel,
}

GisMomentOutcome gisMomentOutcome(String type) => switch (type) {
  'notDisplayed' || 'skipped' => GisMomentOutcome.fallback,
  'dismissed' => GisMomentOutcome.cancel,
  _ => GisMomentOutcome.shown,
};
