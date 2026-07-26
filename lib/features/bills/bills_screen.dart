import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);
    final List<Bill> overdue = data.overdueBills;
    final List<Bill> upcoming = data.upcomingBills;
    final List<Bill> paid = data.paidBills;

    final double dueTotal = <Bill>[...overdue, ...upcoming]
        .fold<double>(0, (double s, Bill b) => s + b.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Factures et rappels',
          subtitle: 'Loyer, téléphone, Hydro, abonnements… '
              '${Fmt.money(dueTotal)} à payer.',
          action: FilledButton.icon(
            onPressed: () => _openBillEditor(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle facture'),
          ),
        ),
        Expanded(
          child: overdue.isEmpty && upcoming.isEmpty && paid.isEmpty
              ? const EmptyState(
                  message: 'Aucune facture enregistrée.',
                  icon: Icons.receipt_long_outlined,
                )
              : ListView(
                  children: <Widget>[
                    _BillGroup(
                      title: 'En retard',
                      icon: Icons.warning_amber_rounded,
                      color: context.dangerColor,
                      bills: overdue,
                    ),
                    _BillGroup(
                      title: 'À venir',
                      icon: Icons.schedule,
                      color: Theme.of(context).colorScheme.primary,
                      bills: upcoming,
                    ),
                    _BillGroup(
                      title: 'Payées',
                      icon: Icons.check_circle_outline,
                      color: context.successColor,
                      bills: paid,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BillGroup extends ConsumerWidget {
  const _BillGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.bills,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Bill> bills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bills.isEmpty) return const SizedBox.shrink();
    final BudgetData data = ref.watch(dataProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                '$title (${bills.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final Bill bill in bills)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            bill.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Échéance : '
                            '${Fmt.shortDate(DateHelpers.fromIso(bill.dueDate))}'
                            ' · ${billFrequencyLabels[bill.frequency]}'
                            '${data.categoryById(bill.categoryId) == null ? '' : ' · ${data.categoryById(bill.categoryId)!.name}'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Fmt.money(bill.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    if (!bill.paid)
                      OutlinedButton(
                        onPressed: () => ref
                            .read(appProvider.notifier)
                            .markBillPaid(bill),
                        child: const Text('Marquer payé'),
                      ),
                    IconButton(
                      tooltip: 'Supprimer',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        final AppNotifier notifier =
                            ref.read(appProvider.notifier);
                        final bool ok = await confirmDialog(
                          context,
                          title: 'Supprimer la facture',
                          message: '${bill.name} sera supprimée.',
                        );
                        if (ok) await notifier.deleteBill(bill.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _openBillEditor(BuildContext context, WidgetRef ref) async {
  final BudgetData data = ref.read(dataProvider);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController amount = TextEditingController();
  final TextEditingController reminder = TextEditingController(text: '3');

  DateTime dueDate = DateHelpers.today();
  String? categoryId = data.categoriesOfType(TxnType.expense).isNotEmpty
      ? data.categoriesOfType(TxnType.expense).first.id
      : null;
  String? accountId = data.mainAccount?.id;
  BillFrequency frequency = BillFrequency.monthly;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: const Text('Nouvelle facture'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      hintText: 'Ex. : Loyer, Netflix, Hydro-Québec',
                    ),
                    validator: (String? v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      prefixText: r'$ ',
                    ),
                    validator: (String? v) {
                      final double? parsed =
                          double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (parsed == null || parsed <= 0)
                          ? 'Montant invalide'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => dueDate = picked);
                    },
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Date d\'échéance'),
                      child: Text(Fmt.date(dueDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: <DropdownMenuItem<String>>[
                      for (final Category c
                          in data.categoriesOfType(TxnType.expense))
                        DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (String? v) => categoryId = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Compte de paiement',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final Account a in data.accounts)
                        DropdownMenuItem<String>(
                          value: a.id,
                          child: Text(a.name),
                        ),
                    ],
                    onChanged: (String? v) => accountId = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BillFrequency>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: 'Fréquence'),
                    items: <DropdownMenuItem<BillFrequency>>[
                      for (final BillFrequency f in BillFrequency.values)
                        DropdownMenuItem<BillFrequency>(
                          value: f,
                          child: Text(billFrequencyLabels[f]!),
                        ),
                    ],
                    onChanged: (BillFrequency? v) =>
                        frequency = v ?? BillFrequency.monthly,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reminder,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rappel (jours avant l\'échéance)',
                    ),
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
              await ref.read(appProvider.notifier).saveBill(
                    name: name.text.trim(),
                    amount:
                        double.parse(amount.text.replaceAll(',', '.')),
                    dueDate: DateHelpers.toIso(dueDate),
                    categoryId: categoryId ?? '',
                    accountId: accountId ?? '',
                    frequency: frequency,
                    reminderDays: int.tryParse(reminder.text) ?? 3,
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
