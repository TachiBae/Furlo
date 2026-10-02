String? validateVetPhone(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return 'Phone number is required';
  if (!RegExp(r'^[+0-9().\- ]+$').hasMatch(input)) {
    return 'Enter a valid phone number';
  }
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) {
    return 'Enter a valid phone number';
  }
  return null;
}

String? validateVetEmail(String? value) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)
      ? null
      : 'Enter a valid email address';
}
