class Meal {
  final int? id;
  final int userId;
  final String date; // yyyy-MM-dd
  final String type;
  final String? photoPath;

  Meal({this.id, this.userId = 1, required this.date, required this.type, this.photoPath});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'userId': userId,
        'date': date,
        'type': type,
        'photoPath': photoPath,
      };

  factory Meal.fromMap(Map<String, dynamic> m) => Meal(
        id: m['id'] as int,
        userId: m['userId'] as int,
        date: m['date'] as String,
        type: m['type'] as String,
        photoPath: m['photoPath'] as String?,
      );
}
