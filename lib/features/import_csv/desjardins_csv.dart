import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import '../../core/utils/date_helpers.dart';
import '../../data/models/finance_models.dart';

/// Une ligne lue dans le fichier CSV, avant confirmation par l'utilisateur.
class ParsedRow {
  ParsedRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.externalKey,
    required this.suggestedCategory,
    this.duplicate = false,
    this.selected = true,
    this.categoryId,
  });

  final String date;
  final String description;
  final double amount;
  final TxnType type;

  /// Empreinte stable de la ligne : sert à ne jamais importer deux fois
  /// la même opération, même lors d'un import partiel.
  final String externalKey;

  /// Nom de catégorie déduit de la description (peut ne correspondre à
  /// aucune catégorie existante).
  final String suggestedCategory;

  bool duplicate;
  bool selected;
  String? categoryId;
}

class ImportPreview {
  const ImportPreview({
    required this.rows,
    required this.duplicates,
    this.error,
  });

  const ImportPreview.failure(String message)
      : rows = const <ParsedRow>[],
        duplicates = 0,
        error = message;

  final List<ParsedRow> rows;
  final int duplicates;
  final String? error;

  bool get ok => error == null;
}

/// Lecteur de relevés CSV Desjardins (AccèsD → « Télécharger les opérations »).
///
/// Le format n'est pas garanti d'une exportation à l'autre : le lecteur est
/// donc tolérant. Il détecte le séparateur, la présence d'une ligne d'en-tête,
/// la colonne de date, la description, puis les montants — que le fichier
/// utilise deux colonnes (retrait / dépôt) ou une seule colonne signée.
class DesjardinsCsv {
  const DesjardinsCsv._();

  /// Mots-clés → nom de catégorie par défaut de l'application.
  static const Map<String, List<String>> categoryRules =
      <String, List<String>>{
    'Épicerie': <String>[
      'IGA', 'METRO', 'MAXI', 'SUPER C', 'PROVIGO', 'COSTCO', 'ADONIS',
      'EPICERIE', 'MARCHE', 'WALMART',
    ],
    'Essence': <String>[
      'ESSO', 'SHELL', 'PETRO', 'ULTRAMAR', 'COUCHE-TARD', 'IRVING',
      'CREVIER', 'SONIC', 'ESSENCE',
    ],
    'Restaurant': <String>[
      'RESTAURANT', 'RESTO', 'MCDONALD', 'TIM HORTONS', 'SUBWAY', 'A&W',
      'ST-HUBERT', 'PIZZA', 'CAFE', 'STARBUCKS', 'UBER EATS', 'DOORDASH',
      'BAR ',
    ],
    'Transport': <String>[
      'STM', 'RTC', 'EXO', 'UBER', 'TAXI', 'STATIONNEMENT', 'PARKING',
      'AUTOBUS', 'VIA RAIL',
    ],
    'Loisirs': <String>[
      'NETFLIX', 'SPOTIFY', 'DISNEY', 'CINEMA', 'CINEPLEX', 'STEAM',
      'PLAYSTATION', 'XBOX', 'AMAZON PRIME', 'APPLE.COM',
    ],
    'Santé': <String>[
      'PHARMAPRIX', 'JEAN COUTU', 'UNIPRIX', 'BRUNET', 'CLINIQUE',
      'DENTISTE', 'PHARMACIE', 'OPTOMETRIE',
    ],
    'Maison': <String>[
      'HYDRO', 'VIDEOTRON', 'BELL', 'TELUS', 'ROGERS', 'FIZZ', 'LOYER',
      'ASSURANCE', 'INTERNET', 'ENERGIR', 'RONA', 'HOME DEPOT', 'CANAC',
    ],
    'Vêtements': <String>[
      'WINNERS', 'SIMONS', 'ZARA', 'H&M', 'SPORTS EXPERTS', 'ARDENE',
      'MARKS', 'UNIQLO',
    ],
    'Études': <String>[
      'UNIVERSITE', 'CEGEP', 'COLLEGE', 'LIBRAIRIE', 'COOPSCO', 'SCOLAIRE',
    ],
    'Salaire': <String>[
      'PAIE', 'SALAIRE', 'DEPOT SALAIRE', 'PAYROLL', 'DEPOT DIRECT',
      'REMISE', 'ALLOCATION',
    ],
  };

  /// Analyse le contenu d'un fichier CSV.
  ///
  /// [knownKeys] contient les empreintes déjà importées : les lignes
  /// correspondantes sont marquées comme doublons et décochées.
  static ImportPreview parse(String content, Set<String> knownKeys) {
    if (content.trim().isEmpty) {
      return const ImportPreview.failure('Le fichier est vide.');
    }

    final String delimiter = _detectDelimiter(content);

    List<List<dynamic>> rows;
    try {
      rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: content.contains('\r\n') ? '\r\n' : '\n',
        shouldParseNumbers: false,
      ).convert(content);
    } catch (_) {
      return const ImportPreview.failure(
        'Fichier illisible. Vérifie qu\'il s\'agit bien d\'un CSV.',
      );
    }

    if (rows.isEmpty) {
      return const ImportPreview.failure('Aucune ligne trouvée.');
    }

    final List<ParsedRow> parsed = <ParsedRow>[];
    int duplicates = 0;

    for (final List<dynamic> raw in rows) {
      final List<String> cells =
          raw.map((dynamic c) => c.toString().trim()).toList();
      if (cells.every((String c) => c.isEmpty)) continue;

      final String? date = _findDate(cells);
      if (date == null) continue; // en-tête ou ligne de total

      final String description = _findDescription(cells);
      final ({double amount, TxnType type})? money =
          _findAmount(cells, description);
      if (money == null || money.amount <= 0) continue;

      final String key = _fingerprint(date, money.amount, money.type,
          description);
      final bool duplicate = knownKeys.contains(key);
      if (duplicate) duplicates++;

      parsed.add(
        ParsedRow(
          date: date,
          description: description,
          amount: money.amount,
          type: money.type,
          externalKey: key,
          suggestedCategory: suggestCategory(description, money.type),
          duplicate: duplicate,
          selected: !duplicate,
        ),
      );
    }

    if (parsed.isEmpty) {
      return const ImportPreview.failure(
        'Aucune transaction reconnue dans ce fichier. '
        'Exporte tes opérations depuis AccèsD au format CSV.',
      );
    }

    parsed.sort((ParsedRow a, ParsedRow b) => b.date.compareTo(a.date));
    return ImportPreview(rows: parsed, duplicates: duplicates);
  }

  /// Catégorie suggérée à partir de la description de l'opération.
  static String suggestCategory(String description, TxnType type) {
    final String upper = _normalize(description);
    for (final MapEntry<String, List<String>> entry in categoryRules.entries) {
      for (final String keyword in entry.value) {
        if (upper.contains(keyword)) {
          final bool isIncomeRule = entry.key == 'Salaire';
          if (isIncomeRule == (type == TxnType.income)) return entry.key;
        }
      }
    }
    return type == TxnType.income ? 'Salaire' : 'Autres';
  }

  // ---------------------------------------------------------------------------

  static String _detectDelimiter(String content) {
    final String firstLine = content.split('\n').first;
    final int semicolons = ';'.allMatches(firstLine).length;
    final int commas = ','.allMatches(firstLine).length;
    return semicolons > commas ? ';' : ',';
  }

  static String _normalize(String value) {
    const Map<String, String> accents = <String, String>{
      'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c',
    };
    String out = value.toLowerCase();
    accents.forEach((String from, String to) {
      out = out.replaceAll(from, to);
    });
    return out.toUpperCase();
  }

  /// Cherche la première cellule qui ressemble à une date et la normalise.
  static String? _findDate(List<String> cells) {
    for (final String cell in cells) {
      final String value = cell.trim();
      if (value.length < 8) continue;

      final RegExpMatch? iso =
          RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(value);
      if (iso != null) {
        return _iso(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
        );
      }

      final RegExpMatch? dmy =
          RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(value);
      if (dmy != null) {
        return _iso(
          int.parse(dmy.group(3)!),
          int.parse(dmy.group(2)!),
          int.parse(dmy.group(1)!),
        );
      }
    }
    return null;
  }

  static String _iso(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return DateHelpers.todayIso();
    }
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Détermine le montant et le sens de l'opération.
  ///
  /// Cas gérés :
  ///  - deux colonnes « retrait » et « dépôt » (format Desjardins classique) ;
  ///  - une colonne unique dont le signe donne le sens.
  ///
  /// La dernière colonne numérique est ignorée quand elle représente le solde
  /// (c'est-à-dire lorsqu'au moins trois nombres sont présents).
  static ({double amount, TxnType type})? _findAmount(
    List<String> cells,
    String description,
  ) {
    final List<int> numeric = <int>[];
    for (int i = 0; i < cells.length; i++) {
      if (RegExp(r'^\d{4}[-/]\d{1,2}').hasMatch(cells[i])) continue;
      if (_toNumber(cells[i]) == null) continue;
      numeric.add(i);
    }
    if (numeric.isEmpty) return null;

    // Format Desjardins classique : … | retrait | dépôt | solde
    // La dernière colonne numérique est le solde ; les deux colonnes qui la
    // précèdent portent le retrait puis le dépôt, l'une des deux étant vide.
    if (numeric.length >= 2) {
      final int balanceIndex = numeric.last;
      if (balanceIndex >= 2) {
        final double? withdrawal = _toNumber(cells[balanceIndex - 2]);
        final double? deposit = _toNumber(cells[balanceIndex - 1]);
        if (withdrawal != null && withdrawal != 0) {
          return (amount: withdrawal.abs(), type: TxnType.expense);
        }
        if (deposit != null && deposit != 0) {
          return (amount: deposit.abs(), type: TxnType.income);
        }
      }
    }

    // Colonne unique : le signe tranche, sinon on se fie à la description.
    for (final int index in numeric) {
      final double value = _toNumber(cells[index])!;
      if (value == 0) continue;
      if (value < 0) {
        return (amount: value.abs(), type: TxnType.expense);
      }
      return (
        amount: value,
        type: _looksLikeIncome(description) ? TxnType.income : TxnType.expense,
      );
    }
    return null;
  }

  static bool _looksLikeIncome(String description) {
    final String upper = _normalize(description);
    for (final String keyword in categoryRules['Salaire']!) {
      if (upper.contains(keyword)) return true;
    }
    return upper.contains('DEPOT') || upper.contains('VIREMENT RECU');
  }

  static double? _toNumber(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return null;
    value = value
        .replaceAll(r'$', '')
        .replaceAll(' ', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) return null;
    return double.tryParse(value);
  }

  static String _findDescription(List<String> cells) {
    String best = '';
    for (final String cell in cells) {
      if (_toNumber(cell) != null) continue;
      // Dates et numéros de compte (chiffres, tirets, espaces) : pas des
      // descriptions.
      if (RegExp(r'^\d{4}[-/]\d{1,2}').hasMatch(cell)) continue;
      if (RegExp(r'^[\d\s\-/.]+$').hasMatch(cell)) continue;
      if (cell.length > best.length) best = cell;
    }
    return best.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _fingerprint(
    String date,
    double amount,
    TxnType type,
    String description,
  ) {
    final String base =
        '$date|${amount.toStringAsFixed(2)}|${txnTypeTo(type)}|'
        '${_normalize(description)}';
    return sha1.convert(utf8.encode(base)).toString().substring(0, 24);
  }
}
