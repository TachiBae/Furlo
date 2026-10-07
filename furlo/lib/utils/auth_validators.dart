String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password';
  if (value.length < 8) return 'Use at least 8 characters';
  return null;
}

/// Sign-in only requires a password to be present: existing accounts may
/// predate the current 8-character creation policy.
String? validateSignInPassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password';
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'Confirm your password';
  if (value != password) return 'Passwords do not match';
  return null;
}
