import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

/// API-ready food lookup. Open Food Facts does not require an API key;
/// callers can swap this implementation later for USDA or another provider.
class FoodLookupResult {
  final String barcode;
  final String name;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const FoodLookupResult({
    required this.barcode,
    required this.name,
    this.brand,
    this.caloriesPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
  });

  factory FoodLookupResult.fromOpenFoodFacts(
      String barcode, Map<String, dynamic> data) {
    final nutrients =
        (data['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    double n(String key) => (nutrients[key] as num?)?.toDouble() ?? 0;
    return FoodLookupResult(
      barcode: barcode,
      name: (data['product_name'] as String?)?.trim().isNotEmpty == true
          ? data['product_name'] as String
          : 'Unknown food',
      brand: data['brands'] as String?,
      caloriesPer100g: n('energy-kcal_100g'),
      proteinPer100g: n('proteins_100g'),
      carbsPer100g: n('carbohydrates_100g'),
      fatPer100g: n('fat_100g'),
    );
  }
}

class FoodLookupService {
  final http.Client _client;
  FoodLookupService({
    http.Client? client,
    this.minimumRequestInterval = const Duration(seconds: 7),
  }) : _client = client ?? http.Client();
  final Duration minimumRequestInterval;
  final Map<String, List<FoodLookupResult>> _searchCache = {};
  DateTime? _lastOffRequestAt;
  Future<void> _requestLock = Future<void>.value();

  Future<http.Response> _get(Uri uri) async {
    final previous = _requestLock;
    final next = Completer<void>();
    _requestLock = next.future;
    await previous;
    try {
      final last = _lastOffRequestAt;
      if (last != null) {
        final wait = minimumRequestInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastOffRequestAt = DateTime.now();
      return await _client.get(uri, headers: const {
        'User-Agent': _userAgent
      }).timeout(const Duration(seconds: 8));
    } finally {
      next.complete();
    }
  }

  static const _userAgent = 'WorkLog/0.5 (nutrition lookup)';

  Future<List<FoodLookupResult>> searchByName(String query) async {
    final clean = query.trim();
    if (clean.length < 2 || clean.length > 80) return const [];
    final cacheKey = clean.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;
    final response =
        await _get(Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': clean,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
      'fields': 'code,product_name,brands,nutriments',
    }));
    if (response.statusCode != 200) {
      throw Exception('Food search is temporarily unavailable');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final products = (body['products'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final seen = <String>{};
    final results = products
        .map((product) => FoodLookupResult.fromOpenFoodFacts(
              (product['code'] as String?) ?? '',
              product,
            ))
        .where((food) =>
            food.name != 'Unknown food' &&
            seen.add('${food.name.toLowerCase()}|${food.brand?.toLowerCase()}'))
        .toList();
    _searchCache[cacheKey] = results;
    return results;
  }

  Future<FoodLookupResult?> byBarcode(String barcode) async {
    final clean = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return null;
    final response = await _get(
        Uri.https('world.openfoodfacts.org', '/api/v2/product/$clean.json', {
      'fields': 'product_name,brands,nutriments',
    }));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 1 || body['product'] is! Map) return null;
    return FoodLookupResult.fromOpenFoodFacts(
        clean, (body['product'] as Map).cast<String, dynamic>());
  }

  void dispose() => _client.close();
}
