import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.digitsOnly', () {
    test('strips spaces, symbols and letters', () {
      expect(PhoneUtils.digitsOnly(' +963 (944) 123-456 '), '963944123456');
      expect(PhoneUtils.digitsOnly('abc123'), '123');
      expect(PhoneUtils.digitsOnly(''), '');
    });
  });

  group('PhoneUtils.toE164', () {
    test('builds canonical numbers and trims trunk zero', () {
      expect(
        PhoneUtils.toE164(dialCode: '+963', national: '0944123456'),
        '+963944123456',
      );
      expect(
        PhoneUtils.toE164(dialCode: '963', national: ' 944 123 456 '),
        '+963944123456',
      );
      expect(
        PhoneUtils.toE164(dialCode: '+33', national: '0612345678'),
        '+33612345678',
      );
      expect(
        PhoneUtils.toE164(dialCode: '+971', national: '501234567'),
        '+971501234567',
      );
    });

    test('returns null for empty or too-short input', () {
      expect(PhoneUtils.toE164(dialCode: '+963', national: ''), isNull);
      expect(PhoneUtils.toE164(dialCode: '', national: '944123456'), isNull);
      expect(PhoneUtils.toE164(dialCode: '+963', national: '0'), isNull);
      expect(PhoneUtils.toE164(dialCode: '+1', national: '12'), isNull);
    });
  });

  group('PhoneUtils.isValidE164', () {
    test('accepts valid and rejects invalid', () {
      expect(PhoneUtils.isValidE164('+963944123456'), isTrue);
      expect(PhoneUtils.isValidE164('+33612345678'), isTrue);
      expect(PhoneUtils.isValidE164('963944123456'), isFalse); // no +
      expect(PhoneUtils.isValidE164('+0963944'), isFalse); // leading 0
      expect(PhoneUtils.isValidE164('+123'), isFalse); // too short
    });
  });
}
