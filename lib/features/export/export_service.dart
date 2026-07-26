import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';

/// Propose les formats d'export disponibles.
Future<void> exportMenu(
  BuildContext context,
  WidgetRef ref,
  List<Txn> transactions,
) async {
  if (transactions.isEmpty) {
    showSnack(context, 'Aucune transaction à exporter.');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Exporter en PDF'),
            subtitle: const Text('Relevé mis en page, prêt à imprimer'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ExportService.exportPdf(context, ref, transactions);
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exporter en Excel'),
            subtitle: const Text('Fichier .xlsx exploitable dans un tableur'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ExportService.exportExcel(context, ref, transactions);
            },
          ),
        ],
      ),
    ),
  );
}

class ExportService {
  const ExportService._();

  static Future<void> exportPdf(
    BuildContext context,
    WidgetRef ref,
    List<Txn> transactions,
  ) async {
    final BudgetData data = ref.read(dataProvider);
    final pw.Document doc = pw.Document();

    final double income = transactions
        .where((Txn t) => t.type == TxnType.income)
        .fold<double>(0, (double s, Txn t) => s + t.amount);
    final double expenses = transactions
        .where((Txn t) => t.type == TxnType.expense)
        .fold<double>(0, (double s, Txn t) => s + t.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => <pw.Widget>[
          pw.Text(
            'Relevé de transactions',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Généré le ${Fmt.date(DateTime.now())} · '
            '${transactions.length} transaction(s)',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              _summaryBox('Revenus', Fmt.money(income)),
              _summaryBox('Dépenses', Fmt.money(expenses)),
              _summaryBox('Solde', Fmt.money(income - expenses)),
              _summaryBox('Total des comptes', Fmt.money(data.totalBalance)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: <int, pw.Alignment>{
              3: pw.Alignment.centerRight,
            },
            headers: <String>['Date', 'Catégorie', 'Description', 'Montant'],
            data: transactions
                .map(
                  (Txn t) => <String>[
                    t.date,
                    data.categoryById(t.categoryId)?.name ?? '—',
                    t.description,
                    Fmt.signedMoney(t.signedAmount),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await _save(
      context,
      bytes: await doc.save(),
      fileName: 'transactions_${DateHelpers.todayIso()}.pdf',
    );
  }

  static pw.Widget _summaryBox(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

  static Future<void> exportExcel(
    BuildContext context,
    WidgetRef ref,
    List<Txn> transactions,
  ) async {
    final BudgetData data = ref.read(dataProvider);
    final xl.Excel excel = xl.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Transactions');
    final xl.Sheet sheet = excel['Transactions'];

    sheet.appendRow(<xl.CellValue>[
      xl.TextCellValue('Date'),
      xl.TextCellValue('Type'),
      xl.TextCellValue('Catégorie'),
      xl.TextCellValue('Compte'),
      xl.TextCellValue('Description'),
      xl.TextCellValue('Montant'),
    ]);

    for (final Txn t in transactions) {
      sheet.appendRow(<xl.CellValue>[
        xl.TextCellValue(t.date),
        xl.TextCellValue(t.type == TxnType.income ? 'Revenu' : 'Dépense'),
        xl.TextCellValue(data.categoryById(t.categoryId)?.name ?? '—'),
        xl.TextCellValue(data.accountById(t.accountId)?.name ?? '—'),
        xl.TextCellValue(t.description),
        xl.DoubleCellValue(t.signedAmount),
      ]);
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      if (context.mounted) showSnack(context, 'Export impossible.');
      return;
    }

    await _save(
      context,
      bytes: bytes,
      fileName: 'transactions_${DateHelpers.todayIso()}.xlsx',
    );
  }

  /// Enregistre le fichier : boîte « Enregistrer sous » sur ordinateur,
  /// dossier Documents de l'application sur téléphone.
  static Future<void> _save(
    BuildContext context, {
    required List<int> bytes,
    required String fileName,
  }) async {
    String? target;
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        target = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le fichier',
          fileName: fileName,
        );
        if (target == null) return;
      } else {
        final Directory dir = await getApplicationDocumentsDirectory();
        target = p.join(dir.path, fileName);
      }

      await File(target).writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        showSnack(context, 'Fichier enregistré : $target');
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Impossible d\'enregistrer le fichier.');
      }
    }
  }
}
