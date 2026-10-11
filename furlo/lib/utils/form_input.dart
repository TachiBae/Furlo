/// Shared input limits for every text field in the app.
///
/// A field's `maxLength` and the message its validator shows are two halves of
/// one policy, so they are stated once here. Before this, the same `40` was
/// written out as a literal in four screens while `validateDisplayName` held
/// its own copy of both the number and the wording — change one and the other
/// silently lied to the user.
class AppFieldLimits {
  const AppFieldLimits._();

  /// A short label: pet, meal, vet or display name.
  static const int shortName = 40;

  /// A longer label: record title, vaccine or clinic name.
  static const int title = 60;

  /// A postal address. Long enough for a real clinic address, short enough to
  /// stay readable in a list row.
  static const int address = 120;

  /// Free-text notes.
  static const int notes = 200;

  /// A phone number, including the spaces, brackets and dashes people type.
  static const int phone = 20;
}

/// The error shown when a field reaches its [limit].
String maxLengthMessage(int limit) => 'Use $limit characters or fewer';
