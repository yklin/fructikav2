import 'dart:async';
import 'dart:io';
import 'package:fructika/database/sql_select_builder.dart';
import 'package:fructika/models/food.dart';
import 'package:fructika/models/food_group.dart';
import 'package:fructika/shared_preferences_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_rank/sqlite_rank.dart';
import 'package:fructika/database/database_provider.dart';
import 'package:fructika/database/migrations.dart';

class SqlDatabaseProvider extends DatabaseProvider {
  static final SqlDatabaseProvider db = SqlDatabaseProvider._();

  SqlDatabaseProvider._();

  Database _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database;
    } else {
      // if _database is null we instantiate it
      _database = await initDB();
      return _database;
    }
  }

  initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "FoodDB.db");

    return await openDatabase(path, version: 1, onOpen: (db) {},
        onCreate: (Database db, int version) async {
      createTables(db, version);
      populateTables(db, version);
    });
  }

  updateFood(Food food) async {
    final db = await database;

    return await db.update("Food", food.toMap(),
        where: "description = ?", whereArgs: [food.description]);
  }

  updateFoodGroup(FoodGroup foodGroup) async {
    final db = await database;

    return await db.update("FoodGroup", foodGroup.toMap(),
        where: "id = ?", whereArgs: [foodGroup.id]);
  }

  Future<List<Food>> getFavouriteFoods() async {
    final db = await database;
    final result = await db.query("Food", where: "favourite = 1");

    return result.isNotEmpty ? result.map((f) => Food.fromMap(f)).toList() : [];
  }

  Future<List<Food>> searchFoods(
      String searchText, PreferencesHelper preferencesHelper) async {
    final db = await database;
    final includeUnknownFructose = await preferencesHelper.getShowUnknown();
    final searchQuery =
        SqlSelectBuilder.buildSearchQuery(Platform.isIOS, includeUnknownFructose);

    final rows = await db.rawQuery(searchQuery, ["$searchText*"]);

    return rows.isNotEmpty ? _mapAndSortFoods(rows) : [];
  }

  Future<List<Food>> _mapAndSortFoods(List<Map<String, dynamic>> rows) async {
    final foods = rows.map((c) => Food.fromMap(c)).toList();

    if (!Platform.isIOS) {
      foods.sort((f1, f2) => rank(f1.matchinfo).compareTo(rank(f2.matchinfo)));
    }

    return foods;
  }

  Future<List<FoodGroup>> getAllFoodGroups() async {
    final db = await database;
    final result = await db.query("FoodGroup");

    return result.isNotEmpty
        ? result.map((c) => FoodGroup.fromMap(c)).toList()
        : [];
  }
}
