import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../data/food_search_api.dart';
import '../models/food_item.dart';
import '../models/food_product.dart';
import '../models/meal.dart';
import '../utils/helpers.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _queryCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  List<FoodProduct> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _message;

  double get _grams {
    final g = double.tryParse(_gramsCtrl.text.replaceAll(',', '.')) ?? 100.0;
    return g < 0 ? 0 : g;
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _message = null;
      _results = [];
    });
    try {
      final r = await FoodSearchApi.search(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        if (r.isEmpty) _message = 'Aucun résultat pour « $q »';
      });
    } catch (e) {
      if (mounted) setState(() => _message = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grams = _grams;
    final factor = grams / 100.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Text('←', style: TextStyle(fontSize: 26, color: cs.primary)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Calories d'un aliment",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Base de données Open Food Facts',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Ex : riz, pain, yaourt…',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (!_loading && _queryCtrl.text.trim().isNotEmpty) ? _search : null,
                  child: const Text('🔍'),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Quantité (g)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Les valeurs se recalculent pour cette quantité.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
              ]),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  children: [
                    if (!_searched)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          const Text('🔎', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 10),
                          Text(
                            "Écris le nom d'un aliment pour connaître ses calories, protéines, glucides et lipides.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ]),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_message!,
                            textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                      ),
                    for (final p in _results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ResultCard(p: p, factor: factor, grams: grams),
                      ),
                    if (_results.isNotEmpty)
                      Text(
                        'Données : Open Food Facts (licence ODbL). Base collaborative : les valeurs peuvent varier d\'un produit à l\'autre.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final FoodProduct p;
  final double factor;
  final double grams;
  const _ResultCard({required this.p, required this.factor, required this.grams});

  Future<void> _addFoodToJournal(BuildContext context) async {
    final dateIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String selectedType = defaultType();

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajouter ${cap(p.name)} (${fmt(grams)} g)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Choisir le moment du repas :'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: mealTypes
                      .map((t) => ChoiceChip(
                            label: Text('${mealEmoji(t)} $t'),
                            selected: selectedType == t,
                            onSelected: (_) => setS(() => selectedType = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Text('➕'),
                    label: Text('Valider (${(p.kcal100 * factor).round()} kcal)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    final db = DatabaseHelper.instance;
    final meals = await db.getMealsByDate(dateIso, 1);
    int mealId;
    final existing = meals.where((m) => m.meal.type == selectedType).firstOrNull;
    if (existing != null) {
      mealId = existing.meal.id!;
    } else {
      mealId = await db.insertMeal(Meal(userId: 1, date: dateIso, type: selectedType));
    }

    await db.insertFood(FoodItem(
      mealId: mealId,
      name: cap(p.name),
      quantityG: grams,
      calories: (p.kcal100 * factor).round(),
      protein: round1(p.protein100 * factor),
      carbs: round1(p.carbs100 * factor),
      fat: round1(p.fat100 * factor),
    ));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${cap(p.name)} (${fmt(grams)} g) ajouté au journal !')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cap(p.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (p.brand.isNotEmpty)
            Text(p.brand, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(p.kcal100 * factor).round()}',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('kcal pour ${fmt(grams)} g', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _MacroChip('Protéines', p.protein100 * factor, const Color(0xFFE3F6EA)),
            const SizedBox(width: 8),
            _MacroChip('Glucides', p.carbs100 * factor, const Color(0xFFFFF0DC)),
            const SizedBox(width: 8),
            _MacroChip('Lipides', p.fat100 * factor, const Color(0xFFFDE6EA)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addFoodToJournal(context),
              icon: const Text('➕'),
              label: Text('Ajouter au journal (${fmt(grams)} g)'),
            ),
          ),
          if (grams != 100.0) ...[
            const SizedBox(height: 8),
            Text('Pour 100 g : ${p.kcal100.round()} kcal',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color bg;
  const _MacroChip(this.label, this.value, this.bg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text('${fmt(value)} g', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }
}
