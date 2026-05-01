import 'package:flutter/material.dart';
import '../../../core/breakpoints.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/repositories/inventory_repository.dart';

enum _AdjustMode { delta, inventory }
enum _DeltaDirection { add, subtract }

/// Produit pour ajustement (même contrat que web AdjustStockDialog).
class AdjustStockProduct {
  const AdjustStockProduct({
    required this.id,
    required this.name,
    this.sku,
    this.imageUrl,
    required this.unit,
    required this.currentQty,
  });
  final String id;
  final String name;
  final String? sku;
  final String? imageUrl;
  final String unit;
  final int currentQty;
}

/// Callback pour enregistrer un ajustement hors ligne (Drift pending + mise à jour stock local).
typedef OnOfflineEnqueue = Future<void> Function({
  required String storeId,
  required String productId,
  required int delta,
  required String reason,
  required String userId,
  required int newQuantity,
});

/// Dialog d'ajustement de stock — variation (+/-) ou inventaire physique (aligné web).
/// Hors ligne : utilise [onOfflineEnqueue] (Drift) pour pending + mise à jour locale.
class AdjustStockDialog extends StatefulWidget {
  const AdjustStockDialog({
    super.key,
    required this.product,
    required this.storeId,
    required this.userId,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final AdjustStockProduct product;
  final String storeId;
  final String userId;
  final void Function(int newQuantity)? onSuccess;
  /// Requis pour le mode hors ligne (enqueue + mise à jour stock Drift).
  final OnOfflineEnqueue? onOfflineEnqueue;

  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final InventoryRepository _repo = InventoryRepository();
  _AdjustMode _mode = _AdjustMode.delta;
  _DeltaDirection _deltaDirection = _DeltaDirection.add;
  final TextEditingController _deltaController = TextEditingController();
  final TextEditingController _countedController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  int get _computedDelta {
    if (_mode == _AdjustMode.inventory) {
      final c = int.tryParse(_countedController.text);
      if (c != null && c >= 0) return c - widget.product.currentQty;
      return 0;
    }
    final quantity = int.tryParse(_deltaController.text);
    if (quantity == null || quantity <= 0) return 0;
    return _deltaDirection == _DeltaDirection.add ? quantity : -quantity;
  }

  bool get _needsAdjust => _computedDelta != 0;

  @override
  void initState() {
    super.initState();
    _reasonController.text = 'Ajustement manuel';
  }

  @override
  void dispose() {
    _deltaController.dispose();
    _countedController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_needsAdjust) {
      setState(() => _error = _mode == _AdjustMode.inventory
          ? 'Quantité comptée identique au stock actuel.'
          : 'Indiquez une variation ou une quantité comptée.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final reason = _reasonController.text.trim().isEmpty
        ? (_mode == _AdjustMode.inventory ? 'Inventaire' : 'Ajustement manuel')
        : _reasonController.text;
    final newQty = widget.product.currentQty + _computedDelta;
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      final onOffline = widget.onOfflineEnqueue;
      if (onOffline == null) {
        setState(() {
          _submitting = false;
          _error = 'Ajustement hors ligne non disponible. Connectez-vous puis réessayez.';
        });
        return;
      }
      try {
        await onOffline(
          storeId: widget.storeId,
          productId: widget.product.id,
          delta: _computedDelta,
          reason: reason,
          userId: widget.userId,
          newQuantity: newQty,
        );
        if (!mounted) return;
        widget.onSuccess?.call(newQty);
        Navigator.of(context).pop();
        AppToast.success(context, 'Ajustement enregistré localement. Synchronisation à la reconnexion.');
      } catch (e) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible d\'enregistrer l\'ajustement. Réessayez.');
          });
        }
      }
      return;
    }
    try {
      await _repo.adjust(
        widget.storeId,
        widget.product.id,
        _computedDelta,
        reason,
        widget.userId,
      );
      if (!mounted) return;
      widget.onSuccess?.call(newQty);
      Navigator.of(context).pop();
      AppToast.success(context, 'Stock mis à jour');
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = AppErrorHandler.toUserMessage(e);
        });
      }
    }
  }

  void _openImagePreview(BuildContext context, String imageUrl) {
    final screenW = MediaQuery.sizeOf(context).width;
    final previewSize = screenW >= 640 ? 170.0 : 140.0;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: previewSize,
                height: previewSize,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.inventory_2,
                    color: Theme.of(ctx).colorScheme.outline,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Ajuster le stock'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.product.imageUrl != null &&
                            widget.product.imageUrl!.isNotEmpty
                        ? Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openImagePreview(
                                context,
                                widget.product.imageUrl!,
                              ),
                              child: Image.network(
                                widget.product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.inventory_2_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Stock actuel: ${widget.product.currentQty} ${widget.product.unit}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_AdjustMode>(
              segments: [
                ButtonSegment(value: _AdjustMode.delta, label: const Text('Variation (+/-)'), icon: const Icon(Icons.add_circle_outline_rounded, size: 18)),
                ButtonSegment(value: _AdjustMode.inventory, label: const Text('Inventaire'), icon: const Icon(Icons.checklist_rounded, size: 18)),
              ],
              selected: {_mode},
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                minimumSize: WidgetStateProperty.all(const Size(0, Breakpoints.minTouchTarget)),
              ),
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  if (_mode == _AdjustMode.inventory) {
                    _reasonController.text = 'Inventaire';
                  } else {
                    _reasonController.text = 'Ajustement manuel';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (_mode == _AdjustMode.delta) ...[
              SegmentedButton<_DeltaDirection>(
                segments: const [
                  ButtonSegment(
                    value: _DeltaDirection.add,
                    label: Text('Ajouter'),
                    icon: Icon(Icons.add_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _DeltaDirection.subtract,
                    label: Text('Diminuer'),
                    icon: Icon(Icons.remove_rounded, size: 18),
                  ),
                ],
                selected: {_deltaDirection},
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  minimumSize: WidgetStateProperty.all(
                    const Size(0, Breakpoints.minTouchTarget),
                  ),
                ),
                onSelectionChanged: (s) {
                  setState(() {
                    _deltaDirection = s.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(
                _deltaDirection == _DeltaDirection.add
                    ? 'Quantité à ajouter au stock'
                    : 'Quantité à retirer du stock',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _deltaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ex: 10',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              Text('Quantité comptée (inventaire physique)', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _countedController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '${widget.product.currentQty}',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_computedDelta != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Correction : ${_computedDelta > 0 ? '+' : ''}$_computedDelta ${widget.product.unit}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text('Raison', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: _mode == _AdjustMode.inventory ? 'Inventaire' : 'Ex: Correction, perte',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(Breakpoints.minTouchTarget, Breakpoints.minTouchTarget)),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (_submitting || !_needsAdjust) ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget)),
          child: Text(_submitting ? 'Enregistrement...' : 'Valider'),
        ),
      ],
    );
  }
}
