import 'package:intl/intl.dart';

const int goalKcal = 2000;
const double goalProtein = 100;
const double goalCarbs = 250;
const double goalFat = 70;

const List<String> mealTypes = ['Petit-déj', 'Déjeuner', 'Dîner', 'Snack'];

String mealEmoji(String type) {
  switch (type) {
    case 'Petit-déj':
      return '🌅';
    case 'Déjeuner':
      return '☀️';
    case 'Dîner':
      return '🌙';
    default:
      return '🍎';
  }
}

String defaultType() {
  final h = DateTime.now().hour;
  if (h < 10) return 'Petit-déj';
  if (h < 15) return 'Déjeuner';
  if (h < 18) return 'Snack';
  return 'Dîner';
}

final List<(List<String>, String)> _foodRules = [
  (['oeuf', 'œuf', 'omelette'], '🥚'),
  (['pain', 'toast', 'baguette', 'sandwich'], '🍞'),
  (['riz'], '🍚'),
  (['poulet', 'dinde'], '🍗'),
  (['viande', 'boeuf', 'bœuf', 'steak', 'agneau', 'kebab'], '🥩'),
  (['poisson', 'thon', 'saumon', 'crevette'], '🐟'),
  (['pâtes', 'pates', 'spaghetti', 'macaroni'], '🍝'),
  (['pizza'], '🍕'),
  (['burger'], '🍔'),
  (['salade', 'laitue', 'concombre'], '🥗'),
  (['tomate'], '🍅'),
  (['pomme de terre', 'frite', 'patate'], '🍟'),
  (['pomme'], '🍎'),
  (['banane'], '🍌'),
  (['orange', 'clémentine', 'mandarine'], '🍊'),
  (['fraise'], '🍓'),
  (['raisin'], '🍇'),
  (['lait'], '🥛'),
  (['fromage'], '🧀'),
  (['yaourt', 'yogourt'], '🥣'),
  (['café', 'cafe', 'thé', 'the '], '☕'),
  (['carotte'], '🥕'),
  (['avocat'], '🥑'),
  (['gâteau', 'gateau', 'dessert', 'chocolat', 'biscuit', 'tarte'], '🍰'),
  (['soupe', 'couscous', 'tajine', 'ragoût'], '🍲'),
  (['olive'], '🫒'),
  (['noix', 'amande', 'cacahuète'], '🥜'),
  (['jus', 'eau', 'boisson', 'soda'], '🥤'),
];

String foodEmoji(String name) {
  final n = name.toLowerCase();
  for (final (keys, emoji) in _foodRules) {
    if (keys.any(n.contains)) return emoji;
  }
  return '🍽️';
}

double toNum(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0.0;

String fmt(double d) => d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);

double round1(double x) => (x * 10).round() / 10.0;

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String prettyDate(DateTime d) => cap(DateFormat('EEEE d MMMM', 'fr_FR').format(d));

String errMsg(Object e) => e.toString().replaceFirst('Exception: ', '');
