import 'package:budget_app/data/models/finance_models.dart';
import 'package:budget_app/features/import_csv/desjardins_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Import CSV Desjardins', () {
    test('lit un relevé au format retrait / dépôt', () {
      const String csv = '''
0815122-1234567,2026-01-15,,IGA MONTREAL,84.32,,1420.11
0815122-1234567,2026-01-16,,DEPOT SALAIRE,,1500.00,2920.11
0815122-1234567,2026-01-17,,ESSO STATION,52.10,,2868.01
''';

      final ImportPreview preview =
          DesjardinsCsv.parse(csv, <String>{});

      expect(preview.ok, isTrue);
      expect(preview.rows.length, 3);

      final ParsedRow salary = preview.rows
          .firstWhere((ParsedRow r) => r.description.contains('SALAIRE'));
      expect(salary.type, TxnType.income);
      expect(salary.amount, 1500.00);

      final ParsedRow grocery =
          preview.rows.firstWhere((ParsedRow r) => r.description.contains('IGA'));
      expect(grocery.type, TxnType.expense);
      expect(grocery.suggestedCategory, 'Épicerie');
    });

    test('reconnaît les doublons déjà importés', () {
      const String csv = '2026-02-01,METRO PLUS,45.00,,\n';
      final ImportPreview first = DesjardinsCsv.parse(csv, <String>{});
      expect(first.rows.length, 1);

      final ImportPreview second = DesjardinsCsv.parse(
        csv,
        <String>{first.rows.first.externalKey},
      );
      expect(second.duplicates, 1);
      expect(second.rows.first.selected, isFalse);
    });

    test('accepte le point-virgule et les dates jour/mois/année', () {
      const String csv = '15/03/2026;PHARMAPRIX;23,45;;\n';
      final ImportPreview preview = DesjardinsCsv.parse(csv, <String>{});

      expect(preview.ok, isTrue);
      expect(preview.rows.first.date, '2026-03-15');
      expect(preview.rows.first.suggestedCategory, 'Santé');
    });

    test('ignore les lignes sans date (en-têtes)', () {
      const String csv = '''
Compte,Date,Chèque,Description,Retrait,Dépôt,Solde
0815122-1234567,2026-01-15,,IGA,84.32,,1420.11
''';
      final ImportPreview preview = DesjardinsCsv.parse(csv, <String>{});
      expect(preview.rows.length, 1);
    });
  });
}
