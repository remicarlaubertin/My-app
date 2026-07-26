import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Noms de tables partagés entre SQLite (local) et Supabase (cloud).
class Tables {
  const Tables._();

  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String bills = 'bills';
  static const String investmentTransfers = 'investment_transfers';
  static const String agendaCategories = 'agenda_categories';
  static const String events = 'events';
  static const String tasks = 'tasks';
  static const String goals = 'goals';
  static const String settings = 'settings';

  /// Tables synchronisées avec le cloud, dans l'ordre de dépendance.
  static const List<String> synced = <String>[
    accounts,
    categories,
    agendaCategories,
    transactions,
    budgets,
    bills,
    investmentTransfers,
    events,
    tasks,
    goals,
  ];
}

/// Ouverture et migration de la base SQLite locale.
///
/// Sur Android/iOS, `sqflite` utilise l'implémentation native.
/// Sur Windows/Linux/macOS, on passe par `sqflite_common_ffi`.
class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// À appeler une seule fois au démarrage, avant toute requête.
  static void initFfi() {
    if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final Directory dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final String path = p.join(dir.path, 'budget_app.db');

    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = OFF');
      },
      onCreate: (Database db, int version) async {
        for (final String statement in _schema) {
          await db.execute(statement);
        }
      },
    );
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Supprime toutes les données locales (déconnexion, changement de compte).
  static Future<void> wipe() async {
    final Database db = await instance();
    final Batch batch = db.batch();
    for (final String table in Tables.synced) {
      batch.delete(table);
    }
    batch.delete(Tables.settings);
    await batch.commit(noResult: true);
  }

  static const List<String> _schema = <String>[
    '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      balance REAL NOT NULL DEFAULT 0,
      is_investment INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color INTEGER NOT NULL,
      is_system INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      category_id TEXT,
      account_id TEXT,
      date TEXT NOT NULL,
      description TEXT,
      source TEXT NOT NULL DEFAULT 'manual',
      external_key TEXT,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    'CREATE INDEX idx_tx_date ON transactions (date)',
    'CREATE INDEX idx_tx_external ON transactions (external_key)',
    '''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category_id TEXT,
      amount_limit REAL NOT NULL,
      alert_threshold INTEGER NOT NULL DEFAULT 80,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE bills (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      due_date TEXT NOT NULL,
      category_id TEXT,
      account_id TEXT,
      frequency TEXT NOT NULL DEFAULT 'monthly',
      paid INTEGER NOT NULL DEFAULT 0,
      reminder_days INTEGER NOT NULL DEFAULT 3,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    'CREATE INDEX idx_bill_due ON bills (due_date)',
    '''
    CREATE TABLE investment_transfers (
      id TEXT PRIMARY KEY,
      month TEXT NOT NULL,
      income REAL NOT NULL DEFAULT 0,
      expenses REAL NOT NULL DEFAULT 0,
      invested REAL NOT NULL DEFAULT 0,
      kept REAL NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE agenda_categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color INTEGER NOT NULL,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE events (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      date TEXT NOT NULL,
      start_minutes INTEGER,
      end_minutes INTEGER,
      location TEXT,
      agenda_category_id TEXT,
      recurrence TEXT NOT NULL DEFAULT 'none',
      reminder_minutes INTEGER NOT NULL DEFAULT 60,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    'CREATE INDEX idx_event_date ON events (date)',
    '''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      priority TEXT NOT NULL DEFAULT 'medium',
      due_date TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE goals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0,
      deadline TEXT,
      updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
    '''
    CREATE TABLE settings (
      id TEXT PRIMARY KEY,
      payload TEXT NOT NULL
    )''',
  ];
}
