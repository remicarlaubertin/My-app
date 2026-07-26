import 'sync_entity.dart';

/// Type de mouvement d'argent.
enum TxnType { expense, income }

TxnType txnTypeFrom(Object? value) =>
    value.toString() == 'income' ? TxnType.income : TxnType.expense;

String txnTypeTo(TxnType type) =>
    type == TxnType.income ? 'income' : 'expense';

/// Fréquence d'une facture récurrente.
enum BillFrequency { once, weekly, monthly, yearly }

BillFrequency billFrequencyFrom(Object? value) {
  switch (value.toString()) {
    case 'weekly':
      return BillFrequency.weekly;
    case 'yearly':
      return BillFrequency.yearly;
    case 'once':
      return BillFrequency.once;
    default:
      return BillFrequency.monthly;
  }
}

String billFrequencyTo(BillFrequency f) => f.name;

const Map<BillFrequency, String> billFrequencyLabels = <BillFrequency, String>{
  BillFrequency.once: 'Une seule fois',
  BillFrequency.weekly: 'Hebdomadaire',
  BillFrequency.monthly: 'Mensuelle',
  BillFrequency.yearly: 'Annuelle',
};

// ---------------------------------------------------------------------------
// Compte
// ---------------------------------------------------------------------------

class Account implements SyncEntity {
  const Account({
    required this.id,
    required this.name,
    this.balance = 0,
    this.isInvestment = false,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final double balance;
  final bool isInvestment;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: asString(m['id']),
        name: asString(m['name']),
        balance: asDouble(m['balance']),
        isInvestment: asBool(m['is_investment']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'balance': balance,
        'is_investment': isInvestment,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Account copyWith({
    String? name,
    double? balance,
    bool? isInvestment,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        isInvestment: isInvestment ?? this.isInvestment,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Catégorie
// ---------------------------------------------------------------------------

class Category implements SyncEntity {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.isSystem = false,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final TxnType type;

  /// Couleur au format ARGB (`Color.value`).
  final int color;
  final bool isSystem;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: asString(m['id']),
        name: asString(m['name']),
        type: txnTypeFrom(m['type']),
        color: asInt(m['color'], fallback: 0xFF6366F1),
        isSystem: asBool(m['is_system']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': txnTypeTo(type),
        'color': color,
        'is_system': isSystem,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Category copyWith({
    String? name,
    TxnType? type,
    int? color,
    bool? isSystem,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        color: color ?? this.color,
        isSystem: isSystem ?? this.isSystem,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Transaction
// ---------------------------------------------------------------------------

class Txn implements SyncEntity {
  const Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.date,
    this.description = '',
    this.source = 'manual',
    this.externalKey,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final TxnType type;
  final double amount;
  final String categoryId;
  final String accountId;

  /// Date au format ISO `yyyy-MM-dd`.
  final String date;
  final String description;

  /// `manual`, `csv` (import Desjardins) ou `bill` (facture payée).
  final String source;

  /// Empreinte utilisée pour éviter les doublons lors des imports CSV.
  final String? externalKey;

  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  bool get isExpense => type == TxnType.expense;

  /// Montant signé : négatif pour une dépense.
  double get signedAmount => isExpense ? -amount : amount;

  factory Txn.fromMap(Map<String, dynamic> m) => Txn(
        id: asString(m['id']),
        type: txnTypeFrom(m['type']),
        amount: asDouble(m['amount']),
        categoryId: asString(m['category_id']),
        accountId: asString(m['account_id']),
        date: asString(m['date']),
        description: asString(m['description']),
        source: asString(m['source'], fallback: 'manual'),
        externalKey: m['external_key'] == null
            ? null
            : asString(m['external_key']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': txnTypeTo(type),
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'date': date,
        'description': description,
        'source': source,
        'external_key': externalKey,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Txn copyWith({
    TxnType? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? date,
    String? description,
    String? source,
    String? externalKey,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Txn(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        date: date ?? this.date,
        description: description ?? this.description,
        source: source ?? this.source,
        externalKey: externalKey ?? this.externalKey,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Budget (enveloppe mensuelle par catégorie)
// ---------------------------------------------------------------------------

class Budget implements SyncEntity {
  const Budget({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.amountLimit,
    this.alertThreshold = 80,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final String categoryId;
  final double amountLimit;

  /// Pourcentage à partir duquel une alerte est déclenchée.
  final int alertThreshold;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: asString(m['id']),
        name: asString(m['name']),
        categoryId: asString(m['category_id']),
        amountLimit: asDouble(m['amount_limit']),
        alertThreshold: asInt(m['alert_threshold'], fallback: 80),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'category_id': categoryId,
        'amount_limit': amountLimit,
        'alert_threshold': alertThreshold,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Budget copyWith({
    String? name,
    String? categoryId,
    double? amountLimit,
    int? alertThreshold,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Budget(
        id: id,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        amountLimit: amountLimit ?? this.amountLimit,
        alertThreshold: alertThreshold ?? this.alertThreshold,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Facture
// ---------------------------------------------------------------------------

class Bill implements SyncEntity {
  const Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.categoryId,
    required this.accountId,
    this.frequency = BillFrequency.monthly,
    this.paid = false,
    this.reminderDays = 3,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final double amount;

  /// Échéance au format ISO `yyyy-MM-dd`.
  final String dueDate;
  final String categoryId;
  final String accountId;
  final BillFrequency frequency;
  final bool paid;

  /// Nombre de jours avant l'échéance pour le rappel.
  final int reminderDays;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  bool isOverdue(String todayIso) => !paid && dueDate.compareTo(todayIso) < 0;

  factory Bill.fromMap(Map<String, dynamic> m) => Bill(
        id: asString(m['id']),
        name: asString(m['name']),
        amount: asDouble(m['amount']),
        dueDate: asString(m['due_date']),
        categoryId: asString(m['category_id']),
        accountId: asString(m['account_id']),
        frequency: billFrequencyFrom(m['frequency']),
        paid: asBool(m['paid']),
        reminderDays: asInt(m['reminder_days'], fallback: 3),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'amount': amount,
        'due_date': dueDate,
        'category_id': categoryId,
        'account_id': accountId,
        'frequency': billFrequencyTo(frequency),
        'paid': paid,
        'reminder_days': reminderDays,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Bill copyWith({
    String? name,
    double? amount,
    String? dueDate,
    String? categoryId,
    String? accountId,
    BillFrequency? frequency,
    bool? paid,
    int? reminderDays,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Bill(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        frequency: frequency ?? this.frequency,
        paid: paid ?? this.paid,
        reminderDays: reminderDays ?? this.reminderDays,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Transfert automatique vers le compte investissement
// ---------------------------------------------------------------------------

class InvestmentTransfer implements SyncEntity {
  const InvestmentTransfer({
    required this.id,
    required this.month,
    required this.income,
    required this.expenses,
    required this.invested,
    required this.kept,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;

  /// Mois traité, au format `yyyy-MM`.
  final String month;
  final double income;
  final double expenses;
  final double invested;
  final double kept;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  double get remaining => income - expenses;

  factory InvestmentTransfer.fromMap(Map<String, dynamic> m) =>
      InvestmentTransfer(
        id: asString(m['id']),
        month: asString(m['month']),
        income: asDouble(m['income']),
        expenses: asDouble(m['expenses']),
        invested: asDouble(m['invested']),
        kept: asDouble(m['kept']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'month': month,
        'income': income,
        'expenses': expenses,
        'invested': invested,
        'kept': kept,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };
}
