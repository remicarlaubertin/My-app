import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/local/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formats de date en français canadien.
  await initializeDateFormatting('fr_CA', null);

  // SQLite : implémentation FFI sur Windows / Linux / macOS.
  AppDatabase.initFfi();

  // Fenêtre desktop : taille de départ, taille minimale, redimensionnable.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const WindowOptions options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(900, 640),
      center: true,
      title: 'Budget — Gestion financière personnelle',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Cloud optionnel : l'application fonctionne sans.
  if (AppConfig.cloudConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      AppConfig.cloudInitialized = true;
    } catch (_) {
      // Démarrage hors ligne : la synchronisation sera simplement inactive.
    }
  }

  runApp(const ProviderScope(child: BudgetApp()));
}
