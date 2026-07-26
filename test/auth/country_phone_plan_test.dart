import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/auth/domain/country.dart';

Country _c(String iso) => Country.all.firstWhere((c) => c.iso == iso);

void main() {
  group('validateNational — strict (sign-up)', () {
    test('accepts real mobile numbers per country', () {
      expect(_c('SY').validateNational('944 123 456'), isNull);
      expect(_c('SY').validateNational('0944123456'), isNull); // trunk zero
      expect(_c('LB').validateNational('71 123 456'), isNull); // 8-digit rule
      expect(_c('LB').validateNational('3123456'), isNull); // 7-digit rule
      expect(_c('EG').validateNational('1001234567'), isNull);
      expect(_c('SA').validateNational('501234567'), isNull);
      expect(_c('FR').validateNational('612345678'), isNull);
      expect(_c('DE').validateNational('1601234567'), isNull); // 10
      expect(_c('DE').validateNational('15123456789'), isNull); // 11
      expect(_c('US').validateNational('4155550132'), isNull);
    });

    test('rejects the junk that used to get through', () {
      expect(_c('SY').validateNational('1234'), 'phoneNotMobile');
      expect(_c('SY').validateNational('0000'), 'phoneRequired');
      expect(_c('EG').validateNational('221234567'), 'phoneNotMobile');
      expect(_c('US').validateNational('1555013212'), 'phoneNotMobile');
    });

    test('separates too-short, too-long and not-a-mobile', () {
      expect(_c('SY').validateNational(''), 'phoneRequired');
      expect(_c('SY').validateNational('944 123'), 'phoneTooShort');
      expect(_c('SY').validateNational('944 123 4567'), 'phoneTooLong');
      // A Syrian landline (11 = Damascus) is not an account-worthy number.
      expect(_c('SY').validateNational('112345678'), 'phoneNotMobile');
      // Half-typed prefix reads as incomplete, not as wrong.
      expect(_c('LB').validateNational('7'), 'phoneTooShort');
    });
  });

  group('validateNational — lenient (sign-in)', () {
    test('keeps length rules but forgives an unknown prefix', () {
      expect(_c('SY').validateNational('112345678', strict: false), isNull);
      expect(_c('SY').validateNational('1234', strict: false), 'phoneTooShort');
      expect(
        _c('SY').validateNational('1234567890', strict: false),
        'phoneTooLong',
      );
    });
  });

  group('toE164', () {
    test('builds the canonical form and refuses invalid input', () {
      expect(_c('SY').toE164('0944 123 456'), '+963944123456');
      expect(_c('FR').toE164('6 12 34 56 78'), '+33612345678');
      expect(_c('SY').toE164('1234'), isNull);
    });
  });

  group('formatNational', () {
    test('groups digits the way the example is grouped', () {
      expect(_c('SY').formatNational('944123456'), '944 123 456');
      expect(_c('SY').formatNational('9441'), '944 1');
      expect(_c('FR').formatNational('612345678'), '6 12 34 56 78');
      expect(_c('IQ').formatNational('7901234567'), '790 123 4567');
    });
  });

  group('normalizeNational (paste)', () {
    test('strips an international prefix or trunk zero when that helps', () {
      final sy = _c('SY');
      expect(sy.normalizeNational('+963 944 123 456'), '944123456');
      expect(sy.normalizeNational('00963944123456'), '944123456');
      expect(sy.normalizeNational('0944123456'), '944123456');
      // Already valid and starting with its own dial code → left alone.
      expect(sy.normalizeNational('963123456'), '963123456');
    });
  });

  test('every country has a plan its own example satisfies', () {
    for (final c in Country.all) {
      expect(
        c.validateNational(c.example),
        isNull,
        reason: '${c.iso} example "${c.example}" fails its own plan',
      );
      expect(
        c.formatNational(c.example.replaceAll(' ', '')),
        c.example,
        reason: '${c.iso} example is not grouped the way the mask groups it',
      );
    }
  });
}
