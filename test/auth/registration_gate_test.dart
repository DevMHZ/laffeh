import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/registration_config.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/services/registration_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes a skip timestamp [ago] in the past, the way a user who skipped that
/// long ago would have left it.
Map<String, Object> skippedAgo(Duration ago) => {
  AppStrings.registrationSkippedAtKey: DateTime.now()
      .toUtc()
      .subtract(ago)
      .toIso8601String(),
};

Future<RegistrationGate> gateWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return RegistrationGate(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const grace = RegistrationConfig.gracePeriod;

  test('a user who never skipped is not on the clock', () async {
    final gate = await gateWith({});
    expect(gate.skippedAt, isNull);
    expect(gate.remaining, isNull);
    expect(gate.isRequired, isFalse);
    expect(gate.isCountingDown, isFalse);
  });

  test('skipping starts the clock and only the first skip counts', () async {
    final gate = await gateWith({});
    await gate.markSkipped();
    final first = gate.skippedAt;
    expect(first, isNotNull);

    // A second skip must not push the deadline back.
    await gate.markSkipped();
    expect(gate.skippedAt, first);
  });

  test('inside the week the app stays open', () async {
    final gate = await gateWith(skippedAgo(const Duration(days: 6)));
    expect(gate.isRequired, isFalse);
    expect(gate.daysLeft, 1);
  });

  test('after the week an account is required', () async {
    final gate = await gateWith(skippedAgo(grace));
    expect(gate.isRequired, isTrue);
    expect(gate.remaining, Duration.zero);
    expect(gate.daysLeft, 0);
    // Well past the deadline stays required, not wrapped around.
    final later = await gateWith(skippedAgo(const Duration(days: 400)));
    expect(later.isRequired, isTrue);
  });

  test('the countdown only starts near the deadline', () async {
    final early = await gateWith(skippedAgo(const Duration(days: 1)));
    expect(early.isCountingDown, isFalse);

    final late = await gateWith(skippedAgo(grace - const Duration(days: 2)));
    expect(late.isCountingDown, isTrue);
    expect(late.daysLeft, 2);

    // Expired is not "counting down" — it is over.
    final over = await gateWith(skippedAgo(grace));
    expect(over.isCountingDown, isFalse);
  });

  test('daysLeft rounds up so the final hours still read as a day', () async {
    final gate = await gateWith(skippedAgo(grace - const Duration(hours: 3)));
    expect(gate.daysLeft, 1);
  });

  test('a clock that jumped backwards cannot stretch the trial', () async {
    // Timestamp in the future: the device clock was ahead when it was written.
    final gate = await gateWith({
      AppStrings.registrationSkippedAtKey: DateTime.now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String(),
    });
    expect(gate.remaining, grace);
    expect(gate.isRequired, isFalse);
  });

  test('a corrupt timestamp is treated as never skipped', () async {
    final gate = await gateWith({
      AppStrings.registrationSkippedAtKey: 'not-a-date',
    });
    expect(gate.skippedAt, isNull);
    expect(gate.isRequired, isFalse);
  });

  test('signing in stops the clock and a later skip restarts it', () async {
    final gate = await gateWith(skippedAgo(grace));
    expect(gate.isRequired, isTrue);

    await gate.clear();
    expect(gate.isRequired, isFalse);
    expect(gate.skippedAt, isNull);

    await gate.markSkipped();
    expect(gate.isRequired, isFalse);
    expect(gate.daysLeft, grace.inDays);
  });

  group('trial countdown copy', () {
    tearDown(() => AppStrings.setLocale(const Locale('en')));

    test('English pluralises', () {
      AppStrings.setLocale(const Locale('en'));
      expect(AppStrings.trialDaysLeft(1), contains('1 day left'));
      expect(AppStrings.trialDaysLeft(3), contains('3 days left'));
    });

    test('Arabic follows MSA number agreement', () {
      AppStrings.setLocale(const Locale('ar'));
      expect(AppStrings.trialDaysLeft(1), contains('يوم واحد'));
      expect(AppStrings.trialDaysLeft(2), contains('يومان'));
      expect(AppStrings.trialDaysLeft(3), contains('3 أيام'));
      expect(AppStrings.trialDaysLeft(12), contains('12 يوماً'));
    });
  });
}
