import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_product.dart';

/// API Open Food Facts (valeurs pour 100 g).
class FoodSearchApi {
  static const _baseUrls = [
    'https://world.openfoodfacts.net/cgi/search.pl',
    'https://fr.openfoodfacts.org/cgi/search.pl',
    'https://world.openfoodfacts.org/cgi/search.pl',
  ];

  static Future<List<FoodProduct>> search(String query) async {
    Object? lastError;
    for (final base in _baseUrls) {
      try {
        final products = await _fetch(base, query);
        if (products != null) return products;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ??
        Exception('Le serveur Open Food Facts est temporairement indisponible. Réessaie dans quelques instants.');
  }

  static double? _num(Map<String, dynamic> n, String key) {
    final v = n[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static Future<List<FoodProduct>?> _fetch(String base, String query) async {
    final uri = Uri.parse(base).replace(queryParameters: {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
      'fields': 'product_name,brands,nutriments',
    });

    final resp = await http.get(uri, headers: {
      'User-Agent': 'HealthApp - Flutter - Version 1.0',
    }).timeout(const Duration(seconds: 25));

    if (resp.statusCode == 429) throw Exception('Trop de recherches, attends une minute.');
    if ([502, 503, 504].contains(resp.statusCode)) return null;
    if (resp.statusCode < 200 || resp.statusCode > 299) {
      throw Exception('Erreur Open Food Facts (${resp.statusCode})');
    }

    final body = utf8.decode(resp.bodyBytes);
    if (!body.trim().startsWith('{')) return null;

    final json = jsonDecode(body) as Map<String, dynamic>;
    final products = json['products'] as List<dynamic>? ?? [];

    final list = <FoodProduct>[];
    final seen = <String>{};
    for (final p in products) {
      final map = p as Map<String, dynamic>;
      final name = (map['product_name'] ?? '').toString().trim();
      final n = map['nutriments'] as Map<String, dynamic>?;
      if (n == null) continue;
      final kcal = _num(n, 'energy-kcal_100g') ??
          (_num(n, 'energy_100g') != null ? _num(n, 'energy_100g')! / 4.184 : null);
      if (name.isEmpty || kcal == null) continue;
      if (!seen.add(name.toLowerCase())) continue;
      list.add(FoodProduct(
        name: name,
        brand: (map['brands'] ?? '').toString().split(',').first.trim(),
        kcal100: kcal,
        protein100: _num(n, 'proteins_100g') ?? 0,
        carbs100: _num(n, 'carbohydrates_100g') ?? 0,
        fat100: _num(n, 'fat_100g') ?? 0,
      ));
      if (list.length == 10) break;
    }
    return list;
  }
}
