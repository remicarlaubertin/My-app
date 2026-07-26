/// Contrat commun à toutes les entités synchronisées.
///
/// Chaque table possède les mêmes trois colonnes techniques :
///  - `id`          : identifiant UUID généré sur l'appareil
///  - `updated_at`  : date de dernière modification (UTC) → arbitrage de la
///                    synchronisation, dernier écrivain gagne
///  - `deleted`     : suppression logique, pour que l'effacement se propage
///                    aussi entre les appareils
abstract class SyncEntity {
  String get id;
  DateTime get updatedAt;
  bool get deleted;

  Map<String, dynamic> toMap();
}

/// Conversions tolérantes : les valeurs viennent tantôt de SQLite
/// (entiers pour les booléens), tantôt de Supabase (types natifs).
bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1' || value == 't';
  return fallback;
}

double asDouble(Object? value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
}

int asInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

String asString(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

DateTime asDate(Object? value) {
  if (value == null) return DateTime.now().toUtc();
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc() ?? DateTime.now().toUtc();
}

String isoNow() => DateTime.now().toUtc().toIso8601String();
