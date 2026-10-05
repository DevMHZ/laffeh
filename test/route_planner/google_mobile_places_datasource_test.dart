import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/route_planner/data/datasources/google_mobile_places_datasource.dart';

void main() {
  test('parses Google predictions and honours backend fallback', () async {
    var google = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: google
                  ? {
                      'provider': 'google',
                      'predictions': [
                        {
                          'place_id': 'ChIJ12345678',
                          'name': 'Hospital',
                          'context': 'Beirut',
                        },
                      ],
                    }
                  : {'provider': 'fallback'},
            ),
          );
        },
      ),
    );
    final source = GoogleMobilePlacesDataSource(dio);

    final predictions = await source.autocomplete('Hospital');
    expect(predictions.single.placeId, 'ChIJ12345678');
    expect(predictions.single.fullLabel, 'Hospital, Beirut');
    google = false;
    expect(await source.autocomplete('Hospital'), isEmpty);
  });

  test('parses coordinates and returns null on backend fallback', () async {
    var google = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: google
                  ? {
                      'provider': 'google',
                      'result': {
                        'lat': 33.9,
                        'lon': 35.5,
                        'label': 'Beirut',
                        'place_id': 'ChIJ12345678',
                      },
                    }
                  : {'provider': 'fallback'},
            ),
          );
        },
      ),
    );
    final source = GoogleMobilePlacesDataSource(dio);

    final point = await source.geocode('Beirut');
    expect(point?.point.latitude, 33.9);
    expect(point?.point.longitude, 35.5);
    google = false;
    expect(await source.resolve('ChIJ12345678'), isNull);
  });
}
