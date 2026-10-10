import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worklog/features/gym/data/food_lookup_service.dart';

void main() {
  test('searches Open Food Facts by product name and parses nutrients',
      () async {
    var requests = 0;
    final service = FoodLookupService(
      minimumRequestInterval: Duration.zero,
      client: MockClient((request) async {
        requests++;
        expect(request.url.host, 'world.openfoodfacts.org');
        expect(request.url.path, '/cgi/search.pl');
        expect(request.url.queryParameters['search_terms'], 'oat milk');
        expect(request.headers['User-Agent'], contains('WorkLog'));
        return http.Response(
          jsonEncode({
            'products': [
              {
                'code': '123',
                'product_name': 'Oat Drink',
                'brands': 'Example',
                'nutriments': {
                  'energy-kcal_100g': 42,
                  'proteins_100g': 1.1,
                  'carbohydrates_100g': 6.7,
                  'fat_100g': 1.3,
                },
              },
              {'code': '456', 'product_name': ''},
            ],
          }),
          200,
        );
      }),
    );

    final result = await service.searchByName('oat milk');
    expect(result, hasLength(1));
    expect(result.single.name, 'Oat Drink');
    expect(result.single.caloriesPer100g, 42);
    expect(result.single.proteinPer100g, 1.1);
    expect(await service.searchByName('oat milk'), result);
    expect(requests, 1, reason: 'Repeated searches should use the cache.');
    service.dispose();
  });

  test('returns no requests for short query and an empty list for no results',
      () async {
    final service = FoodLookupService(
      minimumRequestInterval: Duration.zero,
      client: MockClient((request) async => http.Response(
            jsonEncode({'products': []}),
            200,
          )),
    );
    expect(await service.searchByName('x'), isEmpty);
    expect(await service.searchByName('zznotfood'), isEmpty);
    service.dispose();
  });

  test('preserves barcode lookup and returns null when product is absent',
      () async {
    final service = FoodLookupService(
      minimumRequestInterval: Duration.zero,
      client: MockClient((request) async {
        expect(request.url.path, '/api/v2/product/12345.json');
        return http.Response(jsonEncode({'status': 0}), 200);
      }),
    );
    expect(await service.byBarcode('12-345'), isNull);
    service.dispose();
  });
}
