import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../providers/app_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Catégories',
          subtitle: 'Catégories par défaut et catégories personnalisées.',
          action: FilledButton.icon(
            onPressed: () => _openCategoryEditor(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nouvelle catégorie'),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: wide ? 4 : 2,
            childAspectRatio: 2.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: <Widget>[
              for (final Category c in data.categories)
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      ColorDot(color: Color(c.color), size: 12),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              c.type == TxnType.income ? 'Revenu' : 'Dépense',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!c.isSystem)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () async {
                            final bool removed = await ref
                                .read(appProvider.notifier)
                                .deleteCategory(c.id);
                            if (!removed && context.mounted) {
                              showSnack(
                                context,
                                'Impossible : des transactions utilisent '
                                'cette catégorie.',
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _openCategoryEditor(BuildContext context, WidgetRef ref) async {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  TxnType type = TxnType.expense;
  int color = AppColors.categoryPalette.first.value;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                SegmentedButton<TxnType>(
                  segments: const <ButtonSegment<TxnType>>[
                    ButtonSegment<TxnType>(
                      value: TxnType.expense,
                      label: Text('Dépense'),
                    ),
                    ButtonSegment<TxnType>(
                      value: TxnType.income,
                      label: Text('Revenu'),
                    ),
                  ],
                  selected: <TxnType>{type},
                  onSelectionChanged: (Set<TxnType> s) =>
                      setState(() => type = s.first),
                ),
                const SizedBox(height: 16),
                const Text('Couleur', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Color c in AppColors.categoryPalette)
                      GestureDetector(
                        onTap: () => setState(() => color = c.value),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 3,
                              color: color == c.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
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
              await ref.read(appProvider.notifier).saveCategory(
                    name: name.text.trim(),
                    type: type,
                    color: color,
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
