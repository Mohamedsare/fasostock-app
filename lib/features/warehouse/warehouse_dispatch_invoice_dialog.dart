import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/local/drift/app_database.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/repositories/customers_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../shared/utils/format_currency.dart';
import '../pos_quick/pos_quick_constants.dart';
import 'warehouse_pos_quick_widgets.dart';
import 'warehouse_ui_helpers.dart';

/// Sortie du dépôt avec bon — interface très simple, **client / personne obligatoire**.
class WarehouseDispatchInvoiceDialog extends ConsumerStatefulWidget {
  const WarehouseDispatchInvoiceDialog({
    super.key,
    required this.companyId,
    required this.products,
    required this.warehouseQuantities,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final List<Product> products;
  final Map<String, int> warehouseQuantities;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  ConsumerState<WarehouseDispatchInvoiceDialog> createState() =>
      _WarehouseDispatchInvoiceDialogState();
}

class _LineEditors {
  _LineEditors()
      : qtyCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController();

  Product? product;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _WarehouseDispatchInvoiceDialogState extends ConsumerState<WarehouseDispatchInvoiceDialog> {
  final CustomersRepository _customersRepo = CustomersRepository();
  Customer? _customer;
  final _notesCtrl = TextEditingController();
  final _lines = <_LineEditors>[_LineEditors()];
  bool _saving = false;
  bool _creatingCustomer = false;
  String _productFilter = '';
  String _customerFilter = '';
  bool _searching = false;
  Timer? _searchDebounce;

  List<Product> get _activeProducts =>
      widget.products.where((p) => p.isActive && p.isAvailableInWarehouse).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Clients en direct depuis Drift (mis à jour après création).
  List<Customer> get _customers =>
      ref.watch(customersStreamProvider(widget.companyId)).valueOrNull ?? [];

  List<Customer> get _sortedCustomers {
    final list = List<Customer>.from(_customers);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _syncAfterCustomerChange() async {
    try {
      final auth = context.read<AuthProvider>();
      final company = context.read<CompanyProvider>();
      final uid = auth.user?.id;
      if (uid == null) return;
      await ref.read(syncServiceV2Provider).sync(
            userId: uid,
            companyId: company.currentCompanyId ?? widget.companyId,
            storeId: null,
          );
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_invoice_sync_after_customer', e, st);
    }
  }

  /// Formulaire court : nom + téléphone (comme la caisse).
  Future<void> _openCreateCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau client'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Renseignez au minimum le nom. Le téléphone aide à le retrouver.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex. : Amadou Diallo',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Au moins 2 lettres' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                    hintText: 'Facultatif',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (ok != true || !mounted) return;
    await _createCustomer(name: name, phone: phone);
  }

  Future<void> _createCustomer({required String name, String? phone}) async {
    setState(() => _creatingCustomer = true);
    try {
      final companyId = widget.companyId;
      final offlineRepo = ref.read(customersOfflineRepositoryProvider);
      final db = ref.read(appDatabaseProvider);
      final isOnline = ConnectivityService.instance.isOnline;

      if (!isOnline) {
        final localId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
        await db.enqueuePendingAction(
          'customer',
          jsonEncode({
            'local_id': localId,
            'company_id': companyId,
            'name': name,
            'type': CustomerType.individual.value,
            'phone': phone,
          }),
        );
        final now = DateTime.now().toUtc().toIso8601String();
        await db.upsertLocalCustomers([
          LocalCustomersCompanion.insert(
            id: 'pending:$localId',
            companyId: companyId,
            name: name,
            type: Value(CustomerType.individual.value),
            phone: Value(phone),
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        final pending = Customer(
          id: 'pending:$localId',
          companyId: companyId,
          name: name,
          type: CustomerType.individual,
          phone: phone,
        );
        if (!mounted) return;
        setState(() => _customer = pending);
        AppToast.success(context, 'Client enregistré. Il sera envoyé à la reconnexion.');
        Future.microtask(_syncAfterCustomerChange);
        return;
      }

      final created = await _customersRepo.create(
        CreateCustomerInput(
          companyId: companyId,
          name: name,
          type: CustomerType.individual,
          phone: phone,
        ),
      );
      await offlineRepo.upsertCustomer(created);
      if (!mounted) return;
      setState(() => _customer = created);
      AppToast.success(context, 'Client ajouté. Vous pouvez continuer le bon.');
      Future.microtask(_syncAfterCustomerChange);
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_invoice_create_customer', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _creatingCustomer = false);
    }
  }

  List<Customer> get _filteredCustomers {
    final list = _sortedCustomers;
    final q = _customerFilter.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      final p = c.phone ?? '';
      if (p.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  List<Product> _filteredProductsForDropdown(_LineEditors row) {
    final base = _activeProducts.where((p) {
      if (_productFilter.isEmpty) return true;
      final q = _productFilter.toLowerCase();
      return p.name.toLowerCase().contains(q) || (p.sku ?? '').toLowerCase().contains(q);
    }).take(400).toList();
    final sel = row.product;
    if (sel != null && !base.contains(sel)) {
      return [sel, ...base];
    }
    return base;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _productFilter = value.trim();
        _searching = false;
      });
    });
  }

  void _onProductSelected(_LineEditors row, Product? p) {
    setState(() {
      row.product = p;
      if (p != null && row.priceCtrl.text.isEmpty) {
        row.priceCtrl.text = p.salePrice.toString();
      }
    });
  }

  void _addLine() {
    setState(() => _lines.add(_LineEditors()));
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  double _lineTotal(_LineEditors row) {
    final q = int.tryParse(row.qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(row.priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    return q * price;
  }

  double get _grandTotal {
    var t = 0.0;
    for (final row in _lines) {
      t += _lineTotal(row);
    }
    return t;
  }

  /// Nouveau bon sans fermer le dialogue.
  void _resetDispatchForm() {
    for (final l in _lines) {
      l.dispose();
    }
    _lines
      ..clear()
      ..add(_LineEditors());
    _notesCtrl.clear();
    _customer = null;
    _productFilter = '';
    _customerFilter = '';
  }

  Future<void> _submit() async {
    if (_customer == null) {
      AppToast.info(
        context,
        'Choisissez d’abord la personne ou le client qui reçoit la marchandise.',
      );
      return;
    }
    final inputs = <WarehouseDispatchLineInput>[];
    final seen = <String>{};
    for (final row in _lines) {
      final p = row.product;
      if (p == null) {
        AppToast.info(context, 'Choisissez un article sur chaque ligne.');
        return;
      }
      if (seen.contains(p.id)) {
        AppToast.info(
          context,
          'Le même article est en double. Mettez la quantité sur une seule ligne.',
        );
        return;
      }
      seen.add(p.id);
      final qty = int.tryParse(row.qtyCtrl.text.trim());
      if (qty == null || qty <= 0) {
        AppToast.info(context, 'Indiquez une quantité correcte (nombre entier).');
        return;
      }
      final price = double.tryParse(row.priceCtrl.text.trim().replaceAll(',', '.'));
      if (price == null || price < 0) {
        AppToast.info(context, 'Indiquez un prix correct pour chaque article.');
        return;
      }
      final wh = widget.warehouseQuantities[p.id] ?? 0;
      if (qty > wh) {
        AppToast.info(
          context,
          'Pas assez de stock pour « ${p.name} ». Disponible : $wh.',
        );
        return;
      }
      inputs.add(WarehouseDispatchLineInput(productId: p.id, quantity: qty, unitPrice: price));
    }

    setState(() => _saving = true);
    try {
      final res = await widget.warehouseRepo.createDispatchInvoice(
        companyId: widget.companyId,
        customerId: _customer!.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: inputs,
      );
      if (!mounted) return;
      AppToast.success(context, 'Bon enregistré : ${res.documentNumber}');
      await widget.onSuccess();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _resetDispatchForm();
      });
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_invoice', e, st);
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'customer_id': _customer!.id,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'lines': inputs.map((e) => e.toJson()).toList(),
        });
        if (mounted) {
          AppToast.success(context, 'Enregistré. Envoi dès que la connexion revient.');
          await widget.onSuccess();
          if (!mounted) return;
          setState(() {
            _saving = false;
            _resetDispatchForm();
          });
        }
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCustomers = _customers.isNotEmpty;
    final canSubmit =
        !_saving && !_creatingCustomer && hasCustomers && _activeProducts.isNotEmpty;

    final maxH = MediaQuery.sizeOf(context).height * 0.94;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1100 : 560,
          maxHeight: maxH,
        ),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WarehousePosQuickHeader(
                title: 'Facture / sortie dépôt',
                subtitle: 'La marchandise quitte votre magasin (style caisse rapide)',
                closeEnabled: !_saving,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 62,
                            child: Container(
                              color: PosQuickColors.fondPrincipal,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: _dispatchStepsColumn(
                                  theme,
                                  scheme,
                                  hasCustomers,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 38,
                            child: Container(
                              color: PosQuickColors.fondSecondaire,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: Text(
                                      'Récapitulatif',
                                      style: TextStyle(
                                        color: PosQuickColors.textePrincipal,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  _dispatchFooterBar(hasCustomers, canSubmit),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: PosQuickColors.fondPrincipal,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: _dispatchStepsColumn(
                                  theme,
                                  scheme,
                                  hasCustomers,
                                ),
                              ),
                            ),
                          ),
                          _dispatchFooterBar(hasCustomers, canSubmit),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Étapes 1–3 (client, lignes, note) — réutilisé en mode étroit et dans la colonne gauche en mode large.
  Widget _dispatchStepsColumn(
    ThemeData theme,
    ColorScheme scheme,
    bool hasCustomers,
  ) {
    return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DispatchStepCard(
                        step: 1,
                        title: 'Qui reçoit la marchandise ?',
                        subtitle: 'Obligatoire — touchez le nom de la personne ou du client.',
                        accent: PosQuickColors.orangePrincipal,
                        icon: Icons.person_rounded,
                        child: !hasCustomers
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _EmptyCustomersHint(theme: theme),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: (_saving || _creatingCustomer)
                                        ? null
                                        : _openCreateCustomerDialog,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: const Color(0xFFF97316),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: _creatingCustomer
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.person_add_rounded),
                                    label: const Text(
                                      'Créer un client maintenant',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: (_saving || _creatingCustomer)
                                        ? null
                                        : _openCreateCustomerDialog,
                                    icon: _creatingCustomer
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.person_add_alt_1_rounded),
                                    label: const Text('Ajouter un nouveau client'),
                                    style: FilledButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    onChanged: (v) => setState(() => _customerFilter = v),
                                    decoration: warehousePosQuickSearchDecoration(
                                      hintText: 'Chercher par nom ou téléphone…',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 260),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: _filteredCustomers.length,
                                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                                      itemBuilder: (context, i) {
                                        final c = _filteredCustomers[i];
                                        final selected = _customer?.id == c.id;
                                        return Material(
                                          color: selected
                                              ? PosQuickColors.orangeClair.withValues(alpha: 0.45)
                                              : PosQuickColors.fondPrincipal,
                                          borderRadius: BorderRadius.circular(14),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(14),
                                            onTap: () => setState(() => _customer = c),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 14,
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 22,
                                                    backgroundColor: PosQuickColors.orangePrincipal
                                                        .withValues(alpha: 0.16),
                                                    child: const Icon(
                                                      Icons.person_rounded,
                                                      color: PosQuickColors.orangePrincipal,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          c.name,
                                                          style: theme.textTheme.titleSmall?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        if (c.phone != null &&
                                                            c.phone!.trim().isNotEmpty)
                                                          Text(
                                                            c.phone!,
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              color: scheme.onSurfaceVariant,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (selected)
                                                    const Icon(
                                                      Icons.check_circle_rounded,
                                                      color: PosQuickColors.orangePrincipal,
                                                      size: 26,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      _DispatchStepCard(
                        step: 2,
                        title: 'Quels articles sortent ?',
                        subtitle: 'Choisissez l’article, la quantité et le prix d’une unité.',
                        accent: PosQuickColors.orangePrincipal,
                        icon: Icons.inventory_2_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              decoration: warehousePosQuickSearchDecoration(
                                hintText: 'Chercher un article…',
                                suffixIcon: _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: _onSearchChanged,
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(_lines.length, (i) {
                              final row = _lines[i];
                              final filtered = _filteredProductsForDropdown(row);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: PosQuickColors.fondPrincipal,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: PosQuickColors.bordure,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            _StepNumberChip(
                                              label: '${i + 1}',
                                              color: PosQuickColors.orangePrincipal,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Article',
                                                style: theme.textTheme.labelLarge?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (_lines.length > 1)
                                              IconButton(
                                                onPressed: _saving ? null : () => _removeLine(i),
                                                icon: const Icon(Icons.delete_outline_rounded),
                                                tooltip: 'Retirer cette ligne',
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<Product>(
                                          key: ValueKey('dispatch_line_${i}_${row.product?.id}'),
                                          initialValue: row.product != null && filtered.contains(row.product!)
                                              ? row.product
                                              : null,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: scheme.surface,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            hintText: 'Sélectionner un article',
                                          ),
                                          items: filtered
                                              .map(
                                                (p) => DropdownMenuItem(
                                                  value: p,
                                                  child: Row(
                                                    children: [
                                                      _DispatchProductMiniThumb(product: p, size: 28),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          '${p.name}${p.sku != null && p.sku!.isNotEmpty ? ' (${p.sku})' : ''} · ${p.unit}',
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          selectedItemBuilder: (ctx) => filtered
                                              .map(
                                                (p) => Row(
                                                  children: [
                                                    _DispatchProductMiniThumb(product: p, size: 28),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${p.name}${p.sku != null && p.sku!.isNotEmpty ? ' (${p.sku})' : ''} · ${p.unit}',
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                          onChanged: _saving
                                              ? null
                                              : (v) => _onProductSelected(row, v),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: row.qtyCtrl,
                                                decoration: InputDecoration(
                                                  labelText: row.product != null
                                                      ? 'Quantité (${row.product!.unit})'
                                                      : 'Quantité',
                                                  helperText: row.product != null
                                                      ? 'En stock : ${widget.warehouseQuantities[row.product!.id] ?? 0} ${row.product!.unit}'
                                                      : null,
                                                  suffixText: row.product?.unit,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                ],
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller: row.priceCtrl,
                                                decoration: InputDecoration(
                                                  labelText: row.product != null
                                                      ? 'Prix pour 1 ${row.product!.unit}'
                                                      : 'Prix pour 1 unité',
                                                  suffixText: 'FCFA',
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                                  ),
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                                onChanged: (_) => setState(() {}),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (row.product != null && row.priceCtrl.text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              'Sous-total ligne (${row.product!.unit}) : ${formatCurrency(_lineTotal(row))}',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: PosQuickColors.orangePrincipal,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _addLine,
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              label: const Text('Ajouter un autre article'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: PosQuickColors.orangePrincipal,
                                side: const BorderSide(color: PosQuickColors.bordure),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DispatchStepCard(
                        step: 3,
                        title: 'Note (facultatif)',
                        subtitle: 'Exemple : motif de la sortie, nom sur place…',
                        accent: PosQuickColors.orangePrincipal,
                        icon: Icons.edit_note_rounded,
                        child: TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: warehousePosFormFieldDecoration(
                            labelText: 'Note (facultatif)',
                            hintText: 'Écrivez ici si besoin',
                          ),
                        ),
                      ),
                    ],
    );
  }

  Widget _dispatchFooterBar(
    bool hasCustomers,
    bool canSubmit,
  ) {
    return Material(
      elevation: 4,
      color: PosQuickColors.fondSecondaire,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: PosQuickColors.textePrincipal,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    formatCurrency(_grandTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: PosQuickColors.orangePrincipal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: PosQuickColors.orangePrincipal,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasCustomers
                            ? 'Enregistrer le bon de sortie'
                            : 'Ajoutez d’abord un client',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCustomersHint extends StatelessWidget {
  const _EmptyCustomersHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
          const SizedBox(height: 8),
          Text(
            'Aucun client enregistré pour l’instant.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Appuyez sur le bouton orange ci‑dessous pour créer un client tout de suite. Vous pouvez aussi aller dans le menu « Clients ».',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchStepCard extends StatelessWidget {
  const _DispatchStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.child,
  });

  final int step;
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosQuickColors.fondSecondaire,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosQuickColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StepNumberChip(label: '$step', color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: PosQuickColors.textePrincipal.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StepNumberChip extends StatelessWidget {
  const _StepNumberChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DispatchProductMiniThumb extends StatelessWidget {
  const _DispatchProductMiniThumb({required this.product, this.size = 24});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = (product.productImages != null && product.productImages!.isNotEmpty)
        ? product.productImages!.first.url
        : null;
    final radius = BorderRadius.circular(6);
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        alignment: Alignment.center,
        child: Icon(Icons.inventory_2_rounded, size: size * 0.62),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          alignment: Alignment.center,
          child: Icon(Icons.inventory_2_rounded, size: size * 0.62),
        ),
      ),
    );
  }
}
