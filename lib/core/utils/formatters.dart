import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// Formatage des montants et des dates, en français canadien.
class Fmt {
  const Fmt._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppConfig.currencyLocale,
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: AppConfig.currencyLocale,
    symbol: r'$',
  );

  static String money(num? value) => _currency.format(value ?? 0);

  static String moneyCompact(num? value) => _compact.format(value ?? 0);

  static String signedMoney(num value) =>
      value >= 0 ? '+${money(value)}' : '-${money(value.abs())}';

  static String percent(num value) => '${value.round()} %';

  static final DateFormat _dayMonth = DateFormat('d MMM', 'fr_CA');
  static final DateFormat _full = DateFormat('d MMMM yyyy', 'fr_CA');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'fr_CA');
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  static String date(DateTime d) => _full.format(d);
  static String shortDate(DateTime d) => _dayMonth.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);
  static String iso(DateTime d) => _iso.format(d);

  static String time(int? minutesFromMidnight) {
    if (minutesFromMidnight == null) return '';
    final int h = minutesFromMidnight ~/ 60;
    final int m = minutesFromMidnight % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Capitalise la première lettre (les mois en français sortent en minuscule).
  static String capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
