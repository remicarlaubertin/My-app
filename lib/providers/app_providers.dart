import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/date_helpers.dart';
import '../data/local/database.dart';
import '../data/local/local_store.dart';
import '../data/models/agenda_models.dart';
import '../data/models/app_settings.dart';
import '../data/models/finance_models.dart';
import '../data/remote/auth_service.dart';
import '../data/remote/sync_service.dart';
import '../data/repository/budget_repository.dart';
import '../data/repository/budget_selectors.dart';
import '../features/notifications/notification_service.dart';

const Uuid _uuid = Uuid();

final Provider<LocalStore> localStoreProvider =
    Provider<LocalStore>((Ref ref) => const LocalStore());

final Provider<BudgetRepository> repositoryProvider =
    Provider<BudgetRepository>(
  (Ref ref) => BudgetRepository(ref.watch(localStoreProvider)),
);

final Provider<AuthService> authServiceProvider =
    Provider<AuthService>((Ref ref) => const AuthService());

final Provider<SyncService> syncServiceProvider = Provider<SyncService>(
  (Ref ref) => SyncService(ref.watch(localStoreProvider)),
);

/// État global de l'application.
class AppState {
  const AppState({
    this.data = const BudgetData(),
    this.loading = true,
    this.syncing = false,
    this.message,
  });

  final BudgetData data;
  final bool loading;
  final bool syncing;
  final String? message;

  AppState copyWith({
    BudgetData? data,
    bool? loading,
    bool? syncing,
    String? message,
    bool clearMessage = false,
  }) =>
      AppState(
        data: data ?? this.data,
        loading: loading ?? this.loading,
        syncing: syncing ?? this.syncing,
        message: clearMessage ? null : (message ?? this.message),
      );
}

/// Toutes les écritures passent par ce notifier : il écrit dans SQLite,
/// recharge l'état, puis met les notifications à jour.
class AppNotifier extends StateNotifier<AppState> {
  AppNotifier(this._repo, this._sync) : super(const AppState());

  final BudgetRepository _repo;
  final SyncService _sync;

  BudgetData get data => state.data;

  Future<void> bootstrap() async {
    await _repo.ensureSeeded();
    await reload();
    await NotificationService.init();
    await _maybeRunAutomaticTransfer();
    await NotificationService.refresh(state.data);
    if (_sync.available) {
      await synchronize(silent: true);
    }
  }

  Future<void> reload() async {
    final BudgetData loaded = await _repo.loadAll();
    state = state.copyWith(data: loaded, loading: false);
  }

  void notify(String message) =>
      state = state.copyWith(message: message);

  void clearMessage() => state = state.copyWith(clearMessage: true);

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  Future<void> saveTransaction({
    String? id,
    required TxnType type,
    required double amount,
    required String categoryId,
    required String accountId,
    required String date,
    String description = '',
    String source = 'manual',
    String? externalKey,
  }) async {
    final Txn txn = Txn(
      id: id ?? _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      date: date,
      description: description,
      source: source,
      externalKey: externalKey,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.transactions, txn);
    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> deleteTransaction(String id) async {
    await _repo.remove(Tables.transactions, id);
    await reload();
  }

  /// Import CSV : ajoute plusieurs transactions d'un coup.
  Future<int> importTransactions(List<Txn> transactions) async {
    if (transactions.isEmpty) return 0;
    await _repo.saveMany(Tables.transactions, transactions);
    await reload();
    await NotificationService.refresh(state.data);
    return transactions.length;
  }

  // ---------------------------------------------------------------------------
  // Catégories
  // ---------------------------------------------------------------------------

  Future<void> saveCategory({
    String? id,
    required String name,
    required TxnType type,
    required int color,
  }) async {
    final Category category = Category(
      id: id ?? _uuid.v4(),
      name: name,
      type: type,
      color: color,
      isSystem: false,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.categories, category);
    await reload();
  }

  Future<bool> deleteCategory(String id) async {
    final bool used =
        state.data.transactions.any((Txn t) => t.categoryId == id);
    if (used) return false;
    await _repo.remove(Tables.categories, id);
    await reload();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Comptes
  // ---------------------------------------------------------------------------

  Future<void> saveAccount({
    String? id,
    required String name,
    required double openingBalance,
    bool isInvestment = false,
  }) async {
    final Account account = Account(
      id: id ?? _uuid.v4(),
      name: name,
      balance: openingBalance,
      isInvestment: isInvestment,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.accounts, account);
    await reload();
  }

  Future<void> deleteAccount(String id) async {
    await _repo.remove(Tables.accounts, id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------------------

  Future<void> saveBudget({
    String? id,
    required String name,
    required String categoryId,
    required double amountLimit,
    required int alertThreshold,
  }) async {
    final Budget budget = Budget(
      id: id ?? _uuid.v4(),
      name: name,
      categoryId: categoryId,
      amountLimit: amountLimit,
      alertThreshold: alertThreshold,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.budgets, budget);
    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> deleteBudget(String id) async {
    await _repo.remove(Tables.budgets, id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // Factures
  // ---------------------------------------------------------------------------

  Future<void> saveBill({
    String? id,
    required String name,
    required double amount,
    required String dueDate,
    required String categoryId,
    required String accountId,
    required BillFrequency frequency,
    int reminderDays = 3,
    bool paid = false,
  }) async {
    final Bill bill = Bill(
      id: id ?? _uuid.v4(),
      name: name,
      amount: amount,
      dueDate: dueDate,
      categoryId: categoryId,
      accountId: accountId,
      frequency: frequency,
      paid: paid,
      reminderDays: reminderDays,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.bills, bill);
    await reload();
    await NotificationService.refresh(state.data);
  }

  /// Marque une facture payée : crée la transaction correspondante et,
  /// si la facture est récurrente, prépare l'échéance suivante.
  Future<void> markBillPaid(Bill bill) async {
    final Txn txn = Txn(
      id: _uuid.v4(),
      type: TxnType.expense,
      amount: bill.amount,
      categoryId: bill.categoryId,
      accountId: bill.accountId,
      date: DateHelpers.todayIso(),
      description: 'Facture payée : ${bill.name}',
      source: 'bill',
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(Tables.transactions, txn);
    await _repo.save(Tables.bills, bill.copyWith(paid: true));

    if (bill.frequency != BillFrequency.once) {
      final DateTime due = DateHelpers.fromIso(bill.dueDate);
      final DateTime next;
      if (bill.frequency == BillFrequency.weekly) {
        next = due.add(const Duration(days: 7));
      } else if (bill.frequency == BillFrequency.yearly) {
        next = DateTime(due.year + 1, due.month, due.day);
      } else {
        next = DateHelpers.addMonths(due, 1);
      }
      await _repo.save(
        Tables.bills,
        Bill(
          id: _uuid.v4(),
          name: bill.name,
          amount: bill.amount,
          dueDate: DateHelpers.toIso(next),
          categoryId: bill.categoryId,
          accountId: bill.accountId,
          frequency: bill.frequency,
          reminderDays: bill.reminderDays,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> deleteBill(String id) async {
    await _repo.remove(Tables.bills, id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // Investissements
  // ---------------------------------------------------------------------------

  Future<void> setHideAmounts(bool hidden) =>
      updateSettings(state.data.settings.copyWith(hideAmounts: hidden));

  Future<void> setInvestmentEnabled(bool enabled) =>
      updateSettings(state.data.settings.copyWith(investmentEnabled: enabled));

  Future<void> setInvestmentPercent(int percent) => updateSettings(
      state.data.settings.copyWith(investmentPercent: percent));

  /// Exécute le transfert de fin de mois pour le mois précédent.
  ///
  /// Solde restant = revenus − dépenses ; `percent` % partent vers le compte
  /// investissement. Un même mois ne peut être transféré qu'une seule fois.
  Future<String> runInvestmentTransfer({DateTime? month}) async {
    final AppSettings settings = state.data.settings;
    if (!settings.investmentEnabled) {
      return 'Active la règle avant de lancer un transfert.';
    }

    final DateTime now = DateTime.now();
    final DateTime target =
        month ?? DateTime(now.year, now.month - 1, 1);
    final String key =
        '${target.year}-${target.month.toString().padLeft(2, '0')}';

    final bool already = state.data.transfers
        .any((InvestmentTransfer t) => t.month == key);
    if (already) {
      return 'Le transfert de ce mois a déjà été effectué.';
    }

    final double income = state.data.incomeOfMonth(target);
    final double expenses = state.data.expensesOfMonth(target);
    final double remaining = income - expenses;
    final double invested =
        remaining > 0 ? remaining * settings.investmentPercent / 100 : 0;

    await _repo.save(
      Tables.investmentTransfers,
      InvestmentTransfer(
        id: _uuid.v4(),
        month: key,
        income: income,
        expenses: expenses,
        invested: invested,
        kept: remaining - invested,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _repo.saveSettings(
      settings.copyWith(lastAutoTransferMonth: key),
    );
    await reload();

    return invested > 0
        ? 'Transfert effectué vers le compte Investissements.'
        : 'Aucun montant à transférer pour ce mois.';
  }

  /// Annule un transfert vers les investissements (ex. montant erroné).
  /// Le solde des deux comptes est automatiquement recalculé, puisqu'il
  /// dépend de la somme des transferts encore présents.
  Future<void> deleteInvestmentTransfer(String id) async {
    await _repo.remove(Tables.investmentTransfers, id);
    await reload();
  }

  /// Au démarrage : si on a changé de mois et que la règle est active,
  /// le transfert du mois précédent est exécuté automatiquement.
  Future<void> _maybeRunAutomaticTransfer() async {
    final AppSettings settings = state.data.settings;
    if (!settings.investmentEnabled) return;

    final DateTime now = DateTime.now();
    final DateTime previous = DateTime(now.year, now.month - 1, 1);
    final String key =
        '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
    if (settings.lastAutoTransferMonth == key) return;

    await runInvestmentTransfer(month: previous);
  }

  // ---------------------------------------------------------------------------
  // Agenda
  // ---------------------------------------------------------------------------

  Future<void> saveEvent(AgendaEvent event) async {
    await _repo.save(Tables.events, event);
    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> deleteEvent(String id) async {
    await _repo.remove(Tables.events, id);
    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> saveTask(AgendaTask task) async {
    await _repo.save(Tables.tasks, task);
    await reload();
  }

  Future<void> toggleTask(AgendaTask task) async {
    await _repo.save(Tables.tasks, task.copyWith(done: !task.done));
    await reload();
  }

  Future<void> deleteTask(String id) async {
    await _repo.remove(Tables.tasks, id);
    await reload();
  }

  Future<void> saveGoal(Goal goal) async {
    await _repo.save(Tables.goals, goal);
    await reload();
  }

  Future<void> deleteGoal(String id) async {
    await _repo.remove(Tables.goals, id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // Réglages et synchronisation
  // ---------------------------------------------------------------------------

  Future<void> updateSettings(AppSettings settings) async {
    await _repo.saveSettings(settings);
    await reload();
    await NotificationService.refresh(state.data);
  }

  Future<void> synchronize({bool silent = false}) async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true);
    final SyncResult result = await _sync.synchronize();
    await reload();
    state = state.copyWith(
      syncing: false,
      message: silent && result.ok
          ? null
          : (result.ok
              ? 'Synchronisation terminée — ${result.pushed} envoyé(s), '
                  '${result.pulled} reçu(s).'
              : result.error),
    );
    if (result.ok) await NotificationService.refresh(state.data);
  }

  /// Efface les données locales (déconnexion) et repart d'une base neuve.
  Future<void> resetLocalData() async {
    await AppDatabase.wipe();
    await _repo.ensureSeeded();
    await reload();
  }
}

final StateNotifierProvider<AppNotifier, AppState> appProvider =
    StateNotifierProvider<AppNotifier, AppState>(
  (Ref ref) => AppNotifier(
    ref.watch(repositoryProvider),
    ref.watch(syncServiceProvider),
  ),
);

/// Raccourci pratique : les données seules.
final Provider<BudgetData> dataProvider = Provider<BudgetData>(
  (Ref ref) => ref.watch(appProvider).data,
);
