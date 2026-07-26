/// Configuration globale de l'application.
///
/// Les clés Supabase ne sont **jamais** écrites dans le code source.
/// Elles sont injectées à la compilation :
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Si elles sont absentes, l'application démarre en mode 100 % local
/// (base SQLite sur l'appareil, aucune synchronisation).
class AppConfig {
  const AppConfig._();

  static const String appName = 'Budget';
  static const String appVersion = '1.0.0';

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Vrai quand les deux clés ont été fournies à la compilation.
  static bool get cloudConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Passé à `true` par `main()` une fois `Supabase.initialize` réussi.
  /// Tant que l'initialisation n'a pas abouti (démarrage hors ligne),
  /// aucun appel au client Supabase ne doit être tenté.
  static bool cloudInitialized = false;

  /// La synchronisation est réellement utilisable.
  static bool get cloudEnabled => cloudConfigured && cloudInitialized;

  static const String currencyLocale = 'fr_CA';
  static const String currencyCode = 'CAD';
}
