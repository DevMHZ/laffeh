import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/env_config.dart';
import 'package:laffeh/core/network/dio_client.dart';

void main() {
  test('mobile route requests cannot pick up a legacy privileged key', () {
    dotenv.loadFromString(envString: 'AI_ROUTE_API_KEY=legacy-secret\n'
        'AI_ROUTE_BASE_URL=https://example.com/api/v1');
    DioClient.reset();
    final options = DioClient.aiRouteDio.options;
    expect(options.baseUrl, 'https://back.laffa.afdal.tech/api/mobile');
    expect(options.headers.containsKey('X-API-Key'), isFalse);
    expect(options.headers['X-Laffa-Mobile-Key'], EnvConfig.laffaMobileAppKey);
    expect(EnvConfig.laffaMobileAppKey, startsWith('laffa_mobile_public_'));
    expect(options.headers.values, isNot(contains('legacy-secret')));
    DioClient.reset();
  });
}
