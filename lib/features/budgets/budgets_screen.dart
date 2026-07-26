import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Budgets',
          subtitle: 'Fixe une limite mensuelle par catégorie.',
          action: FilledButton.icon(
            onPressed: () => _openBudgetEditor(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouveau budget'),
          ),
        ),
        Expanded(
          child: data.budgets.isEmpty
              ? const EmptyState(
                  message: 'Aucun budget défini.\n'
                      'Crée-en un pour suivre tes dépenses par catégorie.',
                  icon: Icons.savings_outlined,
                )
              : ListView.separated(
                  itemCount: data.budgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final Budget budget = data.budgets[index];
                    final double spent = data.spentForBudget(budget);
                    final double ratio = budget.amountLimit <= 0
                        ? 0
                        : spent / budget.amountLimit;
                    final Category? category =
                        data.categoryById(budget.categoryId);

                    final Color barColor = ratio >= 1
                        ? context.dangerColor
                        : ratio * 100 >= budget.alertThreshold
                            ? context.warningColor
                            : context.successColor;

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              ColorDot(
                                color: Color(category?.color ?? 0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  budget.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${Fmt.money(spent)} / ${Fmt.money(budget.amountLimit)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.mutedColor,
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  final AppNotifier notifier =
                                      ref.read(appProvider.notifier);
                                  final bool ok = await confirmDialog(
                                    context,
                                    title: 'Supprimer le budget',
                                    message: '${budget.name} sera supprimé.',
                                  );
                                  if (ok) {
                                    await notifier.deleteBudget(budget.id);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ProgressBar(value: ratio, color: barColor),
                          const SizedBox(height: 8),
                          Text(
                            ratio >= 1
                                ? 'Budget dépassé de ${Fmt.money(spent - budget.amountLimit)}'
                                : 'Il reste ${Fmt.money(budget.amountLimit - spent)} · '
                                    'alerte à ${budget.alertThreshold} %',
                            style: TextStyle(
                              fontSize: 12,
                              color: ratio >= 1
                                  ? context.dangerColor
                                  : context.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> _openBudgetEditor(BuildContext context, WidgetRef ref) async {
  final BudgetData data = ref.read(dataProvider);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController amount = TextEditingController();
  final TextEditingController threshold = TextEditingController(text: '80');
  String? categoryId = data.categoriesOfType(TxnType.expense).isNotEmpty
      ? data.categoriesOfType(TxnType.expense).first.id
      : null;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Nouveau budget'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Ex. : Restaurants',
                ),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoryId,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: <DropdownMenuItem<String>>[
                  for (final Category c
                      in data.categoriesOfType(TxnType.expense))
                    DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (String? v) => categoryId = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limite mensuelle',
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
              TextFormField(
                controller: threshold,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Seuil d\'alerte (%)',
                ),
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
            await ref.read(appProvider.notifier).saveBudget(
                  name: name.text.trim(),
                  categoryId: categoryId ?? '',
                  amountLimit:
                      double.parse(amount.text.replaceAll(',', '.')),
                  alertThreshold: int.tryParse(threshold.text) ?? 80,
                );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Créer'),
        ),
      ],
    ),
  );
}
