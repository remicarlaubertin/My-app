import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/agenda_models.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';

const Uuid _uuid = Uuid();

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateHelpers.today();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final BudgetData data = ref.watch(dataProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    final Widget calendar = AppCard(
      padding: const EdgeInsets.all(8),
      child: TableCalendar<Object>(
        locale: 'fr_CA',
        firstDay: DateTime(2015),
        lastDay: DateTime(2100),
        focusedDay: _focused,
        calendarFormat: _format,
        availableCalendarFormats: const <CalendarFormat, String>{
          CalendarFormat.month: 'Mois',
          CalendarFormat.twoWeeks: '2 semaines',
          CalendarFormat.week: 'Semaine',
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (DateTime day) =>
            DateHelpers.sameDay(day, _selected),
        onDaySelected: (DateTime selected, DateTime focused) => setState(() {
          _selected = DateTime(selected.year, selected.month, selected.day);
          _focused = focused;
        }),
        onFormatChanged: (CalendarFormat format) =>
            setState(() => _format = format),
        onPageChanged: (DateTime focused) => _focused = focused,
        eventLoader: (DateTime day) {
          final ({
            List<AgendaEvent> events,
            List<AgendaTask> tasks,
            List<Bill> bills,
          }) items = data.agendaFor(day);
          return <Object>[...items.events, ...items.tasks, ...items.bills];
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: context.warningColor,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 4,
          outsideDaysVisible: false,
        ),
        headerStyle: const HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
        ),
      ),
    );

    final Widget details = _DayDetails(
      day: _selected,
      onAddEvent: () => _openEventEditor(context, ref, _selected),
      onAddTask: () => _openTaskEditor(context, ref, _selected),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Agenda',
          subtitle: 'Rendez-vous, tâches et factures au même endroit.',
          action: wide
              ? Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _openTaskEditor(context, ref, _selected),
                      icon: const Icon(Icons.check_box_outlined, size: 16),
                      label: const Text('Tâche'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          _openEventEditor(context, ref, _selected),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Événement'),
                    ),
                  ],
                )
              : null,
        ),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(child: calendar),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: details),
                    ),
                  ],
                )
              : ListView(
                  children: <Widget>[
                    calendar,
                    const SizedBox(height: 16),
                    details,
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DayDetails extends ConsumerWidget {
  const _DayDetails({
    required this.day,
    required this.onAddEvent,
    required this.onAddTask,
  });

  final DateTime day;
  final VoidCallback onAddEvent;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);
    final ({
      List<AgendaEvent> events,
      List<AgendaTask> tasks,
      List<Bill> bills,
    }) items = data.agendaFor(day);

    final bool empty = items.events.isEmpty &&
        items.tasks.isEmpty &&
        items.bills.isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Fmt.capitalize(Fmt.date(day)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Ajouter une tâche',
                icon: const Icon(Icons.check_box_outlined, size: 18),
                onPressed: onAddTask,
              ),
              IconButton(
                tooltip: 'Ajouter un événement',
                icon: const Icon(Icons.add, size: 18),
                onPressed: onAddEvent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Rien de prévu cette journée.',
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            ),
          for (final AgendaEvent event in items.events)
            _EventTile(event: event, data: data),
          for (final AgendaTask task in items.tasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: task.done,
              title: Text(
                task.title,
                style: TextStyle(
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                'Tâche · priorité ${priorityLabels[task.priority]!.toLowerCase()}',
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
              onChanged: (_) =>
                  ref.read(appProvider.notifier).toggleTask(task),
            ),
          for (final Bill bill in items.bills)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: bill.paid ? context.successColor : context.warningColor,
              ),
              title: Text(bill.name),
              subtitle: Text(
                bill.paid ? 'Facture payée' : 'Facture à payer',
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
              trailing: Text(
                Fmt.money(bill.amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, required this.data});

  final AgendaEvent event;
  final BudgetData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AgendaCategory? category =
        data.agendaCategoryById(event.agendaCategoryId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Text(
        category?.icon ?? '📅',
        style: const TextStyle(fontSize: 18),
      ),
      title: Text(event.title),
      subtitle: Text(
        <String>[
          if (event.isAllDay)
            'Toute la journée'
          else
            '${Fmt.time(event.startMinutes)}'
                '${event.endMinutes == null ? '' : ' – ${Fmt.time(event.endMinutes)}'}',
          if (event.location.isNotEmpty) event.location,
          if (event.recurrence != Recurrence.none)
            recurrenceLabels[event.recurrence]!,
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: context.mutedColor),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: () async {
          final AppNotifier notifier = ref.read(appProvider.notifier);
          final bool ok = await confirmDialog(
            context,
            title: 'Supprimer l\'événement',
            message: '${event.title} sera supprimé.',
          );
          if (ok) await notifier.deleteEvent(event.id);
        },
      ),
    );
  }
}

Future<void> _openEventEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final BudgetData data = ref.read(dataProvider);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController title = TextEditingController();
  final TextEditingController location = TextEditingController();

  TimeOfDay? start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? end;
  Recurrence recurrence = Recurrence.none;
  String? categoryId =
      data.agendaCategories.isNotEmpty ? data.agendaCategories.first.id : null;
  bool allDay = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text('Nouvel événement — ${Fmt.shortDate(day)}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Titre'),
                    validator: (String? v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: <DropdownMenuItem<String>>[
                      for (final AgendaCategory c in data.agendaCategories)
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text('${c.icon}  ${c.name}'),
                        ),
                    ],
                    onChanged: (String? v) => categoryId = v,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allDay,
                    title: const Text('Toute la journée'),
                    onChanged: (bool v) => setState(() => allDay = v),
                  ),
                  if (!allDay)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    start ?? const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => start = picked);
                              }
                            },
                            child: Text(
                              'Début : ${start?.format(context) ?? '—'}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: end ??
                                    const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (picked != null) setState(() => end = picked);
                            },
                            child:
                                Text('Fin : ${end?.format(context) ?? '—'}'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: location,
                    decoration:
                        const InputDecoration(labelText: 'Lieu (optionnel)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Recurrence>(
                    value: recurrence,
                    decoration: const InputDecoration(labelText: 'Récurrence'),
                    items: <DropdownMenuItem<Recurrence>>[
                      for (final Recurrence r in Recurrence.values)
                        DropdownMenuItem<Recurrence>(
                          value: r,
                          child: Text(recurrenceLabels[r]!),
                        ),
                    ],
                    onChanged: (Recurrence? v) =>
                        recurrence = v ?? Recurrence.none,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(appProvider.notifier).saveEvent(
                    AgendaEvent(
                      id: _uuid.v4(),
                      title: title.text.trim(),
                      date: DateHelpers.toIso(day),
                      startMinutes: allDay
                          ? null
                          : (start!.hour * 60 + start!.minute),
                      endMinutes: allDay || end == null
                          ? null
                          : (end!.hour * 60 + end!.minute),
                      location: location.text.trim(),
                      agendaCategoryId: categoryId ?? '',
                      recurrence: recurrence,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openTaskEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController title = TextEditingController();
  Priority priority = Priority.medium;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text('Nouvelle tâche — ${Fmt.shortDate(day)}'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Priority>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priorité'),
                  items: <DropdownMenuItem<Priority>>[
                    for (final Priority p in Priority.values)
                      DropdownMenuItem<Priority>(
                        value: p,
                        child: Text(priorityLabels[p]!),
                      ),
                  ],
                  onChanged: (Priority? v) =>
                      priority = v ?? Priority.medium,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(appProvider.notifier).saveTask(
                    AgendaTask(
                      id: _uuid.v4(),
                      title: title.text.trim(),
                      priority: priority,
                      dueDate: DateHelpers.toIso(day),
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    ),
  );
}
