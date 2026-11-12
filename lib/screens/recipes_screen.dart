import 'package:flutter/material.dart';
import '../data/meal_db_api.dart';
import '../models/recipe.dart';
import '../utils/helpers.dart';

const _suggestions = ['Chicken', 'Beef', 'Pasta', 'Fish', 'Rice', 'Salad', 'Soup', 'Cake'];

/// Carte d'accès affichée sur l'écran des repas.
class EntryCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color background, arrowColor;
  final VoidCallback onTap;
  const EntryCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.arrowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ]),
            ),
            Text('›', style: TextStyle(fontSize: 28, color: arrowColor)),
          ]),
        ),
      ),
    );
  }
}

/// Retourne (via Navigator.pop) {'type': ..., 'description': ...} si on ajoute une recette.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _queryCtrl = TextEditingController();
  List<Recipe> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _message;

  Future<void> _run(Future<List<Recipe>> Function() block, String emptyMsg) async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _message = null;
      _results = [];
    });
    try {
      final r = await block();
      if (!mounted) return;
      setState(() {
        _results = r;
        if (r.isEmpty) _message = emptyMsg;
      });
    } catch (e) {
      if (mounted) setState(() => _message = errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String q) {
    if (q.trim().isEmpty) return;
    _queryCtrl.text = q;
    _run(() => MealDbApi.search(q.trim()), 'Aucune recette pour « ${q.trim()} ». Essaie en anglais.');
  }

  Future<void> _open(Recipe recipe) async {
    final type = await showDialog<String>(
      context: context,
      builder: (_) => _RecipeDialog(recipe: recipe),
    );
    if (type == null || !mounted) return;
    final description = 'Une seule portion de la recette « ${recipe.name} » '
        '(la recette complète fait environ 4 portions). '
        'Ingrédients de la recette complète : ${recipe.ingredients.join(", ")}. '
        'Donne les aliments pour UNE portion.';
    Navigator.pop(context, {'type': type, 'description': description});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Text('←', style: TextStyle(fontSize: 26, color: cs.primary)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Idées de repas',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Recettes TheMealDB',
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
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'En anglais : chicken, pasta…',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (!_loading && _queryCtrl.text.trim().isNotEmpty)
                    ? () => _search(_queryCtrl.text)
                    : null,
                child: const Text('🔍'),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                          final r = await MealDbApi.random();
                          return r == null ? <Recipe>[] : [r];
                        }, 'Aucune recette'),
                child: const Text('🎲'),
              ),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestions
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(label: Text(s), onPressed: () => _search(s)),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                children: [
                  if (!_searched)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: [
                        const Text('👨‍🍳', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 10),
                        Text(
                          'Cherche une recette, choisis une suggestion ou tente 🎲 pour une surprise.',
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
                  for (final r in _results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RecipeCard(r: r, onTap: () => _open(r)),
                    ),
                  if (_results.isNotEmpty)
                    Text('Données : TheMealDB. Les recettes sont en anglais.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RemoteImage extends StatelessWidget {
  final String url;
  final double height;
  const _RemoteImage(this.url, {required this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(child: Text('🍽️', style: TextStyle(fontSize: 36)));
    return Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (_, child, p) => p == null ? child : placeholder,
            ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe r;
  final VoidCallback onTap;
  const _RecipeCard({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _RemoteImage(r.imageUrl, height: 170),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                [r.category, r.area].where((e) => e.isNotEmpty).join(' • ') +
                    '  •  ${r.ingredients.length} ingrédients',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RecipeDialog extends StatefulWidget {
  final Recipe recipe;
  const _RecipeDialog({required this.recipe});

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  String type = defaultType();

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(r.name),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _RemoteImage(r.imageUrl, height: 180),
            ),
            const SizedBox(height: 10),
            const Text('Ingrédients', style: TextStyle(fontWeight: FontWeight.bold)),
            ...r.ingredients.map((i) => Text('• $i')),
            const SizedBox(height: 10),
            const Text('Préparation', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(r.instructions, style: const TextStyle(fontSize: 12)),
            const Divider(height: 24),
            const Text('Ajouter à mon journal comme :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: mealTypes
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: t == type,
                        onSelected: (_) => setState(() => type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text('Les calories sont estimées par l\'IA pour une portion (recette divisée par 4).',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        TextButton(
            onPressed: () => Navigator.pop(context, type),
            child: const Text('Ajouter à mon journal')),
      ],
    );
  }
}
