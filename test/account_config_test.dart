import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/env_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('account endpoint switches an installed app to the new host', () async {
    dotenv.loadFromString(
      envString: 'DISPATCH_BASE_URL=https://back.laffa.afdal.tech',
    );
    SharedPreferences.setMockInitialValues({
      'account_service_url_v1': 'https://old.example.com',
      'account_service_anon_key_v1': 'sb_publishable_old',
    });
    final prefs = await SharedPreferences.getInstance();
    final client = Dio();
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, endsWith('/api/mobile/account-config'));
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'url': 'https://auth.afdal.tech',
                'anon_key': 'sb_publishable_new',
              },
            ),
          );
        },
      ),
    );
    await EnvConfig.loadAccountConfig(prefs, client: client);
    expect(EnvConfig.supabaseUrl, 'https://auth.afdal.tech');
    expect(EnvConfig.supabaseAnonKey, 'sb_publishable_new');
    expect(prefs.getString('account_service_url_v1'), 'https://auth.afdal.tech');
  });
}
