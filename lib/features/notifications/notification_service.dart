import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
// `Priority` existe aussi dans flutter_local_notifications : on masque
// celui du modèle d'agenda, inutile ici.
import '../../data/models/agenda_models.dart' hide Priority;
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';

/// Notifications locales.
///
/// - **Android** : `flutter_local_notifications`, avec rappels programmés
///   (facture bientôt due, facture en retard, événement d'agenda).
/// - **Windows** : `local_notifier`, notifications système immédiates
///   déclenchées au démarrage et à chaque rafraîchissement des données.
///
/// Les alertes « budget dépassé » et « solde faible » sont calculées à partir
/// des données locales, donc identiques sur les deux plateformes.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static bool _tzReady = false;

  /// Empreinte des dernières alertes immédiates affichées.
  static String? _lastAlertSignature;

  /// Fuseau utilisé pour programmer les rappels.
  static const String timeZoneName = 'America/Toronto';

  static bool get _supportsScheduling => !kIsWeb && Platform.isAndroid;
  static bool get _supportsWindows => !kIsWeb && Platform.isWindows;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'budget_reminders',
    'Rappels budget',
    channelDescription:
        'Factures à payer, budgets dépassés et rappels d\'agenda',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  static Future<void> init() async {
    if (_ready) return;

    if (_supportsWindows) {
      await localNotifier.setup(appName: 'Budget');
      _ready = true;
      return;
    }
    if (!_supportsScheduling) {
      _ready = true;
      return;
    }

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _tzReady = true;
    } catch (_) {
      _tzReady = false;
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _ready = true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Notification immédiate, sur les deux plateformes.
  static Future<void> showNow(String title, String body, {int id = 0}) async {
    if (_supportsWindows) {
      final LocalNotification notification =
          LocalNotification(title: title, body: body);
      await notification.show();
      return;
    }
    if (!_supportsScheduling) return;
    await _plugin.show(id, title, body, _details);
  }

  /// Recalcule et reprogramme tous les rappels à partir des données.
  static Future<void> refresh(BudgetData data) async {
    if (!data.settings.notificationsEnabled) {
      _lastAlertSignature = null;
      if (_supportsScheduling) await _plugin.cancelAll();
      return;
    }

    final List<({String title, String body})> immediate =
        _immediateAlerts(data);

    // `refresh()` est appelé après chaque écriture : sans cette empreinte,
    // la même alerte serait réaffichée à chaque modification.
    final String signature = immediate
        .map((({String title, String body}) a) => '${a.title}|${a.body}')
        .join('§');
    final bool alreadyShown = signature == _lastAlertSignature;
    _lastAlertSignature = signature;

    if (_supportsWindows) {
      if (alreadyShown) return;
      for (final ({String title, String body}) alert in immediate) {
        await showNow(alert.title, alert.body);
      }
      return;
    }
    if (!_supportsScheduling) return;

    // On n'annule que la plage des rappels programmés (200-400) : annuler
    // tout effacerait des alertes encore valables affichées précédemment.
    for (int i = 200; i <= 400; i++) {
      await _plugin.cancel(i);
    }

    int id = 100;
    if (!alreadyShown) {
      for (final ({String title, String body}) alert in immediate) {
        await _plugin.show(id++, alert.title, alert.body, _details);
      }
    }
    id = 200;

    if (!_tzReady) return;

    // Rappels de factures : N jours avant l'échéance, à 9 h.
    for (final Bill bill in data.upcomingBills) {
      final DateTime due = DateHelpers.fromIso(bill.dueDate);
      final DateTime remindOn = due.subtract(Duration(days: bill.reminderDays));
      await _scheduleAt(
        id: id++,
        when: DateTime(remindOn.year, remindOn.month, remindOn.day, 9),
        title: 'Facture à venir : ${bill.name}',
        body:
            '${Fmt.money(bill.amount)} à payer le ${Fmt.shortDate(due)}.',
      );
    }

    // Rappels d'agenda pour les 60 prochains jours.
    final DateTime from = DateHelpers.today();
    final DateTime to = from.add(const Duration(days: 60));
    for (final AgendaEventReminder reminder
        in _agendaReminders(data, from, to)) {
      await _scheduleAt(
        id: id++,
        when: reminder.when,
        title: reminder.title,
        body: reminder.body,
      );
      if (id > 400) break;
    }
  }

  static Future<void> _scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (when.isBefore(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Certains appareils refusent les alarmes exactes : on ignore
      // silencieusement plutôt que de bloquer l'application.
    }
  }

  /// Alertes valables « maintenant » : retards, dépassements, solde faible.
  static List<({String title, String body})> _immediateAlerts(
    BudgetData data,
  ) {
    final List<({String title, String body})> alerts =
        <({String title, String body})>[];

    for (final Bill bill in data.overdueBills) {
      alerts.add((
        title: 'Facture en retard : ${bill.name}',
        body: '${Fmt.money(bill.amount)} était dû le '
            '${Fmt.shortDate(DateHelpers.fromIso(bill.dueDate))}.',
      ));
    }

    for (final Budget budget in data.budgets) {
      final double spent = data.spentForBudget(budget);
      if (budget.amountLimit <= 0) continue;
      final double ratio = spent / budget.amountLimit * 100;
      if (ratio >= 100) {
        alerts.add((
          title: 'Budget dépassé : ${budget.name}',
          body: '${Fmt.money(spent)} dépensés sur '
              '${Fmt.money(budget.amountLimit)} prévus.',
        ));
      } else if (ratio >= budget.alertThreshold) {
        alerts.add((
          title: 'Budget bientôt atteint : ${budget.name}',
          body: '${ratio.round()} % du budget utilisé ce mois-ci.',
        ));
      }
    }

    final double balance = data.totalBalance;
    if (balance < data.settings.lowBalanceThreshold) {
      alerts.add((
        title: 'Solde faible',
        body: 'Il te reste ${Fmt.money(balance)} au total.',
      ));
    }

    if (data.settings.investmentEnabled) {
      final DateTime now = DateTime.now();
      final int lastDay = DateTime(now.year, now.month + 1, 0).day;
      if (now.day >= lastDay - 2) {
        final double planned = data.plannedInvestment;
        if (planned > 0) {
          alerts.add((
            title: 'Transfert investissement prévu',
            body: '${Fmt.money(planned)} seront transférés à la fin du mois.',
          ));
        }
      }
    }

    return alerts;
  }

  static List<AgendaEventReminder> _agendaReminders(
    BudgetData data,
    DateTime from,
    DateTime to,
  ) {
    final List<AgendaEventReminder> out = <AgendaEventReminder>[];
    for (final AgendaEvent event in data.events) {
      for (final DateTime day in data.occurrencesOf(event, from, to)) {
        final int startMinutes = event.startMinutes ?? 9 * 60;
        final DateTime start = DateTime(
          day.year,
          day.month,
          day.day,
          startMinutes ~/ 60,
          startMinutes % 60,
        );
        out.add(
          AgendaEventReminder(
            when: start.subtract(Duration(minutes: event.reminderMinutes)),
            title: event.title,
            body: event.isAllDay
                ? 'Aujourd\'hui — ${Fmt.shortDate(day)}'
                : '${Fmt.time(event.startMinutes)} — ${Fmt.shortDate(day)}',
          ),
        );
      }
    }
    return out;
  }
}

class AgendaEventReminder {
  const AgendaEventReminder({
    required this.when,
    required this.title,
    required this.body,
  });

  final DateTime when;
  final String title;
  final String body;
}
