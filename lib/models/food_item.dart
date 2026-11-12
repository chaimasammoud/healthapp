class FoodItem {
  final int? id;
  final int mealId;
  final String name;
  final double quantityG;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodItem({
    this.id,
    required this.mealId,
    required this.name,
    required this.quantityG,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'mealId': mealId,
        'name': name,
        'quantityG': quantityG,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
        id: m['id'] as int,
        mealId: m['mealId'] as int,
        name: m['name'] as String,
        quantityG: (m['quantityG'] as num).toDouble(),
        calories: (m['calories'] as num).toInt(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbs'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
      );
}
