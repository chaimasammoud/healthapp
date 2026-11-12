import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../data/database_helper.dart';
import '../data/meal_analyzer.dart';
import '../models/detected_food.dart';
import '../models/food_item.dart';
import '../models/meal.dart';
import '../models/meal_with_items.dart';
import '../utils/helpers.dart';
import 'food_dialog.dart';
import 'food_search_screen.dart';
import 'recipes_screen.dart';

enum SortOption {
  recent('Récents'),
  oldest('Anciens'),
  kcalDesc('Plus caloriques'),
  kcalAsc('Moins caloriques'),
  type('Type de repas');

  final String label;
  const SortOption(this.label);
}

class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  final _db = DatabaseHelper.instance;
  static const int _userId = 1; // utilisateur fixe pour l'instant

  DateTime _date = DateTime.now();
  List<MealWithItems> _meals = [];
  bool _loading = false;
  String _query = '';
  SortOption _sort = SortOption.recent;

  String get _dateIso => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _db.getMealsByDate(_dateIso, _userId);
    if (!mounted) return;
    setState(() => _meals = m);
  }

  void _changeDay(int offset) {
    setState(() => _date = DateTime(_date.year, _date.month, _date.day + offset));
    _load();
  }

  void _goToday() {
    setState(() => _date = DateTime.now());
    _load();
  }

  /// Repas filtrés par la recherche et triés.
  List<MealWithItems> get _shown {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<MealWithItems>.from(_meals)
        : _meals
            .where((mw) =>
                mw.meal.type.toLowerCase().contains(q) ||
                mw.items.any((i) => i.name.toLowerCase().contains(q)))
            .toList();
    switch (_sort) {
      case SortOption.recent:
        filtered.sort((a, b) => b.meal.id!.compareTo(a.meal.id!));
      case SortOption.oldest:
        filtered.sort((a, b) => a.meal.id!.compareTo(b.meal.id!));
      case SortOption.kcalDesc:
        filtered.sort((a, b) => b.totalCalories.compareTo(a.totalCalories));
      case SortOption.kcalAsc:
        filtered.sort((a, b) => a.totalCalories.compareTo(b.totalCalories));
      case SortOption.type:
        filtered.sort((a, b) =>
            mealTypes.indexOf(a.meal.type).compareTo(mealTypes.indexOf(b.meal.type)));
    }
    return filtered;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ----- Actions repas -----
  Future<void> _addManualMeal(String type) async {
    await _db.insertMeal(Meal(userId: _userId, date: _dateIso, type: type));
    await _load();
  }

  Future<String> _savePhoto(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/meal_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _analyzeAndSave(
    String type,
    Future<List<DetectedFood>> Function() analyze, {
    Uint8List? photo,
  }) async {
    setState(() => _loading = true);
    try {
      final foods = await analyze();
      final path = photo != null ? await _savePhoto(photo) : null;
      final mealId = await _db.insertMeal(
          Meal(userId: _userId, date: _dateIso, type: type, photoPath: path));
      for (final f in foods) {
        await _db.insertFood(FoodItem(
          mealId: mealId,
          name: f.name,
          quantityG: f.quantityG,
          calories: f.calories,
          protein: f.protein,
          carbs: f.carbs,
          fat: f.fat,
        ));
      }
      await _load();
    } catch (e) {
      _showError(errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto(String type, ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      await _analyzeAndSave(type, () => MealAnalyzer.analyzePhoto(bytes), photo: bytes);
    } catch (e) {
      _showError('Impossible de récupérer la photo');
    }
  }

  Future<void> _describeMeal(String type) async {
    final mealCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Décris ton repas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: mealCtrl,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                  labelText: 'Repas / Aliments',
                  hintText: 'Ex : Escalope, riz, yaourt...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                  labelText: 'Quantité (g)',
                  hintText: 'Ex : 200',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(
              onPressed: mealCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      final meal = mealCtrl.text.trim();
                      final qty = qtyCtrl.text.trim();
                      final combined = qty.isNotEmpty ? '$qty g de $meal' : meal;
                      Navigator.pop(ctx, combined);
                    },
              child: const Text('Analyser'),
            ),
          ],
        ),
      ),
    );

    if (text != null) {
      await _analyzeAndSave(type, () => MealAnalyzer.analyzeText(text));
    }
  }

  Future<bool> _confirm(String title, String text) async {
    final cs = Theme.of(context).colorScheme;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Supprimer', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _deleteMeal(MealWithItems mw) async {
    final ok = await _confirm('Supprimer ce repas ?',
        'Le repas « ${mw.meal.type} » et ses ${mw.items.length} aliment(s) seront supprimés. Cette action est définitive.');
    if (!ok) return;
    await _db.deleteMeal(mw.meal.id!);
    final p = mw.meal.photoPath;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    await _load();
  }

  // ----- Actions aliments -----
  Future<void> _openFoodDialog(int mealId, FoodItem? item) async {
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => FoodDialog(mealId: mealId, item: item),
    );
    if (result is FoodItem) {
      if (result.id == null) {
        await _db.insertFood(result);
      } else {
        await _db.updateFood(result);
      }
    } else if (result == 'delete' && item != null) {
      final ok = await _confirm('Supprimer cet aliment ?', '« ${item.name} » sera retiré de ce repas.');
      if (ok) await _db.deleteFood(item.id!);
    }
    await _load();
  }

  // ----- Navigation -----
  Future<void> _openSearch() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()));

  Future<void> _openRecipes() async {
    final res = await Navigator.push<Map<String, String>>(
        context, MaterialPageRoute(builder: (_) => const RecipesScreen()));
    if (res != null) {
      await _analyzeAndSave(res['type']!, () => MealAnalyzer.analyzeText(res['description']!));
    }
  }

  // ----- Feuille d'ajout -----
  void _openAddSheet() {
    var type = defaultType();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajouter un repas',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: mealTypes
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${mealEmoji(t)} $t'),
                                selected: t == type,
                                onSelected: (_) => setS(() => type = t),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionRow('📷', 'Prendre une photo', "L'IA estime les calories de ton assiette", () {
                  Navigator.pop(ctx);
                  _pickPhoto(type, ImageSource.camera);
                }),
                const SizedBox(height: 10),
                _ActionRow('🖼️', 'Importer une photo', 'Choisis une image de ta galerie', () {
                  Navigator.pop(ctx);
                  _pickPhoto(type, ImageSource.gallery);
                }),
                const SizedBox(height: 10),
                _ActionRow('✍️', 'Décrire mon repas', 'Ex : 2 œufs, du pain et un café', () {
                  Navigator.pop(ctx);
                  _describeMeal(type);
                }),
                const SizedBox(height: 10),
                _ActionRow('➕', 'Ajout manuel', 'Crée le repas et saisis les aliments', () {
                  Navigator.pop(ctx);
                  _addManualMeal(type);
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- UI -----
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = _shown;

    final children = <Widget>[
      _DateBar(date: _date, onPrev: () => _changeDay(-1), onNext: () => _changeDay(1), onToday: _goToday),
      _SummaryCard(meals: _meals),
      EntryCard(
        emoji: '🔎',
        title: "Calories d'un aliment",
        subtitle: 'Cherche riz, pain, yaourt… et découvre ses valeurs',
        background: cs.secondaryContainer,
        arrowColor: cs.secondary,
        onTap: _openSearch,
      ),
      EntryCard(
        emoji: '👨‍🍳',
        title: 'Idées de repas',
        subtitle: 'Découvre des recettes et ajoute-les à ton journal',
        background: cs.primaryContainer,
        arrowColor: cs.primary,
        onTap: _openRecipes,
      ),
      if (_meals.isNotEmpty) _buildSearchSortBar(cs),
      if (_loading)
        Card(
          color: cs.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Analyse du repas…', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              LinearProgressIndicator(color: cs.secondary, borderRadius: BorderRadius.circular(20)),
            ]),
          ),
        ),
      if (_meals.isEmpty && !_loading)
        _EmptyState(onAdd: _openAddSheet)
      else if (shown.isEmpty && _meals.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Aucun résultat pour « $_query »',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        )
      else
        ...shown.map((mw) => _MealCard(
              key: ValueKey(mw.meal.id),
              mw: mw,
              onDeleteMeal: () => _deleteMeal(mw),
              onAddFood: () => _openFoodDialog(mw.meal.id!, null),
              onEditFood: (f) => _openFoodDialog(mw.meal.id!, f),
            )),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
        label: const Text('＋  Ajouter un repas', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    );
  }

  Widget _buildSearchSortBar(ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: '🔍  Rechercher un aliment ou un repas',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Text('Trier :  ', style: TextStyle(color: cs.onSurfaceVariant)),
          ...SortOption.values.map((o) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(o.label),
                  selected: o == _sort,
                  onSelected: (_) => setState(() => _sort = o),
                ),
              )),
        ]),
      ),
    ]);
  }
}

// ---------- Composants ----------

class _DateBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev, onNext, onToday;
  const _DateBar({required this.date, required this.onPrev, required this.onNext, required this.onToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(onPressed: onPrev, icon: Text('‹', style: TextStyle(fontSize: 30, color: cs.primary))),
      InkWell(
        onTap: onToday,
        child: Column(children: [
          Text(prettyDate(date), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(isToday ? "Aujourd'hui" : "Revenir à aujourd'hui",
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      ),
      IconButton(onPressed: onNext, icon: Text('›', style: TextStyle(fontSize: 30, color: cs.primary))),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  final List<MealWithItems> meals;
  const _SummaryCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = meals.expand((m) => m.items).toList();
    final kcal = items.fold<int>(0, (s, i) => s + i.calories);
    final protein = items.fold<double>(0, (s, i) => s + i.protein);
    final carbs = items.fold<double>(0, (s, i) => s + i.carbs);
    final fat = items.fold<double>(0, (s, i) => s + i.fat);
    final remaining = goalKcal - kcal;

    return Card(
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: (kcal / goalKcal).clamp(0.0, 1.0),
                    strokeWidth: 11,
                    color: cs.secondary,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$kcal',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  Text('kcal', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total du jour',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Objectif : $goalKcal kcal',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 6),
                Text(
                  remaining >= 0 ? 'Il te reste $remaining kcal' : 'Dépassé de ${-remaining} kcal',
                  style: TextStyle(
                      color: remaining >= 0 ? Colors.white : cs.secondary,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          _MacroBar('Protéines', protein, goalProtein, const Color(0xFF7FD8A8)),
          const SizedBox(height: 10),
          _MacroBar('Glucides', carbs, goalCarbs, const Color(0xFFFFC27A)),
          const SizedBox(height: 10),
          _MacroBar('Lipides', fat, goalFat, const Color(0xFFF08FA3)),
        ]),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value, goal;
  final Color color;
  const _MacroBar(this.label, this.value, this.goal, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        Text('${fmt(value)} / ${goal.toInt()} g',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: (value / goal).clamp(0.0, 1.0),
          minHeight: 8,
          color: color,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    ]);
  }
}

class _MealCard extends StatelessWidget {
  final MealWithItems mw;
  final VoidCallback onDeleteMeal, onAddFood;
  final ValueChanged<FoodItem> onEditFood;
  const _MealCard({
    super.key,
    required this.mw,
    required this.onDeleteMeal,
    required this.onAddFood,
    required this.onEditFood,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photo = mw.meal.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Text(mealEmoji(mw.meal.type), style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mw.meal.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${mw.items.length} aliment${mw.items.length > 1 ? "s" : ""}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
            Text('${mw.totalCalories} kcal',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 17)),
            IconButton(onPressed: onDeleteMeal, icon: const Text('🗑️', style: TextStyle(fontSize: 18))),
          ]),
          if (hasPhoto) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(File(photo), height: 170, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          if (mw.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (var i = 0; i < mw.items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: cs.surfaceContainerHighest),
              _FoodRow(item: mw.items[i], onTap: () => onEditFood(mw.items[i])),
            ],
          ],
          const SizedBox(height: 4),
          TextButton(onPressed: onAddFood, child: const Text('＋ Ajouter un aliment')),
        ]),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;
  const _FoodRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Text(foodEmoji(item.name), style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cap(item.name), style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '${fmt(item.quantityG)} g  •  P ${fmt(item.protein)}  G ${fmt(item.carbs)}  L ${fmt(item.fat)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          Text('${item.calories} kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback onTap;
  const _ActionRow(this.emoji, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withValues(alpha: 0.75))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(children: [
        const Text('🥗', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        const Text('Aucun repas ce jour', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          "Prends ton assiette en photo ou décris ton repas : l'app calcule les calories pour toi.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        ElevatedButton(onPressed: onAdd, child: const Text('Ajouter mon premier repas')),
      ]),
    );
  }
}
