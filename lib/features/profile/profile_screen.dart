import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';
import '../auth/login_screen.dart';
import '../auth/pin_service.dart';
import '../export/export_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppState app = ref.watch(appProvider);
    final BudgetData data = app.data;
    final AppSettings settings = data.settings;
    final String? email = ref.watch(authServiceProvider).currentUser?.email;

    return ListView(
      children: <Widget>[
        const SectionHeader(
          title: 'Profil et réglages',
          subtitle: 'Compte, sécurité, comptes bancaires et préférences.',
        ),

        // --- Compte cloud ---------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    child: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          email ?? 'Mode hors ligne',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          email != null
                              ? 'Données synchronisées entre tes appareils'
                              : AppConfig.cloudConfigured
                                  ? 'Connecte-toi pour synchroniser Windows et Android'
                                  : 'Version compilée sans synchronisation',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (email == null)
                    FilledButton(
                      onPressed: () => openLoginSheet(context, ref),
                      child: const Text('Se connecter'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () async {
                        final bool ok = await confirmDialog(
                          context,
                          title: 'Se déconnecter',
                          message:
                              'Tes données locales seront effacées de cet '
                              'appareil. Elles restent dans le cloud et '
                              'reviendront à la prochaine connexion.',
                          confirmLabel: 'Se déconnecter',
                        );
                        if (!ok) return;
                        await ref.read(authServiceProvider).signOut();
                        await ref.read(appProvider.notifier).resetLocalData();
                      },
                      child: const Text('Se déconnecter'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      settings.lastSyncAt == null
                          ? 'Jamais synchronisé'
                          : 'Dernière synchro : '
                              '${Fmt.date(settings.lastSyncAt!.toLocal())}',
                      style:
                          TextStyle(fontSize: 12, color: context.mutedColor),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: app.syncing
                        ? null
                        : () => ref.read(appProvider.notifier).synchronize(),
                    icon: const Icon(Icons.cloud_sync_outlined, size: 16),
                    label: Text(
                      app.syncing ? 'Synchronisation…' : 'Synchroniser',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Sécurité -------------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Sécurité',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.pinEnabled,
                title: const Text('Verrouiller avec un code PIN'),
                subtitle: Text(
                  'Demandé à chaque ouverture de l\'application.',
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
                onChanged: (bool value) async {
                  final AppNotifier notifier = ref.read(appProvider.notifier);
                  const PinService pin = PinService();
                  if (value) {
                    final String? code = await _askPin(context);
                    if (code == null) return;
                    await pin.setPin(code);
                    // La session en cours reste déverrouillée : le code sera
                    // demandé à la prochaine ouverture.
                    ref.read(unlockedProvider.notifier).state = true;
                  } else {
                    await pin.clear();
                  }
                  ref.invalidate(pinConfiguredProvider);
                  await notifier.updateSettings(
                    settings.copyWith(pinEnabled: value),
                  );
                },
              ),
              Text(
                'Aucune information bancaire n\'est enregistrée : '
                'l\'application ne stocke que les montants et les '
                'descriptions que tu saisis ou importes.',
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Comptes --------------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Mes comptes',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openAccountEditor(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              for (final Account account in data.accounts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    account.isInvestment
                        ? Icons.trending_up
                        : Icons.account_balance_wallet_outlined,
                    size: 20,
                  ),
                  title: Text(account.name),
                  subtitle: Text(
                    'Solde d\'ouverture : ${Fmt.money(account.balance)}',
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
                  trailing: Text(
                    Fmt.money(data.balanceOf(account)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () =>
                      _openAccountEditor(context, ref, existing: account),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Préférences ----------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Préférences',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.darkMode,
                title: const Text('Thème sombre'),
                onChanged: (bool value) => ref
                    .read(appProvider.notifier)
                    .updateSettings(settings.copyWith(darkMode: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.notificationsEnabled,
                title: const Text('Notifications'),
                subtitle: Text(
                  'Factures dues, budgets dépassés, solde faible.',
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
                onChanged: (bool value) => ref
                    .read(appProvider.notifier)
                    .updateSettings(
                      settings.copyWith(notificationsEnabled: value),
                    ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Seuil d\'alerte « solde faible »'),
                subtitle: Text(
                  Fmt.money(settings.lowBalanceThreshold),
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () async {
                  final double? value = await _askAmount(
                    context,
                    title: 'Seuil de solde faible',
                    initial: settings.lowBalanceThreshold,
                  );
                  if (value == null) return;
                  await ref.read(appProvider.notifier).updateSettings(
                        settings.copyWith(lowBalanceThreshold: value),
                      );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Données --------------------------------------------------------
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Mes données',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () =>
                        exportMenu(context, ref, data.transactions),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exporter mes transactions'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final bool ok = await confirmDialog(
                        context,
                        title: 'Réinitialiser les données locales',
                        message:
                            'Toutes les données de cet appareil seront '
                            'effacées. Si tu es connecté, elles reviendront '
                            'à la prochaine synchronisation.',
                        confirmLabel: 'Réinitialiser',
                      );
                      if (ok) {
                        await ref.read(appProvider.notifier).resetLocalData();
                      }
                    },
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Budget ${AppConfig.appVersion} · '
                '${data.transactions.length} transactions · '
                '${data.bills.length} factures',
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

Future<String?> _askPin(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Choisir un code PIN'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        decoration: const InputDecoration(labelText: 'Code à 4 chiffres'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.length != 4) return;
            Navigator.of(context).pop(controller.text);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

Future<double?> _askAmount(
  BuildContext context, {
  required String title,
  required double initial,
}) async {
  final TextEditingController controller =
      TextEditingController(text: initial.toStringAsFixed(2));
  return showDialog<double>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: r'$ '),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            double.tryParse(controller.text.replaceAll(',', '.')),
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

Future<void> _openAccountEditor(
  BuildContext context,
  WidgetRef ref, {
  Account? existing,
}) async {
  final TextEditingController name =
      TextEditingController(text: existing?.name ?? '');
  final TextEditingController balance = TextEditingController(
    text: (existing?.balance ?? 0).toStringAsFixed(2),
  );
  bool isInvestment = existing?.isInvestment ?? false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text(existing == null ? 'Nouveau compte' : 'Modifier le compte'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom du compte'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Solde d\'ouverture',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isInvestment,
                title: const Text('Compte d\'investissement'),
                onChanged: (bool v) => setState(() => isInvestment = v),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          if (existing != null)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await ref
                    .read(appProvider.notifier)
                    .deleteAccount(existing.id);
              },
              child: const Text('Supprimer'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await ref.read(appProvider.notifier).saveAccount(
                    id: existing?.id,
                    name: name.text.trim(),
                    openingBalance: double.tryParse(
                          balance.text.replaceAll(',', '.'),
                        ) ??
                        0,
                    isInvestment: isInvestment,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}
