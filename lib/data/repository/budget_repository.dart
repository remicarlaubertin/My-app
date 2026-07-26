import '../local/database.dart';
import '../local/local_store.dart';
import '../local/seed_data.dart';
import '../models/agenda_models.dart';
import '../models/app_settings.dart';
import '../models/finance_models.dart';
import '../models/sync_entity.dart';

/// Instantané complet des données de l'utilisateur.
///
/// L'application est volontairement « offline first » : toutes les vues lisent
/// cet objet en mémoire, alimenté par SQLite. Le cloud ne fait qu'alimenter
/// SQLite à son tour.
class BudgetData {
  const BudgetData({
    this.accounts = const <Account>[],
    this.categories = const <Category>[],
    this.transactions = const <Txn>[],
    this.budgets = const <Budget>[],
    this.bills = const <Bill>[],
    this.transfers = const <InvestmentTransfer>[],
    this.agendaCategories = const <AgendaCategory>[],
    this.events = const <AgendaEvent>[],
    this.tasks = const <AgendaTask>[],
    this.goals = const <Goal>[],
    this.settings = const AppSettings(),
  });

  final List<Account> accounts;
  final List<Category> categories;
  final List<Txn> transactions;
  final List<Budget> budgets;
  final List<Bill> bills;
  final List<InvestmentTransfer> transfers;
  final List<AgendaCategory> agendaCategories;
  final List<AgendaEvent> events;
  final List<AgendaTask> tasks;
  final List<Goal> goals;
  final AppSettings settings;

  BudgetData copyWith({
    List<Account>? accounts,
    List<Category>? categories,
    List<Txn>? transactions,
    List<Budget>? budgets,
    List<Bill>? bills,
    List<InvestmentTransfer>? transfers,
    List<AgendaCategory>? agendaCategories,
    List<AgendaEvent>? events,
    List<AgendaTask>? tasks,
    List<Goal>? goals,
    AppSettings? settings,
  }) =>
      BudgetData(
        accounts: accounts ?? this.accounts,
        categories: categories ?? this.categories,
        transactions: transactions ?? this.transactions,
        budgets: budgets ?? this.budgets,
        bills: bills ?? this.bills,
        transfers: transfers ?? this.transfers,
        agendaCategories: agendaCategories ?? this.agendaCategories,
        events: events ?? this.events,
        tasks: tasks ?? this.tasks,
        goals: goals ?? this.goals,
        settings: settings ?? this.settings,
      );
}

/// Couche d'accès aux données : lit et écrit dans SQLite, jamais dans l'UI.
class BudgetRepository {
  const BudgetRepository(this._store);

  final LocalStore _store;

  LocalStore get store => _store;

  /// Remplit la base au tout premier lancement.
  Future<void> ensureSeeded() async {
    if (!await _store.isEmpty()) return;

    await _store.upsertMany(
      Tables.accounts,
      SeedData.accounts().map((Account a) => a.toMap()).toList(),
    );
    await _store.upsertMany(
      Tables.categories,
      SeedData.categories().map((Category c) => c.toMap()).toList(),
    );
    await _store.upsertMany(
      Tables.agendaCategories,
      SeedData.agendaCategories()
          .map((AgendaCategory c) => c.toMap())
          .toList(),
    );
    await _store.writeSettings(const AppSettings());
  }

  Future<BudgetData> loadAll() async {
    final List<Map<String, dynamic>> accounts =
        await _store.readAll(Tables.accounts);
    final List<Map<String, dynamic>> categories =
        await _store.readAll(Tables.categories);
    final List<Map<String, dynamic>> transactions =
        await _store.readAll(Tables.transactions);
    final List<Map<String, dynamic>> budgets =
        await _store.readAll(Tables.budgets);
    final List<Map<String, dynamic>> bills = await _store.readAll(Tables.bills);
    final List<Map<String, dynamic>> transfers =
        await _store.readAll(Tables.investmentTransfers);
    final List<Map<String, dynamic>> agendaCategories =
        await _store.readAll(Tables.agendaCategories);
    final List<Map<String, dynamic>> events =
        await _store.readAll(Tables.events);
    final List<Map<String, dynamic>> tasks = await _store.readAll(Tables.tasks);
    final List<Map<String, dynamic>> goals = await _store.readAll(Tables.goals);
    final AppSettings settings = await _store.readSettings();

    final List<Txn> txns =
        transactions.map(Txn.fromMap).toList()
          ..sort((Txn a, Txn b) => b.date.compareTo(a.date));

    return BudgetData(
      accounts: accounts.map(Account.fromMap).toList(),
      categories: categories.map(Category.fromMap).toList(),
      transactions: txns,
      budgets: budgets.map(Budget.fromMap).toList(),
      bills: bills.map(Bill.fromMap).toList()
        ..sort((Bill a, Bill b) => a.dueDate.compareTo(b.dueDate)),
      transfers: transfers.map(InvestmentTransfer.fromMap).toList()
        ..sort((InvestmentTransfer a, InvestmentTransfer b) =>
            b.month.compareTo(a.month)),
      agendaCategories: agendaCategories.map(AgendaCategory.fromMap).toList(),
      events: events.map(AgendaEvent.fromMap).toList(),
      tasks: tasks.map(AgendaTask.fromMap).toList()
        ..sort((AgendaTask a, AgendaTask b) => a.dueDate.compareTo(b.dueDate)),
      goals: goals.map(Goal.fromMap).toList(),
      settings: settings,
    );
  }

  Future<void> save(String table, SyncEntity entity) =>
      _store.upsert(table, entity.toMap());

  Future<void> saveMany(String table, List<SyncEntity> entities) =>
      _store.upsertMany(
        table,
        entities.map((SyncEntity e) => e.toMap()).toList(),
      );

  Future<void> remove(String table, String id) => _store.softDelete(table, id);

  Future<void> saveSettings(AppSettings settings) =>
      _store.writeSettings(settings);

  /// Empreintes déjà connues (import CSV) — sert à écarter les doublons.
  Future<Set<String>> knownExternalKeys() async {
    final List<Map<String, dynamic>> rows =
        await _store.readAll(Tables.transactions);
    return rows
        .map((Map<String, dynamic> r) => asString(r['external_key']))
        .where((String k) => k.isNotEmpty)
        .toSet();
  }
}
