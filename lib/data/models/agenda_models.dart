import 'sync_entity.dart';

/// Récurrence d'un événement d'agenda.
enum Recurrence { none, daily, weekly, biweekly, monthly, yearly }

Recurrence recurrenceFrom(Object? value) {
  switch (value.toString()) {
    case 'daily':
      return Recurrence.daily;
    case 'weekly':
      return Recurrence.weekly;
    case 'biweekly':
      return Recurrence.biweekly;
    case 'monthly':
      return Recurrence.monthly;
    case 'yearly':
      return Recurrence.yearly;
    default:
      return Recurrence.none;
  }
}

const Map<Recurrence, String> recurrenceLabels = <Recurrence, String>{
  Recurrence.none: 'Aucune',
  Recurrence.daily: 'Chaque jour',
  Recurrence.weekly: 'Chaque semaine',
  Recurrence.biweekly: 'Aux 2 semaines',
  Recurrence.monthly: 'Chaque mois',
  Recurrence.yearly: 'Chaque année',
};

enum Priority { low, medium, high }

Priority priorityFrom(Object? value) {
  switch (value.toString()) {
    case 'high':
      return Priority.high;
    case 'low':
      return Priority.low;
    default:
      return Priority.medium;
  }
}

const Map<Priority, String> priorityLabels = <Priority, String>{
  Priority.low: 'Basse',
  Priority.medium: 'Moyenne',
  Priority.high: 'Haute',
};

// ---------------------------------------------------------------------------
// Catégorie d'agenda
// ---------------------------------------------------------------------------

class AgendaCategory implements SyncEntity {
  const AgendaCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final String icon;
  final int color;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  factory AgendaCategory.fromMap(Map<String, dynamic> m) => AgendaCategory(
        id: asString(m['id']),
        name: asString(m['name']),
        icon: asString(m['icon'], fallback: '📅'),
        color: asInt(m['color'], fallback: 0xFF6366F1),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };
}

// ---------------------------------------------------------------------------
// Événement
// ---------------------------------------------------------------------------

class AgendaEvent implements SyncEntity {
  const AgendaEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.startMinutes,
    this.endMinutes,
    this.location = '',
    required this.agendaCategoryId,
    this.recurrence = Recurrence.none,
    this.reminderMinutes = 60,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String title;
  final String description;

  /// Date de la première occurrence, format ISO `yyyy-MM-dd`.
  final String date;

  /// Minutes depuis minuit ; `null` = journée entière.
  final int? startMinutes;
  final int? endMinutes;
  final String location;
  final String agendaCategoryId;
  final Recurrence recurrence;
  final int reminderMinutes;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  bool get isAllDay => startMinutes == null;

  factory AgendaEvent.fromMap(Map<String, dynamic> m) => AgendaEvent(
        id: asString(m['id']),
        title: asString(m['title']),
        description: asString(m['description']),
        date: asString(m['date']),
        startMinutes:
            m['start_minutes'] == null ? null : asInt(m['start_minutes']),
        endMinutes: m['end_minutes'] == null ? null : asInt(m['end_minutes']),
        location: asString(m['location']),
        agendaCategoryId: asString(m['agenda_category_id']),
        recurrence: recurrenceFrom(m['recurrence']),
        reminderMinutes: asInt(m['reminder_minutes'], fallback: 60),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'location': location,
        'agenda_category_id': agendaCategoryId,
        'recurrence': recurrence.name,
        'reminder_minutes': reminderMinutes,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  AgendaEvent copyWith({
    String? title,
    String? description,
    String? date,
    int? startMinutes,
    int? endMinutes,
    String? location,
    String? agendaCategoryId,
    Recurrence? recurrence,
    int? reminderMinutes,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      AgendaEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        date: date ?? this.date,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        location: location ?? this.location,
        agendaCategoryId: agendaCategoryId ?? this.agendaCategoryId,
        recurrence: recurrence ?? this.recurrence,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Tâche
// ---------------------------------------------------------------------------

class AgendaTask implements SyncEntity {
  const AgendaTask({
    required this.id,
    required this.title,
    this.priority = Priority.medium,
    required this.dueDate,
    this.done = false,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String title;
  final Priority priority;
  final String dueDate;
  final bool done;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  factory AgendaTask.fromMap(Map<String, dynamic> m) => AgendaTask(
        id: asString(m['id']),
        title: asString(m['title']),
        priority: priorityFrom(m['priority']),
        dueDate: asString(m['due_date']),
        done: asBool(m['done']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'title': title,
        'priority': priority.name,
        'due_date': dueDate,
        'done': done,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  AgendaTask copyWith({
    String? title,
    Priority? priority,
    String? dueDate,
    bool? done,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      AgendaTask(
        id: id,
        title: title ?? this.title,
        priority: priority ?? this.priority,
        dueDate: dueDate ?? this.dueDate,
        done: done ?? this.done,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}

// ---------------------------------------------------------------------------
// Objectif d'épargne
// ---------------------------------------------------------------------------

class Goal implements SyncEntity {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.deadline,
    required this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String deadline;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: asString(m['id']),
        name: asString(m['name']),
        targetAmount: asDouble(m['target_amount']),
        currentAmount: asDouble(m['current_amount']),
        deadline: asString(m['deadline']),
        updatedAt: asDate(m['updated_at']),
        deleted: asBool(m['deleted']),
      );

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'deadline': deadline,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  Goal copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? deadline,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Goal(
        id: id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: deadline ?? this.deadline,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
        deleted: deleted ?? this.deleted,
      );
}
