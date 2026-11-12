import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/food_item.dart';
import '../models/meal.dart';
import '../models/meal_with_items.dart';


class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'healthapp.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE meals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER NOT NULL,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            photoPath TEXT
          )''');
        await db.execute('''
          CREATE TABLE food_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mealId INTEGER NOT NULL,
            name TEXT NOT NULL,
            quantityG REAL NOT NULL,
            calories INTEGER NOT NULL,
            protein REAL NOT NULL,
            carbs REAL NOT NULL,
            fat REAL NOT NULL,
            FOREIGN KEY(mealId) REFERENCES meals(id) ON DELETE CASCADE
          )''');
        await db.execute('CREATE INDEX idx_food_mealId ON food_items(mealId)');
      },
    );
  }

  // ----- Repas -----
  Future<int> insertMeal(Meal m) async => (await database).insert('meals', m.toMap());

  Future<void> deleteMeal(int id) async =>
      (await database).delete('meals', where: 'id = ?', whereArgs: [id]);

  Future<List<MealWithItems>> getMealsByDate(String date, int userId) async {
    final db = await database;
    final rows = await db.query('meals',
        where: 'date = ? AND userId = ?', whereArgs: [date, userId], orderBy: 'id');
    final result = <MealWithItems>[];
    for (final r in rows) {
      final meal = Meal.fromMap(r);
      final items = await db.query('food_items', where: 'mealId = ?', whereArgs: [meal.id]);
      result.add(MealWithItems(meal, items.map(FoodItem.fromMap).toList()));
    }
    return result;
  }

  // ----- Aliments -----
  Future<void> insertFood(FoodItem f) async => (await database).insert('food_items', f.toMap());

  Future<void> updateFood(FoodItem f) async =>
      (await database).update('food_items', f.toMap(), where: 'id = ?', whereArgs: [f.id]);

  Future<void> deleteFood(int id) async =>
      (await database).delete('food_items', where: 'id = ?', whereArgs: [id]);
}
