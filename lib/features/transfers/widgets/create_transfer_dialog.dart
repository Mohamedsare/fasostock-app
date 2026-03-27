import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/stock_cache_recovery.dart';
import '../../../data/models/stock_transfer.dart';
import '../../../data/models/store.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/transfers_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/offline_providers.dart';

class _LineRow {
  String productId = '';
  String productName = '';
  int quantityRequested = 0;
}

/// Dialog de création de transfert — boutique origine, boutique destination, lignes (produit + quantité).
/// Offline+sync : produits lus depuis le cache local (Drift) ; création transfert possible hors ligne.
class CreateTransferDialog extends ConsumerStatefulWidget {
  const CreateTransferDialog({
    super.key,
    required this.companyId,
    required this.stores,
    required this.onSuccess,
    this.initialFromStoreId,
    this.initialToStoreId,
    this.onOfflineSave,
    this.fromWarehouseSource = false,
    this.warehouseQuantities,
  });

  final String companyId;
  final List<Store> stores;
  final void Function(StockTransfer transfer) onSuccess;
  final String? initialFromStoreId;
  final String? initialToStoreId;

  /// Appelé quand la création API échoue : transfert local + payload pour enqueue (sync plus tard).
  final Future<void> Function(StockTransfer transfer, Map<String, dynamic> payload)?
  onOfflineSave;
  final bool fromWarehouseSource;
  final Map<String, int>? warehouseQuantities;

  @override
  ConsumerState<CreateTransferDialog> createState() =>
      _CreateTransferDialogState();
}

class _CreateTransferDialogState extends ConsumerState<CreateTransferDialog> {
  final TransfersRepository _repo = TransfersRepository();

  List<Store> get _stores => widget.stores;

  String? _fromStoreId;
  String? _toStoreId;
  List<_LineRow> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final storeIds = _stores.map((s) => s.id).toSet();
    _fromStoreId =
        widget.initialFromStoreId != null &&
            storeIds.contains(widget.initialFromStoreId)
        ? widget.initialFromStoreId
        : (_stores.isNotEmpty ? _stores.first.id : null);
    _toStoreId =
        widget.initialToStoreId != null &&
            storeIds.contains(widget.initialToStoreId)
        ? widget.initialToStoreId
        : (_stores.length > 1
              ? _stores[1].id
              : (_stores.isNotEmpty ? _stores.first.id : null));
    _lines = [_LineRow()];
  }

  void _addLine() => setState(() => _lines.add(_LineRow()));
  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index));
  }

  void _updateLineProduct(
    int index,
    String? productId,
    List<Product> products,
  ) {
    final id = productId ?? '';
    if (id.isEmpty) {
      setState(() {
        _lines[index].productId = '';
        _lines[index].productName = '';
        _lines[index].quantityRequested = 0;
      });
      return;
    }
    final p = products.cast<Product?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
    if (p != null) {
      setState(() {
        _lines[index].productId = p.id;
        _lines[index].productName = p.name;
      });
    }
  }

  void _updateLineQty(int index, int value) {
    setState(() => _lines[index].quantityRequested = value.clamp(0, 999999));
  }

  bool get _canSubmit {
    if (_toStoreId == null) return false;
    if (!widget.fromWarehouseSource &&
        (_fromStoreId == null || _fromStoreId == _toStoreId)) {
      return false;
    }
    return _lines.any((l) => l.productId.isNotEmpty && l.quantityRequested > 0);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      AppToast.info(
        context,
        'Choisissez deux boutiques différentes et au moins une ligne avec quantité > 0.',
      );
      return;
    }
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      AppToast.info(context, 'Session expirée. Reconnectez-vous.');
      return;
    }
    setState(() => _saving = true);
    try {
      final itemRows = _lines
          .where((l) => l.productId.isNotEmpty && l.quantityRequested > 0)
          .toList();
      final items = itemRows
          .map(
            (l) => CreateTransferItemInput(
              productId: l.productId,
              quantityRequested: l.quantityRequested,
            ),
          )
          .toList();
      if (items.isEmpty) {
        AppToast.info(
          context,
          'Ajoutez au moins une ligne avec produit et quantité.',
        );
        setState(() => _saving = false);
        return;
      }
      final stockByProduct = widget.fromWarehouseSource
          ? (widget.warehouseQuantities ?? <String, int>{})
          : await ref.read(appDatabaseProvider).getInventoryQuantities(_fromStoreId!);
      final stockProblems = <String>[];
      for (final l in itemRows) {
        final available = stockByProduct[l.productId] ?? 0;
        if (l.quantityRequested > available) {
          final name = l.productName.isNotEmpty ? l.productName : l.productId;
          stockProblems.add(
            '• $name : demandé ${l.quantityRequested}, disponible $available',
          );
        }
      }
      if (stockProblems.isNotEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Stock insuffisant')),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                'À la boutique d\'origine, le stock ne permet pas ce transfert :\n\n${stockProblems.join('\n')}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final input = CreateTransferInput(
        companyId: widget.companyId,
        fromStoreId: widget.fromWarehouseSource ? null : _fromStoreId!,
        toStoreId: _toStoreId!,
        fromWarehouse: widget.fromWarehouseSource,
        items: items,
      );
      final transfer = await _repo.create(input, userId);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop();
      AppToast.success(context, 'Transfert créé (brouillon)');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onSuccess(transfer),
      );
    } catch (e, st) {
      if (!mounted) return;
      final canOffline =
          widget.onOfflineSave != null && ErrorMapper.isNetworkError(e);
      if (canOffline) {
        final pendingId =
            'pending:${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(0x7fffffff)}';
        final now = DateTime.now().toUtc().toIso8601String();
        final itemInputs = _lines
            .where((l) => l.productId.isNotEmpty && l.quantityRequested > 0)
            .toList();
        final items = itemInputs
            .asMap()
            .entries
            .map(
              (e) => StockTransferItem(
                id: '$pendingId:${e.key}',
                transferId: pendingId,
                productId: e.value.productId,
                quantityRequested: e.value.quantityRequested,
                quantityShipped: 0,
                quantityReceived: 0,
                productName: null,
              ),
            )
            .toList();
        final pendingTransfer = StockTransfer(
          id: pendingId,
          companyId: widget.companyId,
          fromStoreId: widget.fromWarehouseSource ? '' : _fromStoreId!,
          toStoreId: _toStoreId!,
          fromWarehouse: widget.fromWarehouseSource,
          status: TransferStatus.draft,
          requestedBy: userId,
          approvedBy: null,
          shippedAt: null,
          receivedAt: null,
          receivedBy: null,
          createdAt: now,
          updatedAt: now,
          items: items,
        );
        final payload = {
          'local_id': pendingId,
          'company_id': widget.companyId,
          'from_store_id': widget.fromWarehouseSource ? null : _fromStoreId,
          'from_warehouse': widget.fromWarehouseSource,
          'to_store_id': _toStoreId,
          'requested_by': userId,
          'items': itemInputs
              .map(
                (l) => {
                  'product_id': l.productId,
                  'quantity_requested': l.quantityRequested,
                },
              )
              .toList(),
        };
        await widget.onOfflineSave!(pendingTransfer, payload);
        if (!mounted) return;
        setState(() => _saving = false);
        Navigator.of(context).pop();
        AppToast.success(
          context,
          'Transfert enregistré localement. Synchronisation à la reconnexion.',
        );
        AppErrorHandler.log(e, st);
      } else {
        if (shouldRecoverInventoryCachesFromRpcError(e)) {
          final fromId =
              widget.fromWarehouseSource ? null : _fromStoreId;
          recoverStoresAndWarehouseInventoryCachesAfterRpcError(
            ref,
            companyId: widget.companyId,
            storeId: fromId,
            secondStoreId: _toStoreId,
            runSync: () async {
              await ref.read(syncServiceV2Provider).sync(
                    userId: userId,
                    companyId: widget.companyId,
                    storeId: null,
                  );
            },
          );
        }
        AppErrorHandler.show(context, e, stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = Breakpoints.isNarrow(MediaQuery.sizeOf(context).width);
    final asyncProducts = ref.watch(productsStreamProvider(widget.companyId));
    final products = (asyncProducts.valueOrNull ?? [])
        .where(
          (p) => p.isActive &&
              (widget.fromWarehouseSource
                  ? p.canTransferFromDepotToStore
                  : true),
        )
        .toList();
    final productsLoading = asyncProducts.isLoading;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded),
          SizedBox(width: 10),
          Text('Nouveau transfert'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: narrow ? null : 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fromWarehouseSource)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Origine: dépôt magasin. Sélectionnez la boutique de destination.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (narrow) ...[
                if (!widget.fromWarehouseSource) _dropdownStore(theme, true),
                if (!widget.fromWarehouseSource) const SizedBox(height: 12),
                _dropdownStore(theme, false),
              ] else
                Row(
                  children: [
                    if (!widget.fromWarehouseSource)
                      Expanded(child: _dropdownStore(theme, true)),
                    if (!widget.fromWarehouseSource) const SizedBox(width: 12),
                    Expanded(child: _dropdownStore(theme, false)),
                  ],
                ),
              if (!widget.fromWarehouseSource &&
                  _fromStoreId != null &&
                  _toStoreId != null &&
                  _fromStoreId == _toStoreId)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Choisissez deux boutiques différentes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lignes', style: theme.textTheme.titleSmall),
                  if (productsLoading)
                    Text(
                      'Chargement…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ligne'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lines.length,
                  itemBuilder: (context, i) =>
                      _buildLineRow(theme, i, products),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_saving || !_canSubmit) ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer (brouillon)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownStore(ThemeData theme, bool isFrom) {
    final value = isFrom ? _fromStoreId : _toStoreId;
    final storeIds = _stores.map((s) => s.id).toSet();
    final validValue = value != null && storeIds.contains(value)
        ? value
        : (_stores.isNotEmpty ? _stores.first.id : null);

    return DropdownButtonFormField<String>(
      value: validValue,
      decoration: InputDecoration(
        labelText: isFrom
            ? 'Boutique d\'origine *'
            : 'Boutique de destination *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      isExpanded: true,
      menuMaxHeight: 300,
      items: _stores
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(s.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() {
        if (isFrom) {
          _fromStoreId = v;
        } else {
          _toStoreId = v;
        }
      }),
    );
  }

  void _openProductPicker(int index, List<Product> products) {
    final line = _lines[index];
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ProductPickerSheet(
        products: products,
        selectedProductId: line.productId.isEmpty ? null : line.productId,
        onSelect: (productId) {
          _updateLineProduct(index, productId, products);
          Navigator.of(ctx).pop();
        },
        maxHeight: isMobile ? screenHeight * 0.85 : screenHeight * 0.75,
        compactTiles: isMobile,
      ),
    );
  }

  Widget _buildLineRow(ThemeData theme, int index, List<Product> products) {
    final line = _lines[index];
    final displayName = line.productName.isNotEmpty
        ? line.productName
        : 'Produit';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _openProductPicker(index, products),
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                key: ValueKey('prod-$index-${line.productId}'),
                decoration: InputDecoration(
                  labelText: 'Produit',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                ),
                child: Text(
                  displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: line.productId.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: line.quantityRequested == 0
                  ? ''
                  : line.quantityRequested.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Qté',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _updateLineQty(index, int.tryParse(v) ?? 0),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: theme.colorScheme.error,
            ),
            onPressed: _lines.length > 1 ? () => _removeLine(index) : null,
            tooltip: 'Supprimer la ligne',
          ),
        ],
      ),
    );
  }
}

/// Feuille modale de sélection produit : recherche + liste (zones tactiles adaptées mobile).
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.selectedProductId,
    required this.onSelect,
    required this.maxHeight,
    this.compactTiles = false,
  });

  final List<Product> products;
  final String? selectedProductId;
  final void Function(String? productId) onSelect;
  final double maxHeight;

  /// Sur true : tuiles plus hautes (minTouchTarget) pour mobile.
  final bool compactTiles;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      if (p.sku != null && p.sku!.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredProducts();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                shrinkWrap: true,
                itemCount: filtered.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: widget.compactTiles ? 12 : 8,
                      ),
                      minVerticalPadding: widget.compactTiles ? 14 : 0,
                      leading: const Icon(Icons.clear_rounded),
                      title: const Text('Aucun produit'),
                      onTap: () => widget.onSelect(null),
                    );
                  }
                  final p = filtered[i - 1];
                  final selected = p.id == widget.selectedProductId;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: widget.compactTiles ? 12 : 8,
                    ),
                    minVerticalPadding: widget.compactTiles ? 14 : 0,
                    leading: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.inventory_2_outlined,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    title: Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    subtitle: p.sku != null && p.sku!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.sku!,
                              style: theme.textTheme.bodySmall,
                            ),
                          )
                        : null,
                    onTap: () => widget.onSelect(p.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
