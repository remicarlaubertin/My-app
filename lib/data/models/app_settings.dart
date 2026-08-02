import 'sync_entity.dart';

/// Réglages de l'application, stockés dans une table clé/valeur locale et
/// synchronisés dans une ligne unique côté Supabase.
class AppSettings {
  const AppSettings({
    this.darkMode = false,
    this.investmentEnabled = false,
    this.investmentPercent = 50,
    this.notificationsEnabled = true,
    this.lowBalanceThreshold = 100,
    this.pinEnabled = false,
    this.hideAmounts = false,
    this.lastAutoTransferMonth,
    this.lastSyncAt,
  });

  final bool darkMode;

  /// Règle automatique de fin de mois.
  final bool investmentEnabled;
  final int investmentPercent;

  final bool notificationsEnabled;

  /// Seuil déclenchant l'alerte « solde faible ».
  final double lowBalanceThreshold;

  final bool pinEnabled;

  /// Masque tous les montants affichés (mode confidentialité).
  final bool hideAmounts;

  /// Dernier mois (`yyyy-MM`) pour lequel le transfert automatique a été fait.
  final String? lastAutoTransferMonth;

  final DateTime? lastSyncAt;

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        darkMode: asBool(m['dark_mode']),
        investmentEnabled: asBool(m['investment_enabled']),
        investmentPercent: asInt(m['investment_percent'], fallback: 50),
        notificationsEnabled: asBool(m['notifications_enabled'], fallback: true),
        lowBalanceThreshold:
            asDouble(m['low_balance_threshold'], fallback: 100),
        pinEnabled: asBool(m['pin_enabled']),
        hideAmounts: asBool(m['hide_amounts']),
        lastAutoTransferMonth: m['last_auto_transfer_month'] == null
            ? null
            : asString(m['last_auto_transfer_month']),
        lastSyncAt:
            m['last_sync_at'] == null ? null : asDate(m['last_sync_at']),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'dark_mode': darkMode,
        'investment_enabled': investmentEnabled,
        'investment_percent': investmentPercent,
        'notifications_enabled': notificationsEnabled,
        'low_balance_threshold': lowBalanceThreshold,
        'pin_enabled': pinEnabled,
        'hide_amounts': hideAmounts,
        'last_auto_transfer_month': lastAutoTransferMonth,
        'last_sync_at': lastSyncAt?.toUtc().toIso8601String(),
      };

  AppSettings copyWith({
    bool? darkMode,
    bool? investmentEnabled,
    int? investmentPercent,
    bool? notificationsEnabled,
    double? lowBalanceThreshold,
    bool? pinEnabled,
    bool? hideAmounts,
    String? lastAutoTransferMonth,
    DateTime? lastSyncAt,
  }) =>
      AppSettings(
        darkMode: darkMode ?? this.darkMode,
        investmentEnabled: investmentEnabled ?? this.investmentEnabled,
        investmentPercent: investmentPercent ?? this.investmentPercent,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
        pinEnabled: pinEnabled ?? this.pinEnabled,
        hideAmounts: hideAmounts ?? this.hideAmounts,
        lastAutoTransferMonth:
            lastAutoTransferMonth ?? this.lastAutoTransferMonth,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}
