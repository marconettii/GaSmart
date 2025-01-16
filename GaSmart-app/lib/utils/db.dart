import 'package:GaSmart/models/vehicle.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DB {
  static Future<void> _createTables(Database db) async {
    print('[+] db creating tables');
    await db.execute("""
      CREATE TABLE veicoli(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marca TEXT,
        modello TEXT,
        anno TEXT,
        editable INTEGER,
        classe TEXT,
        kmL INTEGER,
        carburante TEXT
      )
    """);
    await db.execute("""
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY,
        veicolo INTEGER,
        risparmio INTEGER,
        inquinamento INTEGER,
        raggio INTEGER
      )
    """);
    await db.execute("""
      CREATE TABLE spese(
        id INTEGER PRIMARY KEY,
        amount REAL,
        liters REAL,
        day INTEGER,
        month INTEGER,
        year INTEGER
      )
    """);
    await db.insert('settings', {
      "id": 1,
      "veicolo": 0,
      "risparmio": 0,
      "inquinamento": 1,
      "raggio": 5
    });
  }

  static Future<Database> _db() async =>
      await openDatabase(join(await getDatabasesPath(), 'gasmart.db'),
          onCreate: (db, version) => _createTables(db), version: 2);

  static Future<void> deleteDatabase() async => await databaseFactory
      .deleteDatabase(join(await getDatabasesPath(), 'gasmart.db'));

  static Future<void> insertVehicle(Vehicle v) async =>
      await (await _db()).insert('veicoli', v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> insertVehicleMap(Map<String, dynamic> v) async =>
      await (await _db())
          .insert('veicoli', v, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> updateVehicleMap(Map<String, dynamic> v) async =>
      await (await _db())
          .update('veicoli', v, where: 'id = ?', whereArgs: [v["id"]]);

  static Future<void> deleteVehicle(int id) async =>
      await (await _db()).delete('veicoli', where: 'id = ?', whereArgs: [id]);

  static Future<List<Map<String, dynamic>>> getVehicles() async =>
      await (await _db()).query('veicoli', orderBy: 'editable');

  static Future<Vehicle> getVehicle(int id) async => Vehicle.fromMap(
      (await (await _db()).query('veicoli', where: 'id = ?', whereArgs: [id]))
          .first);

  static Future<void> updateSettings(Map<String, dynamic> s) async =>
      await (await _db()).update('settings', s);

  static Future<List<Map<String, dynamic>>> getSettings() async =>
      await (await _db()).query('settings');

  static Future<void> insertSpesa(Map<String, dynamic> v) async =>
      await (await _db()).insert('spese', v);

  static Future<List<Map<String, dynamic>>> getSpese(
          int month, int year) async =>
      await (await _db()).query('spese',
          where: 'month = ? and year = ?',
          whereArgs: [month, year],
          orderBy: 'day');

  static Future<void> deleteSpeseMese(int month, int year) async =>
      await (await _db()).delete('spese',
          where: 'month = ? and year = ?', whereArgs: [month, year]);

  static Future<void> deleteSpese() async =>
      await (await _db()).delete('spese');
}
