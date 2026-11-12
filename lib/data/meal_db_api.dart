import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

/// API TheMealDB (clé de test publique "1").
class MealDbApi {
  static const _base = 'https://www.themealdb.com/api/json/v1/1/';

  static Future<List<Recipe>> search(String query) => _fetch('search.php', {'s': query});

  static Future<Recipe?> random() async {
    final l = await _fetch('random.php', {});
    return l.isEmpty ? null : l.first;
  }

  static Future<List<Recipe>> _fetch(String path, Map<String, String> params) async {
    final uri = Uri.parse(_base + path).replace(queryParameters: params.isEmpty ? null : params);
    final resp = await http.get(uri).timeout(const Duration(seconds: 40));
    if (resp.statusCode != 200) throw Exception('Erreur TheMealDB ${resp.statusCode}');
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final meals = json['meals'] as List<dynamic>?; // null si rien trouvé
    if (meals == null) return [];
    return meals.map((m) => _parse(m as Map<String, dynamic>)).toList();
  }

  static Recipe _parse(Map<String, dynamic> m) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final name = (m['strIngredient$i'] ?? '').toString().trim();
      final qty = (m['strMeasure$i'] ?? '').toString().trim();
      if (name.isNotEmpty && name != 'null') {
        ingredients.add(qty.isNotEmpty && qty != 'null' ? '$qty $name' : name);
      }
    }
    return Recipe(
      id: (m['idMeal'] ?? '').toString(),
      name: (m['strMeal'] ?? '').toString(),
      category: (m['strCategory'] ?? '').toString(),
      area: (m['strArea'] ?? '').toString(),
      instructions: (m['strInstructions'] ?? '').toString().trim(),
      imageUrl: (m['strMealThumb'] ?? '').toString(),
      ingredients: ingredients,
    );
  }
}
