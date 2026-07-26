import 'package:flutter/material.dart';

/// Palette et thèmes clair/sombre, repris de la version web de l'application.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF818CF8);
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF34D399);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E5E7);
  static const Color lightText = Color(0xFF0A0A0B);
  static const Color lightMuted = Color(0xFF71717A);

  static const Color darkBg = Color(0xFF0A0A0B);
  static const Color darkCard = Color(0xFF141416);
  static const Color darkBorder = Color(0xFF26262A);
  static const Color darkText = Color(0xFFF5F5F7);
  static const Color darkMuted = Color(0xFFA1A1AA);

  /// Palette proposée pour les catégories créées par l'utilisateur.
  static const List<Color> categoryPalette = <Color>[
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF0EA5E9),
    Color(0xFFEF4444),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF94A3B8),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color primary = isDark ? AppColors.primaryDark : AppColors.primary;
    final Color bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final Color card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color text = isDark ? AppColors.darkText : AppColors.lightText;
    final Color muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      surface: card,
      error: isDark ? AppColors.dangerDark : AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withOpacity(0.15),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        selectedIconTheme: IconThemeData(color: primary),
        selectedLabelTextStyle:
            TextStyle(color: primary, fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: muted),
        unselectedLabelTextStyle: TextStyle(color: muted),
        indicatorColor: primary.withOpacity(0.15),
        useIndicator: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: muted, textColor: text),
      textTheme: (isDark ? Typography.whiteMountainView : Typography.blackMountainView)
          .copyWith(bodySmall: TextStyle(color: muted, fontSize: 12)),
    );
  }
}

/// Raccourcis pratiques pour retrouver les couleurs sémantiques.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get successColor => isDark ? AppColors.successDark : AppColors.success;
  Color get dangerColor => isDark ? AppColors.dangerDark : AppColors.danger;
  Color get warningColor => isDark ? AppColors.warningDark : AppColors.warning;
  Color get mutedColor => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get cardColor => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get bgColor => isDark ? AppColors.darkBg : AppColors.lightBg;
}
