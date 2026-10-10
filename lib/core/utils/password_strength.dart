enum PasswordStrength { tooShort, weak, strong }

/// Passwords need at least eight characters, including a letter and a
/// number. The strength label additionally rewards a mix of letter cases.
PasswordStrength passwordStrengthOf(String value) {
  if (value.length < 8) return PasswordStrength.tooShort;
  final hasUpper = value.contains(RegExp(r'[A-Z]'));
  final hasLower = value.contains(RegExp(r'[a-z]'));
  final hasDigit = value.contains(RegExp(r'[0-9]'));
  if (hasUpper && hasLower && hasDigit) return PasswordStrength.strong;
  return PasswordStrength.weak;
}

String? passwordValidationError(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password';
  if (value.length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return 'Use at least one letter and one number';
  }
  if (value.length > 128) return 'Password must be 128 characters or fewer';
  return null;
}
