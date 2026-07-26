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
import '../export/export_service.dart';
import '../import_csv/import_flow.dart';
import 'transaction_editor.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _search = TextEditingController();
  TxnType? _typeFilter;
  String? _categoryFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Txn> _filtered(BudgetData data) {
    final String query = _search.text.trim().toLowerCase();
    return data.transactions.where((Txn t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final String category =
          data.categoryById(t.categoryId)?.name.toLowerCase() ?? '';
      return t.description.toLowerCase().contains(query) ||
          category.contains(query) ||
          t.date.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetData data = ref.watch(dataProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 900;
    final List<Txn> transactions = _filtered(data);

    final double totalIncome = transactions
        .where((Txn t) => t.type == TxnType.income)
        .fold<double>(0, (double s, Txn t) => s + t.amount);
    final double totalExpense = transactions
        .where((Txn t) => t.type == TxnType.expense)
        .fold<double>(0, (double s, Txn t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Transactions',
          subtitle: '${transactions.length} mouvement(s) · '
              'Revenus ${Fmt.money(totalIncome)} · '
              'Dépenses ${Fmt.money(totalExpense)}',
          action: wide
              ? Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => openImportFlow(context, ref),
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Importer CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          exportMenu(context, ref, transactions),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Exporter'),
                    ),
                    FilledButton.icon(
                      onPressed: () => openTransactionEditor(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                    ),
                  ],
                )
              : null,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Rechercher…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Filtrer',
              icon: const Icon(Icons.filter_list),
              onSelected: (String value) {
                setState(() {
                  if (value == 'all') {
                    _typeFilter = null;
                    _categoryFilter = null;
                  } else if (value == 'expense') {
                    _typeFilter = TxnType.expense;
                  } else if (value == 'income') {
                    _typeFilter = TxnType.income;
                  } else {
                    _categoryFilter = value;
                  }
                });
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'all',
                  child: Text('Tout afficher'),
                ),
                const PopupMenuItem<String>(
                  value: 'expense',
                  child: Text('Dépenses seulement'),
                ),
                const PopupMenuItem<String>(
                  value: 'income',
                  child: Text('Revenus seulement'),
                ),
                const PopupMenuDivider(),
                for (final Category c in data.categories)
                  PopupMenuItem<String>(
                    value: c.id,
                    child: Row(
                      children: <Widget>[
                        ColorDot(color: Color(c.color)),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: transactions.isEmpty
              ? EmptyState(
                  message: 'Aucune transaction à afficher.',
                  icon: Icons.swap_horiz,
                  action: FilledButton(
                    onPressed: () => openTransactionEditor(context, ref),
                    child: const Text('Ajouter une transaction'),
                  ),
                )
              : ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final Txn t = transactions[index];
                    final Category? category = data.categoryById(t.categoryId);
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      onTap: () => openTransactionEditor(
                        context,
                        ref,
                        existing: t,
                      ),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Color(category?.color ?? 0xFF94A3B8)
                                    .withOpacity(0.18),
                            child: Icon(
                              t.isExpense ? Icons.north_east : Icons.south_west,
                              size: 15,
                              color: Color(category?.color ?? 0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  category?.name ?? 'Sans catégorie',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  <String>[
                                    Fmt.shortDate(DateHelpers.fromIso(t.date)),
                                    if (t.description.isNotEmpty) t.description,
                                    if (t.source == 'csv') 'Import Desjardins',
                                    if (t.source == 'bill') 'Facture',
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Fmt.signedMoney(t.signedAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.isExpense
                                  ? context.dangerColor
                                  : context.successColor,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () async {
                              final AppNotifier notifier =
                                  ref.read(appProvider.notifier);
                              final bool ok = await confirmDialog(
                                context,
                                title: 'Supprimer la transaction',
                                message:
                                    'Cette transaction sera retirée de tous '
                                    'tes appareils.',
                              );
                              if (ok) {
                                await notifier.deleteTransaction(t.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (!wide)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openImportFlow(context, ref),
                    icon: const Icon(Icons.upload_file_outlined, size: 16),
                    label: const Text('Importer'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => exportMenu(context, ref, transactions),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exporter'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
