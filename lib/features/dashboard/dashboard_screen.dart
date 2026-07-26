import 'package:fl_chart/fl_chart.dart';
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BudgetData data = ref.watch(dataProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    final double income = data.incomeOfMonth();
    final double expenses = data.expensesOfMonth();
    final double remaining = income - expenses;

    return ListView(
      children: <Widget>[
        SectionHeader(
          title: 'Tableau de bord',
          subtitle:
              'Vue d\'ensemble de ${Fmt.capitalize(Fmt.monthYear(DateTime.now()))}.',
          action: wide
              ? Text(
                  'Dernière synchro : '
                  '${data.settings.lastSyncAt == null ? 'jamais' : Fmt.date(data.settings.lastSyncAt!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                )
              : null,
        ),
        GridView.count(
          crossAxisCount: wide ? 5 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: wide ? 1.7 : 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: <Widget>[
            StatCard(
              label: 'Solde actuel',
              value: data.totalBalance,
              icon: Icons.account_balance_wallet_outlined,
            ),
            StatCard(
              label: 'Revenus du mois',
              value: income,
              color: context.successColor,
              icon: Icons.south_west,
            ),
            StatCard(
              label: 'Dépenses du mois',
              value: expenses,
              color: context.dangerColor,
              icon: Icons.north_east,
            ),
            StatCard(
              label: 'Argent restant',
              value: remaining,
              color:
                  remaining >= 0 ? context.successColor : context.dangerColor,
              icon: Icons.savings_outlined,
            ),
            StatCard(
              label: 'Prévu pour investir',
              value: data.plannedInvestment,
              color: Theme.of(context).colorScheme.primary,
              icon: Icons.trending_up,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _CategoryChart(data: data)),
              const SizedBox(width: 16),
              Expanded(
                child: _IncomeExpenseChart(income: income, expenses: expenses),
              ),
            ],
          )
        else ...<Widget>[
          _CategoryChart(data: data),
          const SizedBox(height: 16),
          _IncomeExpenseChart(income: income, expenses: expenses),
        ],
        const SizedBox(height: 16),
        _TrendChart(data: data),
        const SizedBox(height: 16),
        _UpcomingBills(data: data),
        const SizedBox(height: 16),
        _RecentTransactions(data: data),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.data});

  final BudgetData data;

  @override
  Widget build(BuildContext context) {
    final List<({Category category, double amount})> byCategory =
        data.expensesByCategory();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Dépenses par catégorie',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (byCategory.isEmpty)
            SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Aucune dépense ce mois-ci.',
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: <PieChartSectionData>[
                    for (final ({Category category, double amount}) e
                        in byCategory.take(8))
                      PieChartSectionData(
                        value: e.amount,
                        color: Color(e.category.color),
                        title: '',
                        radius: 34,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                for (final ({Category category, double amount}) e
                    in byCategory.take(8))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ColorDot(color: Color(e.category.color)),
                      const SizedBox(width: 6),
                      Text(
                        '${e.category.name} · ${Fmt.money(e.amount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({required this.income, required this.expenses});

  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    final double maxY =
        <double>[income, expenses, 1].reduce((double a, double b) => a > b ? a : b) *
            1.25;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Revenus et dépenses du mois',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 216,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (double value) =>
                      FlLine(color: context.borderColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (double value, TitleMeta meta) => Text(
                        Fmt.moneyCompact(value),
                        style:
                            TextStyle(fontSize: 10, color: context.mutedColor),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          value == 0 ? 'Revenus' : 'Dépenses',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.mutedColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  BarChartGroupData(
                    x: 0,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: income,
                        color: context.successColor,
                        width: 42,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: expenses,
                        color: context.dangerColor,
                        width: 42,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
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

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final BudgetData data;

  @override
  Widget build(BuildContext context) {
    final List<({DateTime month, double income, double expenses})> trend =
        data.monthlyTrend(6);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tendance sur 6 mois',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (double value) =>
                      FlLine(color: context.borderColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (double value, TitleMeta meta) => Text(
                        Fmt.moneyCompact(value),
                        style:
                            TextStyle(fontSize: 10, color: context.mutedColor),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.round();
                        if (index < 0 || index >= trend.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            Fmt.capitalize(
                              Fmt.monthYear(trend[index].month).split(' ').first,
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.mutedColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    isCurved: true,
                    color: context.successColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    spots: <FlSpot>[
                      for (int i = 0; i < trend.length; i++)
                        FlSpot(i.toDouble(), trend[i].income),
                    ],
                  ),
                  LineChartBarData(
                    isCurved: true,
                    color: context.dangerColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    spots: <FlSpot>[
                      for (int i = 0; i < trend.length; i++)
                        FlSpot(i.toDouble(), trend[i].expenses),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              ColorDot(color: context.successColor),
              const SizedBox(width: 6),
              const Text('Revenus', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              ColorDot(color: context.dangerColor),
              const SizedBox(width: 6),
              const Text('Dépenses', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingBills extends StatelessWidget {
  const _UpcomingBills({required this.data});

  final BudgetData data;

  @override
  Widget build(BuildContext context) {
    final List<Bill> overdue = data.overdueBills;
    final List<Bill> upcoming = data.upcomingBills.take(4).toList();
    if (overdue.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Factures à surveiller',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final Bill bill in <Bill>[...overdue, ...upcoming])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    bill.isOverdue(DateHelpers.todayIso())
                        ? Icons.warning_amber_rounded
                        : Icons.schedule,
                    size: 16,
                    color: bill.isOverdue(DateHelpers.todayIso())
                        ? context.dangerColor
                        : context.mutedColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(bill.name)),
                  Text(
                    Fmt.shortDate(DateHelpers.fromIso(bill.dueDate)),
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Fmt.money(bill.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.data});

  final BudgetData data;

  @override
  Widget build(BuildContext context) {
    final List<Txn> recent = data.transactions.take(6).toList();
    if (recent.isEmpty) {
      return const EmptyState(
        message: 'Aucune transaction pour l\'instant.\n'
            'Ajoute une dépense ou importe ton relevé Desjardins.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Dernières transactions',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final Txn t in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: <Widget>[
                  ColorDot(
                    color: Color(
                      data.categoryById(t.categoryId)?.color ?? 0xFF94A3B8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          data.categoryById(t.categoryId)?.name ??
                              'Sans catégorie',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (t.description.isNotEmpty)
                          Text(
                            t.description,
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
                    Fmt.shortDate(DateHelpers.fromIso(t.date)),
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Fmt.signedMoney(t.signedAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: t.isExpense
                          ? context.dangerColor
                          : context.successColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
