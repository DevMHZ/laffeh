import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/form_validators.dart';

void main() {
  group('password', () {
    test('required / too short / ok', () {
      expect(FormValidators.password(''), 'passwordRequired');
      expect(FormValidators.password(null), 'passwordRequired');
      expect(FormValidators.password('1234567'), 'passwordTooShort');
      expect(FormValidators.password('12345678'), isNull);
    });
  });

  group('passwordConfirm', () {
    test('empty / mismatch / match', () {
      expect(
        FormValidators.passwordConfirm('abcdefgh', ''),
        'passwordConfirmRequired',
      );
      expect(
        FormValidators.passwordConfirm('abcdefgh', 'abcdefgX'),
        'passwordMismatch',
      );
      expect(FormValidators.passwordConfirm('abcdefgh', 'abcdefgh'), isNull);
    });
  });

  group('fullName', () {
    test('required / too short / numeric / valid (multi-script)', () {
      expect(FormValidators.fullName(''), 'nameRequired');
      expect(FormValidators.fullName('  '), 'nameRequired');
      expect(FormValidators.fullName('a'), 'nameTooShort');
      expect(FormValidators.fullName('12345'), 'nameNumeric');
      expect(FormValidators.fullName('Mohamad Alzoubi'), isNull);
      expect(FormValidators.fullName('محمد الزعبي'), isNull);
      expect(FormValidators.fullName('Jean-Pierre'), isNull);
      expect(FormValidators.fullName('a' * 121), 'nameTooLong');
    });
  });

  group('companyName', () {
    test('required / too short / too long / valid', () {
      expect(FormValidators.companyName(''), 'companyRequired');
      expect(FormValidators.companyName(null), 'companyRequired');
      // Whitespace is not a company name — sign-up must not accept it.
      expect(FormValidators.companyName('   '), 'companyRequired');
      expect(FormValidators.companyName('A'), 'companyTooShort');
      expect(FormValidators.companyName('Afdal'), isNull);
      expect(FormValidators.companyName('أفضل'), isNull);
      expect(FormValidators.companyName('x' * 161), 'companyTooLong');
    });
  });
}
