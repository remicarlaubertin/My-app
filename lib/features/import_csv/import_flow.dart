import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/finance_models.dart';
import '../../data/repository/budget_repository.dart';
import '../../data/repository/budget_selectors.dart';
import '../../providers/app_providers.dart';
import 'desjardins_csv.dart';

const Uuid _uuid = Uuid();

/// Point d'entrée de l'import Desjardins.
///
/// [path] est fourni lorsqu'un fichier a été glissé-déposé sur la fenêtre ;
/// sinon un sélecteur de fichier est ouvert.
Future<void> openImportFlow(
  BuildContext context,
  WidgetRef ref, {
  String? path,
}) async {
  String? filePath = path;

  if (filePath == null) {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    filePath = result.files.single.path;
  }
  if (filePath == null) return;

  String content;
  try {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();
    // Les exportations Desjardins sont souvent encodées en latin-1.
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      content = latin1.decode(bytes);
    }
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Impossible de lire le fichier sélectionné.');
    }
    return;
  }

  final Set<String> knownKeys =
      await ref.read(repositoryProvider).knownExternalKeys();
  final ImportPreview preview = DesjardinsCsv.parse(content, knownKeys);

  if (!context.mounted) return;

  if (!preview.ok) {
    showSnack(context, preview.error!);
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) => _ImportDialog(
      preview: preview,
      fileName: filePath!.split(Platform.pathSeparator).last,
    ),
  );
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({required this.preview, required this.fileName});

  final ImportPreview preview;
  final String fileName;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  late final List<ParsedRow> _rows;
  bool _hideDuplicates = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.preview.rows;

    // Associe chaque ligne à une catégorie existante à partir du nom suggéré.
    // La catégorie retenue appartient toujours à la liste proposée dans le
    // menu déroulant (même type de transaction), sinon le menu planterait.
    final BudgetData data = ref.read(dataProvider);
    for (final ParsedRow row in _rows) {
      final List<Category> choices = data.categoriesOfType(row.type);
      Category? match;
      for (final Category c in choices) {
        if (c.name.toLowerCase() == row.suggestedCategory.toLowerCase()) {
          match = c;
          break;
        }
      }
      match ??= choices.isNotEmpty ? choices.first : null;
      row.categoryId = match?.id;
    }
  }

  List<ParsedRow> get _visible => _hideDuplicates
      ? _rows.where((ParsedRow r) => !r.duplicate).toList()
      : _rows;

  int get _selectedCount => _rows
      .where((ParsedRow r) => r.selected && r.categoryId != null)
      .length;

  double get _selectedTotal => _rows
      .where((ParsedRow r) => r.selected)
      .fold<double>(0, (double s, ParsedRow r) => s + r.signed);

  Future<void> _confirm() async {
    setState(() => _importing = true);
    final BudgetData data = ref.read(dataProvider);
    final String accountId = data.mainAccount?.id ?? '';

    // Une ligne sans catégorie serait invisible dans les statistiques :
    // on ne l'importe pas.
    final List<Txn> transactions = _rows
        .where((ParsedRow r) => r.selected && r.categoryId != null)
        .map(
          (ParsedRow r) => Txn(
            id: _uuid.v4(),
            type: r.type,
            amount: r.amount,
            categoryId: r.categoryId!,
            accountId: accountId,
            date: r.date,
            description: r.description,
            source: 'csv',
            externalKey: r.externalKey,
            updatedAt: DateTime.now().toUtc(),
          ),
        )
        .toList();

    final int count =
        await ref.read(appProvider.notifier).importTransactions(transactions);

    if (mounted) {
      Navigator.of(context).pop();
      showSnack(context, '$count transaction(s) importée(s).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final BudgetData data = ref.watch(dataProvider);
    final List<ParsedRow> visible = _visible;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Importer mes transactions Desjardins'),
          const SizedBox(height: 4),
          Text(
            '${widget.fileName} · ${_rows.length} ligne(s) lue(s) · '
            '${widget.preview.duplicates} doublon(s) détecté(s)',
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Checkbox(
                  value: _hideDuplicates,
                  onChanged: (bool? v) =>
                      setState(() => _hideDuplicates = v ?? true),
                ),
                const Text('Masquer les doublons déjà importés'),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    for (final ParsedRow r in visible) {
                      r.selected = true;
                    }
                  }),
                  child: const Text('Tout cocher'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final ParsedRow r in visible) {
                      r.selected = false;
                    }
                  }),
                  child: const Text('Tout décocher'),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (BuildContext context, int index) {
                  final ParsedRow row = visible[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: <Widget>[
                        Checkbox(
                          value: row.selected,
                          onChanged: (bool? v) =>
                              setState(() => row.selected = v ?? false),
                        ),
                        SizedBox(
                          width: 84,
                          child: Text(
                            Fmt.shortDate(DateHelpers.fromIso(row.date)),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.description.isEmpty
                                ? 'Opération'
                                : row.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: row.duplicate ? context.mutedColor : null,
                              fontStyle: row.duplicate
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            value: row.categoryId,
                            isDense: true,
                            hint: const Text(
                              'Catégorie',
                              style: TextStyle(fontSize: 12),
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            items: <DropdownMenuItem<String>>[
                              for (final Category c
                                  in data.categoriesOfType(row.type))
                                DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                            onChanged: (String? v) =>
                                setState(() => row.categoryId = v),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            Fmt.signedMoney(row.signed),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: row.type == TxnType.expense
                                  ? context.dangerColor
                                  : context.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: <Widget>[
                  Text(
                    '$_selectedCount transaction(s) sélectionnée(s)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    'Impact net : ${Fmt.signedMoney(_selectedTotal)}',
                    style: TextStyle(color: context.mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _importing || _selectedCount == 0 ? null : _confirm,
          child: Text(
            _importing ? 'Import en cours…' : 'Importer $_selectedCount ligne(s)',
          ),
        ),
      ],
    );
  }
}

extension on ParsedRow {
  double get signed => type == TxnType.expense ? -amount : amount;
}
