/// Utilitaires de dates partagés par toute l'application.
///
/// Convention : les dates « métier » (transaction, facture, événement) sont
/// stockées en texte ISO `yyyy-MM-dd`, ce qui rend les comparaisons et les
/// tris triviaux, y compris en SQL.
class DateHelpers {
  const DateHelpers._();

  static DateTime today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String todayIso() => toIso(today());

  static String toIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime fromIso(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) return today();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Premier jour du mois (inclus) et premier jour du mois suivant (exclu).
  static ({String start, String end}) monthRange([DateTime? reference]) {
    final DateTime ref = reference ?? DateTime.now();
    final DateTime start = DateTime(ref.year, ref.month, 1);
    final DateTime end = DateTime(ref.year, ref.month + 1, 1);
    return (start: toIso(start), end: toIso(end));
  }

  static DateTime addMonths(DateTime date, int months) {
    final int totalMonths = date.month - 1 + months;
    // Division entière « vers le bas », valable aussi pour les mois négatifs.
    final int yearShift =
        totalMonths >= 0 ? totalMonths ~/ 12 : ((totalMonths - 11) ~/ 12);
    final int year = date.year + yearShift;
    final int month = totalMonths - yearShift * 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  static DateTime startOfWeek(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int daysBetween(DateTime from, DateTime to) {
    final DateTime a = DateTime(from.year, from.month, from.day);
    final DateTime b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Les 12 derniers mois, du plus ancien au plus récent.
  static List<DateTime> lastMonths(int count) {
    final DateTime now = DateTime.now();
    return List<DateTime>.generate(
      count,
      (int i) => DateTime(now.year, now.month - (count - 1 - i), 1),
    );
  }
}
