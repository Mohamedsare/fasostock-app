import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/breakpoints.dart';
import 'package:provider/provider.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/repositories/products_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/utils/csv_export.dart';
import '../utils/products_csv.dart';
import '../../../shared/utils/share_csv.dart';

/// Callback pour enregistrer l'import en local (offline) : payload = { company_id, store_id, user_id, rows }.
typedef OnOfflineImportCsv = Future<void> Function(Map<String, dynamic> payload);

/// Dialog d'import produits CSV — offline+sync : si hors ligne, enqueue pending 'product_import', sync à la reconnexion.
class ImportProductsCsvDialog extends StatefulWidget {
  const ImportProductsCsvDialog({
    super.key,
    required this.companyId,
    this.currentStoreId,
    required this.onSuccess,
    this.onOfflineImport,
  });

  final String companyId;
  final String? currentStoreId;
  final VoidCallback onSuccess;
  /// Si fourni et hors ligne, l'import est enregistré localement (pending) au lieu d'appeler l'API.
  final OnOfflineImportCsv? onOfflineImport;

  @override
  State<ImportProductsCsvDialog> createState() => _ImportProductsCsvDialogState();
}

class _ImportProductsCsvDialogState extends State<ImportProductsCsvDialog> {
  final ProductsRepository _repo = ProductsRepository();
  PlatformFile? _pickedFile;
  int? _previewCount;
  List<String> _previewErrors = [];
  bool _importing = false;
  int _importCurrent = 0;
  int _importTotal = 0;
  List<String> _importErrors = [];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      if (file.bytes == null) return;
      String text;
      try {
        text = utf8.decode(file.bytes!);
      } catch (_) {
        if (mounted) AppToast.error(context, 'Fichier invalide (encodage non reconnu).');
        return;
      }
      final rows = parseProductsCsv(text);
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _previewCount = rows.length;
        _previewErrors = rows.isEmpty ? ['Aucune ligne produit valide. Vérifiez le format (header: nom, sku, ...).'] : [];
        _importErrors = [];
      });
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e, fallback: 'Impossible de sélectionner le fichier CSV.');
    }
  }

  Future<void> _import() async {
    if (_pickedFile?.bytes == null) return;
    final text = utf8.decode(_pickedFile!.bytes!);
    final rows = parseProductsCsv(text);
    if (rows.isEmpty) return;

    setState(() {
      _importing = true;
      _importCurrent = 0;
      _importTotal = rows.length;
    });
    final userId = context.read<AuthProvider>().user?.id;
    final isOnline = ConnectivityService.instance.isOnline;

    if (!isOnline && widget.onOfflineImport != null) {
      try {
        final payload = <String, dynamic>{
          'company_id': widget.companyId,
          'store_id': widget.currentStoreId,
          'user_id': userId,
          'rows': csvRowsToMaps(rows),
        };
        await widget.onOfflineImport!(payload);
        if (!mounted) return;
        setState(() => _importing = false);
        widget.onSuccess();
        Navigator.of(context).pop();
        AppToast.success(context, 'Import enregistré localement. Les produits seront ajoutés à la prochaine synchronisation.');
      } catch (e) {
        if (mounted) {
          setState(() => _importing = false);
          AppErrorHandler.show(context, e);
        }
      }
      return;
    }

    if (!isOnline) {
      setState(() => _importing = false);
      AppToast.error(context, 'Pas de connexion. Connectez-vous pour importer des produits.');
      return;
    }

    try {
      final result = await _repo.importFromCsv(
        widget.companyId,
        csvRowsToMaps(rows),
        storeId: widget.currentStoreId,
        userId: userId,
        onProgress: (current, total) {
          if (mounted) setState(() { _importCurrent = current; _importTotal = total; });
        },
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importErrors = result.errors;
      });
      if (result.created > 0) {
        widget.onSuccess();
        if (result.errors.isEmpty) {
          Navigator.of(context).pop();
          AppToast.success(context, '${result.created} produit(s) importé(s)');
        } else {
          AppToast.info(context, 'Import partiel : des erreurs sont survenues');
        }
      }
      if (result.created == 0 && result.errors.isNotEmpty) {
        AppToast.error(context, '${result.errors.length} erreur(s) lors de l\'import');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        AppErrorHandler.show(context, e);
      }
    }
  }

  Future<void> _exportModelCsv() async {
    try {
      final csv = getProductsCsvModelTemplate();
      const filename = 'modele-import-produits.csv';
      final bytes = encodeCsv(csv);
      final saved = await saveCsvFile(filename: filename, bytes: bytes);
      if (mounted && saved) AppToast.success(context, 'Modèle CSV enregistré');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < Breakpoints.tablet;
    final insetPadding = isNarrow ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    return AlertDialog(
      insetPadding: insetPadding,
      title: const Text('Importer des produits (CSV)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Colonnes : nom, sku, code_barres, unite, prix_achat, prix_vente, stock_min, description, actif, categorie, marque. Optionnel : stock_entrant.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _exportModelCsv,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('Télécharger le modèle CSV (exemple de remplissage)'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importing ? null : _pickFile,
                icon: const Icon(Icons.upload_file, size: 22),
                label: Text(_pickedFile?.name ?? 'Choisir un fichier CSV', overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
            ),
            if (_importing && _importTotal > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _importCurrent / _importTotal,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Import en cours… $_importCurrent / $_importTotal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
            if (_previewCount != null && !_importing) ...[
              const SizedBox(height: 12),
              Text('$_previewCount ligne(s) produit(s) détectée(s)', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_previewErrors.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._previewErrors.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  )),
            ],
            if (_importErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Erreurs :', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ..._importErrors.take(10).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11)),
                  )),
              if (_importErrors.length > 10)
                Text('... et ${_importErrors.length - 10} autre(s)', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(Breakpoints.minTouchTarget, Breakpoints.minTouchTarget)),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (_importing || _pickedFile == null || _previewCount == null || _previewCount! == 0)
              ? null
              : _import,
          style: FilledButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget)),
          child: _importing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, value: _importTotal > 0 ? _importCurrent / _importTotal : null),
                )
              : const Text('Importer'),
        ),
      ],
    );
  }
}
