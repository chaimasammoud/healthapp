class Recipe {
  final String id;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String imageUrl;
  final List<String> ingredients;

  Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    required this.imageUrl,
    required this.ingredients,
  });
}
