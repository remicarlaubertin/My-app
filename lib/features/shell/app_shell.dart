import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../providers/app_providers.dart';
import '../agenda/agenda_screen.dart';
import '../bills/bills_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../import_csv/import_flow.dart';
import '../investments/investments_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/transaction_editor.dart';
import '../transactions/transactions_screen.dart';

class AppSection {
  const AppSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.onMobile = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool onMobile;
}

final List<AppSection> appSections = <AppSection>[
  AppSection(
    id: 'dashboard',
    label: 'Accueil',
    icon: Icons.dashboard_outlined,
    builder: (_) => const DashboardScreen(),
  ),
  AppSection(
    id: 'transactions',
    label: 'Transactions',
    icon: Icons.swap_horiz,
    builder: (_) => const TransactionsScreen(),
  ),
  AppSection(
    id: 'bills',
    label: 'Factures',
    icon: Icons.receipt_long_outlined,
    builder: (_) => const BillsScreen(),
  ),
  AppSection(
    id: 'budgets',
    label: 'Budgets',
    icon: Icons.savings_outlined,
    builder: (_) => const BudgetsScreen(),
    onMobile: false,
  ),
  AppSection(
    id: 'investments',
    label: 'Investissements',
    icon: Icons.trending_up,
    builder: (_) => const InvestmentsScreen(),
  ),
  AppSection(
    id: 'agenda',
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    builder: (_) => const AgendaScreen(),
  ),
  AppSection(
    id: 'categories',
    label: 'Catégories',
    icon: Icons.label_outline,
    builder: (_) => const CategoriesScreen(),
    onMobile: false,
  ),
  AppSection(
    id: 'profile',
    label: 'Profil',
    icon: Icons.person_outline,
    builder: (_) => const ProfileScreen(),
  ),
];

/// Coquille de l'application : menu latéral sur ordinateur, barre inférieure
/// sur téléphone, raccourcis clavier et glisser-déposer sur Windows.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String _sectionId = 'dashboard';

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  AppSection get _section =>
      appSections.firstWhere((AppSection s) => s.id == _sectionId);

  void _go(String id) => setState(() => _sectionId = id);

  @override
  Widget build(BuildContext context) {
    // Messages remontés par le notifier (synchronisation, transferts…).
    ref.listen<AppState>(appProvider, (AppState? previous, AppState next) {
      final String? message = next.message;
      if (message != null && message != previous?.message) {
        showSnack(context, message);
        ref.read(appProvider.notifier).clearMessage();
      }
    });

    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 900;

    final Widget content = _section.builder(context);

    final Widget scaffold = wide
        ? _buildWide(content)
        : _buildCompact(content);

    return _ShortcutsWrapper(
      onNavigate: _go,
      child: _isDesktop ? _wrapDropTarget(scaffold) : scaffold,
    );
  }

  Widget _wrapDropTarget(Widget child) {
    return DropTarget(
      onDragDone: (DropDoneDetails details) async {
        if (details.files.isEmpty) return;
        final String path = details.files.first.path;
        if (!path.toLowerCase().endsWith('.csv')) {
          showSnack(context, 'Seuls les fichiers CSV peuvent être importés.');
          return;
        }
        await openImportFlow(context, ref, path: path);
      },
      child: child,
    );
  }

  Widget _buildWide(Widget content) {
    final bool syncing = ref.watch(appProvider).syncing;

    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            width: 232,
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border(right: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: <Widget>[
                      const Text('💰', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Changer de thème',
                        icon: Icon(
                          context.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          size: 18,
                        ),
                        onPressed: () {
                          final AppNotifier n = ref.read(appProvider.notifier);
                          n.updateSettings(
                            n.data.settings.copyWith(
                              darkMode: !n.data.settings.darkMode,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: <Widget>[
                      for (final AppSection s in appSections)
                        _NavTile(
                          section: s,
                          selected: s.id == _sectionId,
                          onTap: () => _go(s.id),
                        ),
                      const SizedBox(height: 12),
                      Divider(color: context.borderColor),
                      const SizedBox(height: 8),
                      _SideAction(
                        icon: Icons.add,
                        label: 'Nouvelle transaction',
                        shortcut: 'Ctrl + N',
                        onTap: () => openTransactionEditor(context, ref),
                      ),
                      _SideAction(
                        icon: Icons.upload_file_outlined,
                        label: 'Importer un CSV',
                        shortcut: 'Ctrl + I',
                        onTap: () => openImportFlow(context, ref),
                      ),
                      _SideAction(
                        icon: syncing ? Icons.sync : Icons.cloud_sync_outlined,
                        label: syncing
                            ? 'Synchronisation…'
                            : 'Synchroniser',
                        shortcut: 'Ctrl + S',
                        onTap: () =>
                            ref.read(appProvider.notifier).synchronize(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Glisse un fichier CSV Desjardins\nn\'importe où pour l\'importer.',
                    style: TextStyle(fontSize: 11, color: context.mutedColor),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(Widget content) {
    final List<AppSection> mobile =
        appSections.where((AppSection s) => s.onMobile).toList();
    int index = mobile.indexWhere((AppSection s) => s.id == _sectionId);
    if (index < 0) index = 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: content,
        ),
      ),
      floatingActionButton: _sectionId == 'dashboard' ||
              _sectionId == 'transactions'
          ? FloatingActionButton(
              onPressed: () => openTransactionEditor(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int i) => _go(mobile[i].id),
        destinations: <Widget>[
          for (final AppSection s in mobile)
            NavigationDestination(
              icon: Icon(s.icon),
              label: s.label,
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                section.icon,
                size: 18,
                color: selected ? Colors.white : context.mutedColor,
              ),
              const SizedBox(width: 10),
              Text(
                section.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : context.mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: context.mutedColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: context.mutedColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                shortcut,
                style: TextStyle(fontSize: 10, color: context.mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourcis clavier (utiles surtout sur Windows).
class _ShortcutsWrapper extends ConsumerWidget {
  const _ShortcutsWrapper({required this.child, required this.onNavigate});

  final Widget child;
  final void Function(String id) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            openTransactionEditor(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            openImportFlow(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            ref.read(appProvider.notifier).synchronize(),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            onNavigate('dashboard'),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            onNavigate('transactions'),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            onNavigate('bills'),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            onNavigate('budgets'),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
            onNavigate('investments'),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
            onNavigate('agenda'),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
