import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/warehouse_stock_line.dart';
import '../../data/repositories/warehouse_repository.dart';
import 'warehouse_ui_helpers.dart';

/// Correction d'inventaire sur le stock **dépôt** (écart, casse, inventaire physique).
class WarehouseAdjustmentDialog extends StatefulWidget {
  const WarehouseAdjustmentDialog({
    super.key,
    required this.companyId,
    required this.line,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final WarehouseStockLine line;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  State<WarehouseAdjustmentDialog> createState() => _WarehouseAdjustmentDialogState();
}

class _WarehouseAdjustmentDialogState extends State<WarehouseAdjustmentDialog> {
  final _deltaCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _costCtrl.text = widget.line.purchasePrice > 0 ? widget.line.purchasePrice.toString() : '';
  }

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _costCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _deltaCtrl.text.trim();
    if (raw.isEmpty || raw == '-' || raw == '+') {
      AppToast.info(context, 'Indiquez une variation (+ ou − en unités).');
      return;
    }
    final normalized = raw.startsWith('+') ? raw.substring(1) : raw;
    final delta = int.tryParse(normalized);
    if (delta == null || delta == 0) {
      AppToast.info(context, 'Variation invalide (nombre entier, ex. -3 ou +10).');
      return;
    }
    double? unitCost;
    if (delta > 0) {
      unitCost = double.tryParse(_costCtrl.text.trim().replaceAll(',', '.'));
      if (unitCost == null || unitCost < 0) {
        AppToast.info(context, 'Indiquez un prix d’achat unitaire pour l’ajout en stock.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await widget.warehouseRepo.registerAdjustment(
        companyId: widget.companyId,
        productId: widget.line.productId,
        delta: delta,
        unitCost: delta > 0 ? unitCost : null,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      AppToast.success(context, 'Stock dépôt mis à jour.');
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e, st) {
      WarehouseUi.logOp('adjustment', e, st);
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'product_id': widget.line.productId,
          'delta': delta,
          if (delta > 0 && unitCost != null) 'unit_cost': unitCost,
          'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
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
    final l = widget.line;
    return AlertDialog(
      title: const Text('Ajuster le stock dépôt'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.productName,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'Stock actuel au dépôt : ${l.quantity} ${l.unit}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deltaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Variation (unités)',
                  hintText: 'Ex. -10 ou +25',
                  helperText: 'Nombre positif = ajout, négatif = retrait',
                ),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^[-+]?\d*$')),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _costCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prix d’achat unitaire (si ajout)',
                  suffixText: 'FCFA',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Appliquer'),
        ),
      ],
    );
  }
}
