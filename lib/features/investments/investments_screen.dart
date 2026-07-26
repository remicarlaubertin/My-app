import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);
    final int percent = data.settings.investmentPercent;
    final bool enabled = data.settings.investmentEnabled;
    final Account? investAccount = data.investmentAccount;

    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'Investissements',
          subtitle: 'Règle automatique de fin de mois.',
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: StatCard(
                label: 'Total investi',
                value: data.totalInvested,
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Solde du compte',
                value: investAccount == null
                    ? 0
                    : data.balanceOf(investAccount),
                icon: Icons.account_balance_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Prévu ce mois-ci',
                value: data.plannedInvestment,
                color: context.successColor,
                icon: Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'À la fin du mois, $percent % de ton solde restant '
                '(revenus − dépenses) sont transférés vers le compte '
                'Investissements.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                title: const Text('Activer la règle automatique'),
                subtitle: Text(
                  'Le transfert est exécuté au premier lancement du mois '
                  'suivant.',
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
                onChanged: (bool value) =>
                    ref.read(appProvider.notifier).setInvestmentEnabled(value),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Text('Pourcentage à investir'),
                  const Spacer(),
                  Text(
                    '$percent %',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Slider(
                value: percent.toDouble(),
                max: 100,
                divisions: 20,
                label: '$percent %',
                onChanged: (double value) => ref
                    .read(appProvider.notifier)
                    .setInvestmentPercent(value.round()),
              ),
              Text(
                'Exemple : sur ${Fmt.money(800)} restants, '
                '${Fmt.money(800 * percent / 100)} vont aux investissements '
                'et ${Fmt.money(800 - 800 * percent / 100)} restent sur le '
                'compte courant.',
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Exécuter le transfert du mois précédent'),
                onPressed: () async {
                  final String message = await ref
                      .read(appProvider.notifier)
                      .runInvestmentTransfer();
                  if (context.mounted) showSnack(context, message);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (data.transfers.isEmpty)
          const EmptyState(
            message: 'Aucun transfert pour l\'instant.',
            icon: Icons.history,
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Historique des transferts',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final InvestmentTransfer t in data.transfers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                t.month,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Revenus ${Fmt.money(t.income)} · '
                                'Dépenses ${Fmt.money(t.expenses)} · '
                                'Conservé ${Fmt.money(t.kept)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${Fmt.money(t.invested)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
