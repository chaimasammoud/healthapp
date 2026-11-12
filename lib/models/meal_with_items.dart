import 'meal.dart';
import 'food_item.dart';

class MealWithItems {
  final Meal meal;
  final List<FoodItem> items;
  MealWithItems(this.meal, this.items);

  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
}
