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

    final List<List<String>> allCells = rows
        .map(
          (List<dynamic> raw) =>
              raw.map((dynamic c) => c.toString().trim()).toList(),
        )
        .where((List<String> cells) => cells.any((String c) => c.isNotEmpty))
        .toList();

    // Certains exports Desjardins répètent sur chaque ligne des colonnes
    // qui ne décrivent pas l'opération elle-même (nom de la caisse, numéro
    // de compte, type de compte). Ces colonnes ont la même valeur partout :
    // on les repère une fois pour ne jamais les confondre avec la
    // description ou le montant d'une transaction.
    final Set<int> constantColumns = _findConstantColumns(allCells);

    final List<_PendingRow> pending = <_PendingRow>[];
    int index = 0;
    for (final List<String> cells in allCells) {
      final int rowIndex = index++;
      final String? date = _findDate(cells);
      if (date == null) continue; // en-tête ou ligne de total

      final String description = _findDescription(cells, constantColumns);
      final _RawMoney? raw = _findRawAmount(cells, constantColumns);
      if (raw == null || raw.amount <= 0) continue;

      pending.add(
        _PendingRow(
          date: date,
          description: description,
          fileOrder: rowIndex,
          raw: raw,
        ),
      );
    }

    if (pending.isEmpty) {
      return const ImportPreview.failure(
        'Aucune transaction reconnue dans ce fichier. '
        'Exporte tes opérations depuis AccèsD au format CSV.',
      );
    }

    // Le sens (entrée/sortie) de chaque opération est déterminé en comparant
    // le solde d'une ligne à celui de la précédente, dans l'ordre
    // chronologique : un solde qui augmente est une entrée, un solde qui
    // diminue est une sortie. Beaucoup plus fiable que de deviner à partir
    // de mots-clés dans la description (« reçu de » vs « envoyé à », etc.).
    // On trie par date puis par ordre d'apparition dans le fichier, en
    // supposant que les lignes d'une même date y sont déjà dans l'ordre.
    final List<_PendingRow> chronological = List<_PendingRow>.from(pending)
      ..sort((_PendingRow a, _PendingRow b) {
        final int byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.fileOrder.compareTo(b.fileOrder);
      });

    final Map<_PendingRow, TxnType> types = <_PendingRow, TxnType>{};
    double? previousBalance;
    for (final _PendingRow row in chronological) {
      final _RawMoney raw = row.raw;
      TxnType type;
      if (raw.isDeposit == true) {
        type = TxnType.income;
      } else if (raw.isDeposit == false) {
        type = TxnType.expense;
      } else if (raw.negative) {
        type = TxnType.expense;
      } else if (previousBalance != null &&
          raw.balance != null &&
          (raw.balance! - previousBalance).abs() >= 0.005) {
        type = raw.balance! > previousBalance ? TxnType.income : TxnType.expense;
      } else {
        type = _looksLikeIncome(row.description)
            ? TxnType.income
            : TxnType.expense;
      }
      if (raw.balance != null) previousBalance = raw.balance;
      types[row] = type;
    }

    final List<ParsedRow> parsed = <ParsedRow>[];
    int duplicates = 0;

    for (final _PendingRow row in pending) {
      final TxnType type = types[row]!;
      final String key =
          _fingerprint(row.date, row.raw.amount, type, row.description);
      final bool duplicate = knownKeys.contains(key);
      if (duplicate) duplicates++;

      parsed.add(
        ParsedRow(
          date: row.date,
          description: row.description,
          amount: row.raw.amount,
          type: type,
          externalKey: key,
          suggestedCategory: suggestCategory(row.description, type),
          duplicate: duplicate,
          selected: !duplicate,
        ),
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

  /// Repère les colonnes dont la valeur ne change jamais d'une ligne à
  /// l'autre (nom de la caisse, numéro de compte, type de compte...).
  /// Nécessite au moins 3 lignes de données pour éviter les faux positifs
  /// sur de petits fichiers.
  static Set<int> _findConstantColumns(List<List<String>> allCells) {
    if (allCells.length < 3) return const <int>{};

    final int width =
        allCells.map((List<String> c) => c.length).reduce((a, b) => a > b ? a : b);
    final Set<int> constant = <int>{};

    for (int col = 0; col < width; col++) {
      String? seen;
      bool isConstant = true;
      int nonEmptyCount = 0;
      for (final List<String> cells in allCells) {
        if (col >= cells.length) continue;
        final String value = cells[col];
        if (value.isEmpty) continue;
        nonEmptyCount++;
        seen ??= value;
        if (value != seen) {
          isConstant = false;
          break;
        }
      }
      if (isConstant && nonEmptyCount >= 3) constant.add(col);
    }
    return constant;
  }

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

  /// Résultat brut de la lecture d'une ligne : le montant absolu, le solde
  /// (s'il est identifiable), et des indices sur le sens de l'opération
  /// quand le fichier le donne explicitement (deux colonnes retrait/dépôt,
  /// ou une colonne signée). Le sens final est tranché ensuite, en dehors
  /// de cette fonction, en comparant les soldes d'une ligne à l'autre.
  static _RawMoney? _findRawAmount(
    List<String> cells,
    Set<int> excluded,
  ) {
    final List<int> numeric = <int>[];
    for (int i = 0; i < cells.length; i++) {
      if (excluded.contains(i)) continue;
      if (RegExp(r'^\d{4}[-/]\d{1,2}').hasMatch(cells[i])) continue;
      if (_toNumber(cells[i]) == null) continue;
      numeric.add(i);
    }
    if (numeric.isEmpty) return null;

    // Un numéro de compte ou de transaction est un entier sans centimes ;
    // un vrai montant s'écrit toujours avec une décimale. Quand au moins
    // deux valeurs décimales existent, on les préfère aux entiers bruts
    // pour éviter de confondre un identifiant avec un montant.
    final List<int> money =
        numeric.where((int i) => _hasDecimals(cells[i])).toList();
    final List<int> candidates = money.length >= 2 ? money : numeric;

    // Format Desjardins classique : … | retrait | dépôt | solde
    // La dernière valeur retenue est le solde ; celles qui restent avant
    // sont le retrait puis le dépôt (l'une des deux étant vide ou nulle),
    // ou un montant unique s'il n'y en a qu'une.
    final int balanceIndex = candidates.last;
    final double? balanceValue = _toNumber(cells[balanceIndex]);
    final List<int> before =
        candidates.where((int i) => i != balanceIndex).toList();

    if (before.length >= 2) {
      final double? withdrawal = _toNumber(cells[before[before.length - 2]]);
      final double? deposit = _toNumber(cells[before[before.length - 1]]);
      if (withdrawal != null && withdrawal != 0) {
        return _RawMoney(
          amount: withdrawal.abs(),
          balance: balanceValue,
          isDeposit: false,
          negative: withdrawal < 0,
        );
      }
      if (deposit != null && deposit != 0) {
        return _RawMoney(
          amount: deposit.abs(),
          balance: balanceValue,
          isDeposit: true,
          negative: false,
        );
      }
    }

    // Colonne unique : le signe (s'il est présent) donne le sens ; sinon
    // il sera déterminé plus tard par comparaison des soldes.
    for (final int i in before) {
      final double value = _toNumber(cells[i])!;
      if (value == 0) continue;
      return _RawMoney(
        amount: value.abs(),
        balance: balanceValue,
        isDeposit: null,
        negative: value < 0,
      );
    }
    return null;
  }

  static bool _hasDecimals(String raw) {
    final String value = raw.trim();
    return value.contains('.') || value.contains(',');
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

  static String _findDescription(List<String> cells, Set<int> excluded) {
    String best = '';
    for (int i = 0; i < cells.length; i++) {
      if (excluded.contains(i)) continue;
      final String cell = cells[i];
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

/// Ligne encore en attente de décision sur son sens (entrée/sortie), le
/// temps de comparer les soldes de toutes les lignes du fichier.
class _PendingRow {
  _PendingRow({
    required this.date,
    required this.description,
    required this.fileOrder,
    required this.raw,
  });

  final String date;
  final String description;
  final int fileOrder;
  final _RawMoney raw;
}

/// Montant et solde bruts extraits d'une ligne, avant de trancher son sens.
class _RawMoney {
  const _RawMoney({
    required this.amount,
    required this.balance,
    required this.isDeposit,
    required this.negative,
  });

  final double amount;
  final double? balance;

  /// true = colonne dépôt explicite, false = colonne retrait explicite,
  /// null = colonne unique, sens encore inconnu.
  final bool? isDeposit;

  /// true si la valeur brute portait déjà un signe négatif.
  final bool negative;
}
