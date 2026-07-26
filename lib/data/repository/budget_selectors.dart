import '../../core/utils/date_helpers.dart';
import '../models/agenda_models.dart';
import '../models/finance_models.dart';
import 'budget_repository.dart';

/// Calculs dérivés des données brutes.
///
/// Règle de solde retenue : `Account.balance` est le **solde d'ouverture**
/// saisi par l'utilisateur. Le solde affiché est recalculé à partir des
/// transactions, ce qui évite toute dérive lors des synchronisations
/// (une transaction reçue deux fois ne peut pas fausser le solde).
extension BudgetSelectors on BudgetData {
  Category? categoryById(String id) {
    for (final Category c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? accountById(String id) {
    for (final Account a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  AgendaCategory? agendaCategoryById(String id) {
    for (final AgendaCategory c in agendaCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? get mainAccount {
    for (final Account a in accounts) {
      if (!a.isInvestment) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Account? get investmentAccount {
    for (final Account a in accounts) {
      if (a.isInvestment) return a;
    }
    return null;
  }

  List<Category> categoriesOfType(TxnType type) =>
      categories.where((Category c) => c.type == type).toList();

  double get totalInvested =>
      transfers.fold<double>(0, (double s, InvestmentTransfer t) => s + t.invested);

  /// Solde courant d'un compte : ouverture + mouvements + transferts.
  double balanceOf(Account account) {
    double total = account.balance;
    for (final Txn t in transactions) {
      if (t.accountId == account.id) total += t.signedAmount;
    }
    if (account.isInvestment) {
      total += totalInvested;
    } else if (mainAccount?.id == account.id) {
      total -= totalInvested;
    }
    return total;
  }

  double get totalBalance =>
      accounts.fold<double>(0, (double s, Account a) => s + balanceOf(a));

  List<Txn> transactionsOfMonth([DateTime? reference]) {
    final ({String end, String start}) range =
        DateHelpers.monthRange(reference);
    return transactions
        .where((Txn t) =>
            t.date.compareTo(range.start) >= 0 &&
            t.date.compareTo(range.end) < 0)
        .toList();
  }

  double incomeOfMonth([DateTime? reference]) => transactionsOfMonth(reference)
      .where((Txn t) => t.type == TxnType.income)
      .fold<double>(0, (double s, Txn t) => s + t.amount);

  double expensesOfMonth([DateTime? reference]) =>
      transactionsOfMonth(reference)
          .where((Txn t) => t.type == TxnType.expense)
          .fold<double>(0, (double s, Txn t) => s + t.amount);

  double remainingOfMonth([DateTime? reference]) =>
      incomeOfMonth(reference) - expensesOfMonth(reference);

  /// Montant qui sera transféré vers les investissements à la fin du mois.
  double get plannedInvestment {
    if (!settings.investmentEnabled) return 0;
    final double remaining = remainingOfMonth();
    return remaining > 0 ? remaining * settings.investmentPercent / 100 : 0;
  }

  /// Dépenses du mois par catégorie, triées du plus grand au plus petit.
  List<({Category category, double amount})> expensesByCategory([
    DateTime? reference,
  ]) {
    final Map<String, double> totals = <String, double>{};
    for (final Txn t in transactionsOfMonth(reference)) {
      if (t.type != TxnType.expense) continue;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }
    final List<({Category category, double amount})> out =
        <({Category category, double amount})>[];
    totals.forEach((String id, double amount) {
      final Category? c = categoryById(id);
      if (c != null) out.add((category: c, amount: amount));
    });
    out.sort((({Category category, double amount}) a,
            ({Category category, double amount}) b) =>
        b.amount.compareTo(a.amount));
    return out;
  }

  /// Revenus et dépenses des N derniers mois (pour le graphique de tendance).
  List<({DateTime month, double income, double expenses})> monthlyTrend(
    int months,
  ) =>
      DateHelpers.lastMonths(months)
          .map((DateTime m) => (
                month: m,
                income: incomeOfMonth(m),
                expenses: expensesOfMonth(m),
              ))
          .toList();

  /// Consommation d'un budget sur le mois courant.
  double spentForBudget(Budget budget) => transactionsOfMonth()
      .where((Txn t) =>
          t.type == TxnType.expense && t.categoryId == budget.categoryId)
      .fold<double>(0, (double s, Txn t) => s + t.amount);

  List<Bill> get overdueBills {
    final String today = DateHelpers.todayIso();
    return bills.where((Bill b) => b.isOverdue(today)).toList();
  }

  List<Bill> get upcomingBills {
    final String today = DateHelpers.todayIso();
    return bills
        .where((Bill b) => !b.paid && b.dueDate.compareTo(today) >= 0)
        .toList();
  }

  List<Bill> get paidBills => bills.where((Bill b) => b.paid).toList();

  /// Occurrences d'un événement récurrent dans une plage de dates.
  List<DateTime> occurrencesOf(
    AgendaEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final DateTime first = DateHelpers.fromIso(event.date);
    final List<DateTime> out = <DateTime>[];

    if (event.recurrence == Recurrence.none) {
      if (!first.isBefore(rangeStart) && !first.isAfter(rangeEnd)) {
        out.add(first);
      }
      return out;
    }

    DateTime cursor = first;
    int guard = 0;
    while (!cursor.isAfter(rangeEnd) && guard < 800) {
      guard++;
      if (!cursor.isBefore(rangeStart)) out.add(cursor);
      if (event.recurrence == Recurrence.daily) {
        cursor = cursor.add(const Duration(days: 1));
      } else if (event.recurrence == Recurrence.weekly) {
        cursor = cursor.add(const Duration(days: 7));
      } else if (event.recurrence == Recurrence.biweekly) {
        cursor = cursor.add(const Duration(days: 14));
      } else if (event.recurrence == Recurrence.monthly) {
        cursor = DateHelpers.addMonths(cursor, 1);
      } else if (event.recurrence == Recurrence.yearly) {
        cursor = DateTime(cursor.year + 1, cursor.month, cursor.day);
      } else {
        return out;
      }
    }
    return out;
  }

  /// Tout ce qui se passe une journée donnée : événements, tâches, factures.
  ({
    List<AgendaEvent> events,
    List<AgendaTask> tasks,
    List<Bill> bills,
  }) agendaFor(DateTime rawDay) {
    final DateTime day = DateTime(rawDay.year, rawDay.month, rawDay.day);
    final String iso = DateHelpers.toIso(day);
    final List<AgendaEvent> dayEvents = events
        .where((AgendaEvent e) => occurrencesOf(e, day, day).isNotEmpty)
        .toList()
      ..sort((AgendaEvent a, AgendaEvent b) =>
          (a.startMinutes ?? -1).compareTo(b.startMinutes ?? -1));

    return (
      events: dayEvents,
      tasks: tasks.where((AgendaTask t) => t.dueDate == iso).toList(),
      bills: bills.where((Bill b) => b.dueDate == iso).toList(),
    );
  }
}
