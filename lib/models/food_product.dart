/// Produit Open Food Facts (valeurs pour 100 g).
class FoodProduct {
  final String name;
  final String brand;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;

  FoodProduct({
    required this.name,
    required this.brand,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
  });
}
