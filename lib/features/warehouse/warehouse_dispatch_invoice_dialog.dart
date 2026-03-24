import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../shared/utils/format_currency.dart';

/// Bon / facture de sortie depuis le **dépôt** (stock magasin), indépendant des boutiques.
class WarehouseDispatchInvoiceDialog extends StatefulWidget {
  const WarehouseDispatchInvoiceDialog({
    super.key,
    required this.companyId,
    required this.products,
    required this.customers,
    required this.warehouseQuantities,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final List<Product> products;
  final List<Customer> customers;
  final Map<String, int> warehouseQuantities;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  State<WarehouseDispatchInvoiceDialog> createState() => _WarehouseDispatchInvoiceDialogState();
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

class _WarehouseDispatchInvoiceDialogState extends State<WarehouseDispatchInvoiceDialog> {
  Customer? _customer;
  final _notesCtrl = TextEditingController();
  final _lines = <_LineEditors>[_LineEditors()];
  bool _saving = false;
  String _filter = '';

  List<Product> get _activeProducts =>
      widget.products.where((p) => p.isActive && p.isAvailableInWarehouse).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
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

  Future<void> _submit() async {
    final inputs = <WarehouseDispatchLineInput>[];
    final seen = <String>{};
    for (final row in _lines) {
      final p = row.product;
      if (p == null) {
        AppToast.info(context, 'Choisissez un produit sur chaque ligne.');
        return;
      }
      if (seen.contains(p.id)) {
        AppToast.info(context, 'Chaque produit ne peut apparaître qu’une fois (regroupez les quantités).');
        return;
      }
      seen.add(p.id);
      final qty = int.tryParse(row.qtyCtrl.text.trim());
      if (qty == null || qty <= 0) {
        AppToast.info(context, 'Quantité invalide sur une ligne.');
        return;
      }
      final price = double.tryParse(row.priceCtrl.text.trim().replaceAll(',', '.'));
      if (price == null || price < 0) {
        AppToast.info(context, 'Prix unitaire invalide sur une ligne.');
        return;
      }
      final wh = widget.warehouseQuantities[p.id] ?? 0;
      if (qty > wh) {
        AppToast.info(context, 'Stock dépôt insuffisant pour « ${p.name} » (dispo: $wh).');
        return;
      }
      inputs.add(WarehouseDispatchLineInput(productId: p.id, quantity: qty, unitPrice: price));
    }

    setState(() => _saving = true);
    try {
      final res = await widget.warehouseRepo.createDispatchInvoice(
        companyId: widget.companyId,
        customerId: _customer?.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: inputs,
      );
      if (!mounted) return;
      AppToast.success(context, 'Bon enregistré : ${res.documentNumber}');
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e) {
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'customer_id': _customer?.id,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'lines': inputs.map((e) => e.toJson()).toList(),
        });
        if (mounted) {
          AppToast.success(context, 'Enregistré. Il sera envoyé dès la prochaine connexion.');
          Navigator.pop(context);
          await widget.onSuccess();
        }
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _activeProducts
        .where((p) {
          if (_filter.isEmpty) return true;
          final q = _filter.toLowerCase();
          return p.name.toLowerCase().contains(q) || (p.sku ?? '').toLowerCase().contains(q);
        })
        .take(400)
        .toList();

    return AlertDialog(
      title: const Text('Bon / facture — sortie dépôt'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Les articles sont prélevés sur votre dépôt. Un numéro de bon est créé automatiquement.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (widget.customers.isNotEmpty)
                DropdownButtonFormField<Customer?>(
                  initialValue: _customer,
                  decoration: const InputDecoration(labelText: 'Client (optionnel)'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<Customer?>(value: null, child: Text('— Aucun —')),
                    ...widget.customers.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _customer = v),
                ),
              if (widget.customers.isEmpty)
                Text(
                  'Aucun client en cache — vous pouvez enregistrer le bon sans client.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text('Lignes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filtrer les produits',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 8),
              ...List.generate(_lines.length, (i) {
                final row = _lines[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<Product>(
                                  initialValue: row.product != null && filtered.contains(row.product!)
                                      ? row.product
                                      : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Produit', isDense: true),
                                  items: filtered
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(
                                            '${p.name}${p.sku != null && p.sku!.isNotEmpty ? ' (${p.sku})' : ''}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => _onProductSelected(row, v),
                                ),
                              ),
                              if (_lines.length > 1)
                                IconButton(
                                  onPressed: _saving ? null : () => _removeLine(i),
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  tooltip: 'Retirer la ligne',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row.qtyCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Quantité',
                                    isDense: true,
                                    helperText: row.product != null
                                        ? 'Dispo dépôt : ${widget.warehouseQuantities[row.product!.id] ?? 0}'
                                        : null,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row.priceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Prix unitaire',
                                    suffixText: 'FCFA',
                                    isDense: true,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          if (row.product != null && row.priceCtrl.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Ligne : ${formatCurrency((double.tryParse(row.priceCtrl.text.replaceAll(',', '.')) ?? 0) * (int.tryParse(row.qtyCtrl.text) ?? 0))}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _saving ? null : _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter une ligne'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving || _activeProducts.isEmpty ? null : _submit,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Valider la sortie'),
        ),
      ],
    );
  }
}
