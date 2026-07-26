import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/pin_lock_screen.dart';
import 'features/auth/pin_service.dart';
import 'features/shell/app_shell.dart';
import 'providers/app_providers.dart';

/// Vrai lorsque l'utilisateur a déverrouillé l'application pour cette session.
final StateProvider<bool> unlockedProvider =
    StateProvider<bool>((Ref ref) => false);

/// Vrai si un code PIN est réellement enregistré dans le coffre du système.
///
/// Le réglage `pinEnabled` voyage avec la synchronisation, alors que le code
/// lui-même reste sur l'appareil : sans cette vérification, une réinstallation
/// pourrait verrouiller l'application avec un code que personne ne possède.
final FutureProvider<bool> pinConfiguredProvider =
    FutureProvider<bool>((Ref ref) => const PinService().isConfigured());

class BudgetApp extends ConsumerStatefulWidget {
  const BudgetApp({super.key});

  @override
  ConsumerState<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends ConsumerState<BudgetApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool darkMode =
        ref.watch(appProvider.select((AppState s) => s.data.settings.darkMode));

    return MaterialApp(
      title: 'Budget',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('fr', 'CA'),
      supportedLocales: const <Locale>[
        Locale('fr', 'CA'),
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppState state = ref.watch(appProvider);

    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool locked =
        state.data.settings.pinEnabled && !ref.watch(unlockedProvider);

    if (locked) {
      return ref.watch(pinConfiguredProvider).when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (Object _, StackTrace __) => const AppShell(),
            data: (bool configured) => configured
                ? PinLockScreen(
                    onUnlocked: () =>
                        ref.read(unlockedProvider.notifier).state = true,
                    pinService: const PinService(),
                  )
                : const AppShell(),
          );
    }

    return const AppShell();
  }
}
