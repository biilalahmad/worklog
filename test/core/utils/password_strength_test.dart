import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/utils/password_strength.dart';

void main() {
  group('passwordValidationError', () {
    test('requires at least eight characters', () {
      expect(passwordValidationError('a1short'), isNotNull);
    });

    test('requires a letter and a number', () {
      expect(passwordValidationError('onlyletters'), contains('letter'));
      expect(passwordValidationError('12345678'), contains('letter'));
      expect(passwordValidationError('validPass1'), isNull);
    });

    test('rejects passwords longer than 128 characters', () {
      expect(passwordValidationError('${'a' * 127}1'), isNull);
      expect(passwordValidationError('${'a' * 128}1'), contains('128'));
    });
  });
}
