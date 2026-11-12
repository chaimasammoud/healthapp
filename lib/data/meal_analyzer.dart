import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/detected_food.dart';
import 'app_config.dart';

/// Analyse un repas (photo ou texte) avec l'API Gemini (palier gratuit).
class MealAnalyzer {
  static const _prompt = '''Tu es un nutritionniste. Identifie chaque aliment du repas,
estime la quantité en grammes et les valeurs nutritionnelles (pour la quantité estimée).
Réponds UNIQUEMENT avec du JSON au format :
{"items":[{"name":"...","quantity_g":0,"calories":0,"protein":0,"carbs":0,"fat":0}]}
Noms en français. Si ce n'est pas de la nourriture, renvoie {"items":[]}.''';

  static Future<List<DetectedFood>> analyzePhoto(Uint8List jpegBytes) {
    final parts = [
      {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Encode(jpegBytes)}},
      {'text': _prompt},
    ];
    return _call(parts);
  }

  static Future<List<DetectedFood>> analyzeText(String description) {
    return _call([
      {'text': '$_prompt\n\nRepas : $description'}
    ]);
  }

  static Future<List<DetectedFood>> _call(List<Map<String, dynamic>> parts) async {
    final apiKey = AppConfig.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('Clé GEMINI_API_KEY manquante (voir data/app_config.dart)');
    }
    final payload = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    final models = {AppConfig.geminiModel, 'gemini-flash-latest', 'gemini-flash-lite-latest'}.toList();
    var lastError = 'Erreur inconnue';

    for (final model in models) {
      try {
        final resp = await http
            .post(
              Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: payload,
            )
            .timeout(const Duration(seconds: 20));
        final text = utf8.decode(resp.bodyBytes);

        if (resp.statusCode >= 200 && resp.statusCode <= 299) return _parse(text);

        lastError = 'Erreur API ${resp.statusCode} : ${_apiMessage(text)}';
        if (![500, 502, 503, 504].contains(resp.statusCode)) {
          break; // Si 400 ou 403 (clé invalide), arrêt direct
        }
      } catch (e) {
        lastError = e is Exception ? e.toString().replaceAll('Exception: ', '') : '$e';
      }
    }
    throw Exception(lastError);
  }

  static String _apiMessage(String body) {
    try {
      final m = (jsonDecode(body)['error']['message'] as String);
      return m.length > 150 ? m.substring(0, 150) : m;
    } catch (_) {
      return 'réponse inattendue';
    }
  }

  static List<DetectedFood> _parse(String text) {
    final candidates = jsonDecode(text)['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception("Image ou texte refusé par l'IA");
    }
    final answer = (candidates[0]['content']['parts'][0]['text'] as String)
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final items = jsonDecode(answer)['items'] as List<dynamic>;
    if (items.isEmpty) throw Exception('Aucun aliment reconnu');
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return items.map((e) {
      return DetectedFood(
        name: e['name'].toString(),
        quantityG: d(e['quantity_g']),
        calories: d(e['calories']).round(),
        protein: d(e['protein']),
        carbs: d(e['carbs']),
        fat: d(e['fat']),
      );
    }).toList();
  }
}
