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

/// Ouvre le formulaire d'ajout / modification d'une transaction.
///
/// Feuille glissante sur téléphone, boîte de dialogue sur ordinateur.
Future<void> openTransactionEditor(
  BuildContext context,
  WidgetRef ref, {
  Txn? existing,
}) async {
  final bool wide = MediaQuery.sizeOf(context).width >= 900;
  final Widget form = TransactionEditor(existing: existing);

  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: form,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(child: form),
      ),
    );
  }
}

class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({super.key, this.existing});

  final Txn? existing;

  @override
  ConsumerState<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<TransactionEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;

  late TxnType _type;
  String? _categoryId;
  String? _accountId;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final Txn? tx = widget.existing;
    _type = tx?.type ?? TxnType.expense;
    _amount = TextEditingController(
      text: tx == null ? '' : tx.amount.toStringAsFixed(2),
    );
    _description = TextEditingController(text: tx?.description ?? '');
    _categoryId = tx?.categoryId;
    _accountId = tx?.accountId;
    _date = tx == null ? DateHelpers.today() : DateHelpers.fromIso(tx.date);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final BudgetData data = ref.read(dataProvider);

    final String categoryId = _categoryId ??
        (data.categoriesOfType(_type).isNotEmpty
            ? data.categoriesOfType(_type).first.id
            : '');
    final String accountId =
        _accountId ?? data.mainAccount?.id ?? '';

    await ref.read(appProvider.notifier).saveTransaction(
          id: widget.existing?.id,
          type: _type,
          amount: double.parse(_amount.text.replaceAll(',', '.')),
          categoryId: categoryId,
          accountId: accountId,
          date: DateHelpers.toIso(_date),
          description: _description.text.trim(),
          source: widget.existing?.source ?? 'manual',
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final BudgetData data = ref.watch(dataProvider);
    final List<Category> categories = data.categoriesOfType(_type);

    if (_categoryId != null &&
        !categories.any((Category c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.existing == null
                ? 'Nouvelle transaction'
                : 'Modifier la transaction',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TxnType>(
            segments: const <ButtonSegment<TxnType>>[
              ButtonSegment<TxnType>(
                value: TxnType.expense,
                label: Text('Dépense'),
                icon: Icon(Icons.north_east, size: 16),
              ),
              ButtonSegment<TxnType>(
                value: TxnType.income,
                label: Text('Revenu'),
                icon: Icon(Icons.south_west, size: 16),
              ),
            ],
            selected: <TxnType>{_type},
            onSelectionChanged: (Set<TxnType> selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Montant',
              prefixText: r'$ ',
            ),
            validator: (String? value) {
              final double? parsed =
                  double.tryParse((value ?? '').replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                return 'Entre un montant valide.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryId ??
                (categories.isNotEmpty ? categories.first.id : null),
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: <DropdownMenuItem<String>>[
              for (final Category c in categories)
                DropdownMenuItem<String>(
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
            onChanged: (String? value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _accountId ?? data.mainAccount?.id,
            decoration: const InputDecoration(labelText: 'Compte'),
            items: <DropdownMenuItem<String>>[
              for (final Account a in data.accounts)
                DropdownMenuItem<String>(value: a.id, child: Text(a.name)),
            ],
            onChanged: (String? value) => setState(() => _accountId = value),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(Fmt.date(_date))),
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: context.mutedColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            child: Text(
              widget.existing == null ? 'Ajouter' : 'Enregistrer',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
