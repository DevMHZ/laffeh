import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/utils/device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates, persists and reuses a stable device id', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final first = await DeviceId.getOrCreate(prefs);
    expect(first, isNotEmpty);
    expect(prefs.getString(AppStrings.deviceIdKey), first);

    final second = await DeviceId.getOrCreate(prefs);
    expect(second, first);
  });
}
