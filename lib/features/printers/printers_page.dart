import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/services/printer_association_storage.dart';
import '../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/permissions_provider.dart';
import '../pos/services/physical_printer_pdf.dart';
import 'printer_test_jobs.dart';

/// Imprimantes système (package `printing`) — association ticket / facture A4.
class PrintersPage extends ConsumerStatefulWidget {
  const PrintersPage({super.key});

  @override
  ConsumerState<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends ConsumerState<PrintersPage> {
  List<Printer> _printers = [];
  bool _loadingPrinters = true;
  String? _printerListError;

  String? _thermalName;
  String? _a4Name;
  PrinterStorageScope _scope = PrinterStorageScope.user;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadAll();
    });
  }

  Future<void> _reloadAll() async {
    await _refreshPrinters();
    await _loadSavedForScope(_scope);
  }

  Future<void> _loadSavedForScope(PrinterStorageScope scope) async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    final cid = company.currentCompanyId;
    if (uid == null || cid == null) return;

    final data = await PrinterAssociationStorage.loadForScope(
      userId: uid,
      companyId: cid,
      scope: scope,
    );

    if (!mounted) return;
    setState(() {
      _scope = scope;
      _thermalName = data?.thermalPrinterName;
      _a4Name = data?.a4PrinterName;
      _dirty = false;
    });
  }

  Future<void> _refreshPrinters() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _loadingPrinters = false;
          _printerListError =
              'La liste d’imprimantes n’est pas disponible dans le navigateur. Utilisez l’application Windows / Android / iOS.';
          _printers = [];
        });
      }
      return;
    }
    setState(() {
      _loadingPrinters = true;
      _printerListError = null;
    });
    try {
      final list = await Printing.listPrinters();
      if (!mounted) return;
      setState(() {
        _printers = list;
        _loadingPrinters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printers = [];
        _loadingPrinters = false;
        _printerListError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    final cid = company.currentCompanyId;
    if (uid == null || cid == null) {
      AppToast.error(context, 'Session ou entreprise indisponible.');
      return;
    }
    await PrinterAssociationStorage.save(
      userId: uid,
      companyId: cid,
      scope: _scope,
      thermalPrinterName: _thermalName,
      a4PrinterName: _a4Name,
    );
    if (!mounted) return;
    setState(() => _dirty = false);
    AppToast.success(context, 'Configuration enregistrée sur cet appareil.');
  }

  Printer? _resolvePrinter(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return findPrinterNamed(_printers, name.trim());
  }

  Future<void> _testThermal() async {
    final p = _resolvePrinter(_thermalName);
    if (p == null) {
      AppToast.error(context, 'Choisissez une imprimante pour le ticket caisse.');
      return;
    }
    try {
      await directPrintPdfBytes(
        printer: p,
        jobName: 'fasostock_test_ticket.pdf',
        buildBytes: buildThermalTestPdf,
      );
      if (mounted) AppToast.success(context, 'Test ticket envoyé.');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _testA4() async {
    final p = _resolvePrinter(_a4Name);
    if (p == null) {
      AppToast.error(context, 'Choisissez une imprimante pour la facture A4.');
      return;
    }
    try {
      await directPrintPdfBytes(
        printer: p,
        jobName: 'fasostock_test_facture_a4.pdf',
        buildBytes: buildA4TestPdf,
      );
      if (mounted) AppToast.success(context, 'Test facture A4 envoyé.');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final auth = context.watch<AuthProvider>();
    final company = context.watch<CompanyProvider>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (!permissions.hasLoaded || auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (permissions.isCashier) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(AppRoutes.sales);
        } catch (_) {}
      });
      return const SizedBox.shrink();
    }
    if (company.currentCompanyId != null &&
        !permissions.hasPermission(Permissions.settingsManage)) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Imprimantes')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Vous n’avez pas accès à cette section.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final names = _printers.map((e) => e.name).toList();

    return Scaffold(
      appBar: null,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 20,
          vertical: isWide ? 28 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Imprimantes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.settings),
              icon: const Icon(Icons.settings_rounded, size: 20),
              label: const Text('Paramètres'),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.print_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _loadingPrinters
                                ? 'Détection des imprimantes…'
                                : 'Imprimantes détectées (${_printers.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Actualiser',
                          onPressed: _loadingPrinters ? null : _refreshPrinters,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    if (_printerListError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _printerListError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                      ),
                    ],
                    if (!_loadingPrinters && names.isEmpty && _printerListError == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          kIsWeb
                              ? ''
                              : 'Aucune imprimante listée. Vérifiez les pilotes et réessayez.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (!_loadingPrinters && names.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: names.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final n = names[i];
                          final pr = _printers[i];
                          final def = pr.isDefault ? ' (par défaut)' : '';
                          return ListTile(
                            dense: true,
                            title: Text(n),
                            subtitle: Text('${pr.url}$def', maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enregistrer pour',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<PrinterStorageScope>(
                      title: const Text('Mon compte (recommandé)'),
                      value: PrinterStorageScope.user,
                      groupValue: _scope,
                      onChanged: (v) {
                        if (v == null) return;
                        unawaited(_loadSavedForScope(v));
                      },
                    ),
                    RadioListTile<PrinterStorageScope>(
                      title: const Text('Cet appareil (tous les utilisateurs)'),
                      value: PrinterStorageScope.device,
                      groupValue: _scope,
                      onChanged: (v) {
                        if (v == null) return;
                        unawaited(_loadSavedForScope(v));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final twoCol = c.maxWidth >= 720;
                final child = twoCol
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAssocCard(context, true, names)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildAssocCard(context, false, names)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildAssocCard(context, true, names),
                          const SizedBox(height: 16),
                          _buildAssocCard(context, false, names),
                        ],
                      );
                return child;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _dirty ? _save : null,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text('Enregistrer la configuration'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssocCard(
    BuildContext context,
    bool thermal,
    List<String> names,
  ) {
    final title = thermal ? 'Ticket caisse (thermique)' : 'Facture A4';
    final subtitle = thermal
        ? 'PDF 80 mm — même format que la caisse rapide.'
        : 'Documents format page.';
    final value = thermal ? _thermalName : _a4Name;
    final onTest = thermal ? _testThermal : _testA4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              decoration: const InputDecoration(
                labelText: 'Imprimante',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              value: value != null && names.contains(value) ? value : null,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Choisir —'),
                ),
                ...names.map(
                  (n) => DropdownMenuItem<String?>(value: n, child: Text(n)),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  if (thermal) {
                    _thermalName = v;
                  } else {
                    _a4Name = v;
                  }
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: names.isEmpty ? null : onTest,
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              label: const Text('Tester l’impression'),
            ),
          ],
        ),
      ),
    );
  }
}
