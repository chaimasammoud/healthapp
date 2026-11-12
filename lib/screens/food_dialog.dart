import 'package:flutter/material.dart';
import '../data/food_search_api.dart';
import '../models/food_item.dart';
import '../models/food_product.dart';
import '../utils/helpers.dart';

/// Résultat : un [FoodItem] (enregistrer) ou la chaîne 'delete' (supprimer).
class FoodDialog extends StatefulWidget {
  final int mealId;
  final FoodItem? item;
  const FoodDialog({super.key, required this.mealId, this.item});

  @override
  State<FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<FoodDialog> {
  late final TextEditingController name, qty, kcal, protein, carbs, fat;
  final searchCtrl = TextEditingController();
  FoodProduct? base;
  List<FoodProduct> results = [];
  bool searching = false;
  String? searchMsg;

  @override
  void initState() {
    super.initState();
    final o = widget.item;
    name = TextEditingController(text: o?.name ?? '');
    qty = TextEditingController(text: o != null ? fmt(o.quantityG) : '');
    kcal = TextEditingController(text: o?.calories.toString() ?? '');
    protein = TextEditingController(text: o != null ? fmt(o.protein) : '');
    carbs = TextEditingController(text: o != null ? fmt(o.carbs) : '');
    fat = TextEditingController(text: o != null ? fmt(o.fat) : '');
  }

  @override
  void dispose() {
    for (final c in [name, qty, kcal, protein, carbs, fat, searchCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // Les données OFF sont pour 100 g
  void applyBase(FoodProduct p, double grams) {
    final f = grams / 100.0;
    kcal.text = (p.kcal100 * f).round().toString();
    protein.text = fmt(round1(p.protein100 * f));
    carbs.text = fmt(round1(p.carbs100 * f));
    fat.text = fmt(round1(p.fat100 * f));
  }

  Future<void> doSearch() async {
    if (searchCtrl.text.trim().isEmpty || searching) return;
    setState(() {
      searching = true;
      searchMsg = null;
      results = [];
    });
    try {
      final r = await FoodSearchApi.search(searchCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        results = r;
        if (r.isEmpty) searchMsg = 'Aucun résultat, essaie un autre mot';
      });
    } catch (e) {
      if (mounted) setState(() => searchMsg = errMsg(e));
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Widget numField(String label, TextEditingController c, {ValueChanged<String>? onChanged}) {
    return Expanded(
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final old = widget.item;

    return AlertDialog(
      title: Text(old == null ? 'Ajouter un aliment' : "Modifier l'aliment"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone de recherche
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔎 Chercher dans Open Food Facts',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => doSearch(),
                          decoration: const InputDecoration(
                            hintText: 'Ex : riz, yaourt, thon',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: searching ? null : doSearch,
                        child: Text(searching ? '…' : 'OK'),
                      ),
                    ]),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (searchMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(searchMsg!, style: TextStyle(color: cs.error, fontSize: 12)),
                      ),
                    ...results.map((p) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  base = p;
                                  name.text = p.name;
                                  if (toNum(qty.text) <= 0) qty.text = '100';
                                  applyBase(p, toNum(qty.text));
                                  results = [];
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                    Text(
                                      (p.brand.isNotEmpty ? '${p.brand} • ' : '') +
                                          '${p.kcal100.round()} kcal / 100 g',
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                    if (base != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            '✅ Valeurs calculées d\'après Open Food Facts. Change la quantité pour les recalculer.',
                            style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 6),
                    Text('Données : Open Food Facts (licence ODbL)',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(children: [
                numField('Quantité (g)', qty, onChanged: (v) {
                  if (base != null && toNum(v) > 0) applyBase(base!, toNum(v));
                }),
                const SizedBox(width: 8),
                numField('Calories', kcal, onChanged: (_) => base = null),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                numField('Prot. (g)', protein, onChanged: (_) => base = null),
                const SizedBox(width: 8),
                numField('Gluc. (g)', carbs, onChanged: (_) => base = null),
                const SizedBox(width: 8),
                numField('Lip. (g)', fat, onChanged: (_) => base = null),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        if (old != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text('Supprimer', style: TextStyle(color: cs.error)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    FoodItem(
                      id: old?.id,
                      mealId: widget.mealId,
                      name: name.text.trim(),
                      quantityG: toNum(qty.text),
                      calories: toNum(kcal.text).toInt(),
                      protein: toNum(protein.text),
                      carbs: toNum(carbs.text),
                      fat: toNum(fat.text),
                    ),
                  ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
