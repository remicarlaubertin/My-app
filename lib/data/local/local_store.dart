import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import 'database.dart';

/// Accès générique à la base SQLite locale.
///
/// Les modèles produisent des `Map` avec des types natifs (bool, double…).
/// SQLite ne connaît pas les booléens : la conversion est centralisée ici,
/// ce qui évite de la répéter dans chaque modèle.
class LocalStore {
  const LocalStore();

  Future<Database> get _db => AppDatabase.instance();

  static Map<String, Object?> encode(Map<String, dynamic> map) {
    final Map<String, Object?> out = <String, Object?>{};
    map.forEach((String key, dynamic value) {
      if (value is bool) {
        out[key] = value ? 1 : 0;
      } else if (value is DateTime) {
        out[key] = value.toUtc().toIso8601String();
      } else if (value is Enum) {
        out[key] = value.name;
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Toutes les lignes vivantes (non supprimées) d'une table.
  Future<List<Map<String, dynamic>>> readAll(String table) async {
    final Database db = await _db;
    return db.query(table, where: 'deleted = 0');
  }

  /// Lignes modifiées localement et pas encore envoyées au cloud.
  Future<List<Map<String, dynamic>>> readDirty(String table) async {
    final Database db = await _db;
    return db.query(table, where: 'dirty = 1');
  }

  /// Écrit une ligne et la marque comme « à synchroniser ».
  Future<void> upsert(String table, Map<String, dynamic> values) async {
    final Database db = await _db;
    final Map<String, Object?> row = encode(values)..['dirty'] = 1;
    await db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMany(
    String table,
    List<Map<String, dynamic>> rows, {
    bool markDirty = true,
  }) async {
    if (rows.isEmpty) return;
    final Database db = await _db;
    final Batch batch = db.batch();
    for (final Map<String, dynamic> values in rows) {
      final Map<String, Object?> row = encode(values)
        ..['dirty'] = markDirty ? 1 : 0;
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Suppression logique : la ligne reste en base pour que l'effacement
  /// se propage aux autres appareils lors de la prochaine synchronisation.
  Future<void> softDelete(String table, String id) async {
    final Database db = await _db;
    await db.update(
      table,
      <String, Object?>{
        'deleted': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> clearDirty(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    final Database db = await _db;
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    await db.update(
      table,
      <String, Object?>{'dirty': 0},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Renvoie la date de modification connue localement pour chaque id.
  Future<Map<String, String>> updatedAtIndex(String table) async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows =
        await db.query(table, columns: <String>['id', 'updated_at']);
    return <String, String>{
      for (final Map<String, dynamic> r in rows)
        r['id'].toString(): r['updated_at'].toString(),
    };
  }

  // -------------------------------------------------------------------------
  // Réglages
  // -------------------------------------------------------------------------

  Future<AppSettings> readSettings() async {
    final Database db = await _db;
    final List<Map<String, dynamic>> rows = await db.query(
      Tables.settings,
      where: 'id = ?',
      whereArgs: <Object?>['local'],
      limit: 1,
    );
    if (rows.isEmpty) return const AppSettings();
    try {
      final Map<String, dynamic> data =
          jsonDecode(rows.first['payload'].toString()) as Map<String, dynamic>;
      return AppSettings.fromMap(data);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> writeSettings(AppSettings settings) async {
    final Database db = await _db;
    await db.insert(
      Tables.settings,
      <String, Object?>{
        'id': 'local',
        'payload': jsonEncode(settings.toMap()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Vrai si la base n'a jamais été remplie (premier lancement).
  Future<bool> isEmpty() async {
    final Database db = await _db;
    final Object? count = (await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.categories}',
    ))
        .first['c'];
    return (count is int ? count : 0) == 0;
  }
}
