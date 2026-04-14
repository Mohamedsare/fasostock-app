import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/breakpoints.dart';
import '../../../core/config/routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/utils/sale_pos_edit.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/stock_cache_recovery.dart';
import '../../../core/utils/user_country_time.dart';
import '../../../core/utils/client_request_id.dart';
import '../../../data/local/drift/app_database.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/pos_cart_settings_provider.dart';
import '../../../providers/sales_page_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../pos/services/receipt_thermal_print_service.dart';
import '../pos/widgets/receipt_ticket_dialog.dart';
import 'pos_quick_constants.dart';
import 'pos_quick_models.dart';
import 'widgets/barcode_scanner_dialog.dart';
import 'widgets/pos_quick_cart_tile.dart';
import 'widgets/pos_quick_left_zone.dart';
import 'widgets/pos_quick_right_zone.dart';

/// POS Caisse Rapide ? interface type alimentation/sup?rette, ticket thermique, offline+sync.
class PosQuickPage extends ConsumerStatefulWidget {
  const PosQuickPage({super.key, required this.storeId, this.editSaleId});

  final String storeId;

  /// Ouvre la caisse en chargeant une vente complétée à modifier (`?editSale=`).
  final String? editSaleId;

  @override
  ConsumerState<PosQuickPage> createState() => _PosQuickPageState();
}

class _PosQuickPageState extends ConsumerState<PosQuickPage> {
  final SalesRepository _salesRepo = SalesRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _amountReceivedController =
      TextEditingController();

  List<PosCartItem> _cart = [];
  final Map<String, TextEditingController> _qtyControllers = {};
  double _discount = 0;
  double _amountReceived = 0;
  bool _amountReceivedTouched = false;
  bool _creating = false;
  ReceiptTicketData? _receiptData;
  bool _syncTriggeredOnce = false;
  Timer? _periodicSyncTimer;
  DateTime? _lastStockLimitToastAt;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedCategoryId;
  Timer? _clockTimer;
  late final ValueNotifier<String> _clockLabel;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Modification vente : stock boutique affiché + quantités « rendues » par l’ancienne vente (avant enregistrement RPC).
  String? _activeEditSaleId;
  Map<String, int> _editStockRelease = {};
  bool _saleEditBootstrapping = false;
  String? _saleEditBarrierError;

  /// Sync toutes les 15 s tant que la caisse est ouverte ? nouveaux produits visibles tr?s vite (magasinier sur un autre poste).
  static const Duration _periodicSyncInterval = Duration(seconds: 15);

  int _effectiveStock(String productId, Map<String, int> stockByProductId) {
    final base = stockByProductId[productId] ?? 0;
    final release = _editStockRelease[productId] ?? 0;
    return base + release;
  }

  bool _isProductShownOnTill(Product p, Map<String, int> stockByProductId) {
    if (!p.isActive) return false;
    if (!p.isAvailableInBoutiqueStock) return false;
    return _effectiveStock(p.id, stockByProductId) > 0;
  }

  Product? _productById(String productId) {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null || companyId.isEmpty) return null;
    final list =
        ref.read(productsStreamProvider(companyId)).valueOrNull ?? const [];
    try {
      return list.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  double _catalogUnitPrice(String productId, int qty) {
    final p = _productById(productId);
    if (p == null) return 0;
    return p.unitPriceForCartQuantity(qty);
  }

  @override
  void initState() {
    super.initState();
    final ep = widget.editSaleId?.trim() ?? '';
    if (ep.isNotEmpty) _saleEditBootstrapping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<CompanyProvider>().setCurrentStoreId(widget.storeId);
      if (ep.isNotEmpty) await _bootstrapSaleEdit();
    });
    _clockLabel = ValueNotifier<String>(
      formatDeviceWallClockHm(DateTime.now()),
    );
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final t = formatDeviceWallClockHm(DateTime.now());
      if (t != _clockLabel.value) _clockLabel.value = t;
    });
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (!mounted) return;
      Future.microtask(() => _refreshSync());
    });
    _connectivitySubscription = ConnectivityService
        .instance
        .onConnectivityChanged
        .listen((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _clockLabel.dispose();
    _clockTimer?.cancel();
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    _discountController.dispose();
    _amountReceivedController.dispose();
    _clearQtyControllers();
    super.dispose();
  }

  void _clearQtyControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _qtyControllers.clear();
  }

  Future<void> _refreshSync() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid != null) {
      try {
        await ref
            .read(syncServiceV2Provider)
            .sync(
              userId: uid,
              companyId: company.currentCompanyId,
              storeId: widget.storeId,
            );
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'pos_quick',
          logContext: const {'op': 'sync'},
        );
      }
    }
  }

  /// Filtre recherche / catégorie ; produits boutique actifs avec stock effectif > 0.
  List<Product> _filteredProducts(
    List<Product> products,
    Map<String, int> stockByProductId,
  ) {
    final search = _searchController.text.trim().toLowerCase();
    return products.where((p) {
      if (!_isProductShownOnTill(p, stockByProductId)) return false;
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (search.isEmpty) return true;
      if (p.name.toLowerCase().contains(search)) return true;
      if (p.sku?.toLowerCase().contains(search) ?? false) return true;
      if (p.barcode?.contains(search) ?? false) return true;
      return false;
    }).toList();
  }

  double get _subtotal => PosQuickCartLogic.subtotal(_cart);
  double get _total => PosQuickCartLogic.totalWithDiscount(_cart, _discount);
  bool get _canPay => PosQuickCartLogic.canPay(_cart, _total);
  int get _cartItemCount => _cart.fold(0, (n, c) => n + c.quantity);

  List<PosCartItem> _stockWarnings(Map<String, int> stockByProductId) => _cart
      .where((c) => _effectiveStock(c.productId, stockByProductId) < c.quantity)
      .toList();

  void _addToCart(Product p, Map<String, int> stockByProductId) {
    final stock = _effectiveStock(p.id, stockByProductId);
    setState(() {
      PosCartItem? existing;
      try {
        existing = _cart.firstWhere((c) => c.productId == p.id);
      } catch (_) {
        existing = null;
      }
      if (existing != null) {
        final newQty = existing.quantity + 1;
        if (stock >= 0 && newQty > stock) {
          _showStockLimitToast();
          return;
        }
        existing.quantity = newQty;
        if (!existing.linePriceUserSet) {
          existing.unitPrice = p.unitPriceForCartQuantity(newQty);
        }
        existing.total = newQty * existing.unitPrice;
        final pid = existing.productId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _qtyControllers[pid]?.text = newQty == 0 ? '' : newQty.toString();
        });
      } else {
        if (stock <= 0) return;
        final pu = p.unitPriceForCartQuantity(1);
        _cart.add(
          PosCartItem(
            productId: p.id,
            name: p.name,
            sku: p.sku,
            unit: p.unit,
            quantity: 1,
            unitPrice: pu,
            total: pu,
            imageUrl: p.productImages?.isNotEmpty == true
                ? p.productImages!.first.url
                : null,
          ),
        );
      }
    });
  }

  void _updateQty(
    String productId,
    int delta,
    Map<String, int> stockByProductId,
  ) {
    final stock = _effectiveStock(productId, stockByProductId);
    int? newQty;
    setState(() {
      final beforeLen = _cart.length;
      _cart = _cart
          .map((c) {
            if (c.productId != productId) return c;
            final q = (c.quantity + delta).clamp(0, 999);
            if (stock >= 0 && q > stock) {
              _showStockLimitToast();
              return c;
            }
            newQty = q;
            c.quantity = q;
            if (!c.linePriceUserSet) {
              c.unitPrice = _catalogUnitPrice(productId, q);
            }
            c.total = q * c.unitPrice;
            return c;
          })
          .where((c) => c.quantity > 0)
          .toList();
      if (_cart.length < beforeLen && _qtyControllers.containsKey(productId)) {
        _qtyControllers[productId]?.dispose();
        _qtyControllers.remove(productId);
      }
    });
    // Aligner le champ après +/- même si le focus est encore sur le TextField
    // (PosCartQtyField n’écrase pas le texte tant que le champ a le focus).
    if (newQty != null && _qtyControllers.containsKey(productId)) {
      _qtyControllers[productId]!.text = newQty == 0 ? '' : newQty.toString();
    }
  }

  void _setQty(String productId, int value, Map<String, int> stockByProductId) {
    final stock = _effectiveStock(productId, stockByProductId);
    PosCartItem? current;
    try {
      current = _cart.firstWhere((c) => c.productId == productId);
    } catch (_) {
      current = null;
    }
    if (current == null) return;

    final requested = value.clamp(0, 999);
    if (stock >= 0 && requested > stock) {
      _showStockLimitToast();
      _qtyControllers[productId]?.text = current.quantity == 0
          ? ''
          : current.quantity.toString();
      return;
    }

    final clamped = requested;
    setState(() {
      _cart = _cart.map((c) {
        if (c.productId != productId) return c;
        c.quantity = clamped;
        if (!c.linePriceUserSet) {
          c.unitPrice = _catalogUnitPrice(productId, clamped);
        }
        c.total = clamped * c.unitPrice;
        return c;
      }).toList();
    });
  }

  void _removeCartLine(String productId) {
    setState(() {
      _cart = _cart.where((c) => c.productId != productId).toList();
      _qtyControllers[productId]?.dispose();
      _qtyControllers.remove(productId);
    });
  }

  void _showStockLimitToast() {
    final now = DateTime.now();
    final last = _lastStockLimitToastAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastStockLimitToastAt = now;
    AppToast.info(context, 'Quantité ajustée au stock disponible.');
  }

  List<CreateSalePaymentInput> _buildPayments() {
    return [CreateSalePaymentInput(method: _paymentMethod, amount: _total)];
  }

  List<CreateSaleItemInput> _cartToSaleItems() {
    return _cart
        .map(
          (c) => CreateSaleItemInput(
            productId: c.productId,
            quantity: c.quantity,
            unitPrice: c.unitPrice,
            discount: (c.quantity * c.unitPrice - c.total).clamp(
              0.0,
              double.infinity,
            ),
          ),
        )
        .toList();
  }

  Future<void> _bootstrapSaleEdit() async {
    final rawId = widget.editSaleId?.trim() ?? '';
    if (rawId.isEmpty || !mounted) return;
    if (!context.read<PermissionsProvider>().hasPermission(
      Permissions.salesUpdate,
    )) {
      setState(() {
        _saleEditBarrierError =
            'Vous n\'avez pas la permission de modifier des ventes.';
        _saleEditBootstrapping = false;
      });
      return;
    }
    setState(() {
      _saleEditBootstrapping = true;
      _saleEditBarrierError = null;
    });
    try {
      final sale = await _salesRepo.get(rawId);
      if (!mounted) return;
      if (sale == null) {
        setState(() {
          _saleEditBarrierError = 'Vente introuvable.';
          _saleEditBootstrapping = false;
        });
        return;
      }
      if (sale.storeId != widget.storeId) {
        setState(() {
          _saleEditBarrierError =
              'Cette vente appartient à une autre boutique.';
          _saleEditBootstrapping = false;
        });
        return;
      }
      if (sale.status != SaleStatus.completed) {
        setState(() {
          _saleEditBarrierError =
              'Seules les ventes complétées peuvent être modifiées.';
          _saleEditBootstrapping = false;
        });
        return;
      }
      if (saleOpensOnInvoicePosScreen(sale)) {
        if (!mounted) return;
        context.go('${AppRoutes.pos(sale.storeId)}?${saleEditQuery(sale.id)}');
        return;
      }
      final items = sale.saleItems ?? await _salesRepo.getItems(sale.id);
      final payments =
          sale.salePayments ?? await _salesRepo.getPayments(sale.id);
      if (!mounted) return;
      final release = <String, int>{};
      final cart = <PosCartItem>[];
      for (final item in items) {
        release[item.productId] =
            (release[item.productId] ?? 0) + item.quantity;
        cart.add(
          PosCartItem(
            productId: item.productId,
            name: item.product?.name ?? 'Produit',
            sku: item.product?.sku,
            unit: item.product?.unit ?? 'pce',
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            total: item.total,
            imageUrl: null,
            linePriceUserSet: true,
          ),
        );
      }
      _clearQtyControllers();
      setState(() {
        _editStockRelease = release;
        _cart = cart;
        _activeEditSaleId = sale.id;
        _discount = sale.discount;
        _discountController.text = sale.discount > 0 ? '${sale.discount}' : '';
        if (payments.isNotEmpty) {
          _paymentMethod = payments.first.method;
          final sum = payments.fold<double>(0, (s, p) => s + p.amount);
          _amountReceivedTouched = true;
          _amountReceived = sum;
          _amountReceivedController.text = sum > 0 ? '$sum' : '';
        }
        _saleEditBootstrapping = false;
      });
      for (final c in _cart) {
        _qtyControllers[c.productId] = TextEditingController(
          text: c.quantity == 0 ? '' : '${c.quantity}',
        );
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'pos_quick',
        logContext: const {'op': 'bootstrap_sale_edit'},
      );
      if (!mounted) return;
      setState(() {
        _saleEditBarrierError = AppErrorHandler.toUserMessage(e);
        _saleEditBootstrapping = false;
      });
    }
  }

  Future<void> _persistLocalAfterSaleUpdate(Sale updated) async {
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now().toIso8601String();
    final items = updated.saleItems ?? await _salesRepo.getItems(updated.id);
    await db.upsertLocalSale(
      LocalSalesCompanion.insert(
        id: updated.id,
        companyId: updated.companyId,
        storeId: updated.storeId,
        customerId: drift.Value(updated.customerId),
        saleNumber: updated.saleNumber,
        status: updated.status.value,
        subtotal: drift.Value(updated.subtotal),
        discount: drift.Value(updated.discount),
        tax: drift.Value(updated.tax),
        total: updated.total,
        createdBy: updated.createdBy,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        saleMode: drift.Value(updated.saleMode?.value),
        documentType: drift.Value(updated.documentType?.value),
        synced: const drift.Value(true),
      ),
    );
    await db.deleteLocalSaleItemsBySaleId(updated.id);
    if (items.isNotEmpty) {
      await db.upsertLocalSaleItems(
        items.map(
          (i) => LocalSaleItemsCompanion.insert(
            id: i.id,
            saleId: i.saleId,
            productId: i.productId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            total: i.total,
            createdAt: now,
          ),
        ),
      );
    }
  }

  Future<void> _afterSaleEditSuccess(Sale sale) async {
    // Capturer le router tout de suite : après les await le widget peut être démonté
    // et `context.go` ne serait plus appelé → écran « Ouverture de la vente… » bloqué.
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    final storeId = widget.storeId;
    final companyId = context.read<CompanyProvider>().currentCompanyId;

    context.read<CompanyProvider>().setCurrentStoreId(storeId);
    context.read<SalesPageProvider>().setFilters(storeId: storeId);
    context.read<SalesPageProvider>().invalidate();
    AppToast.success(context, 'Vente #${sale.saleNumber} mise à jour.');

    if (companyId != null) {
      try {
        await ref.read(salesOfflineRepositoryProvider).upsertSale(sale);
      } catch (e2, st2) {
        AppErrorHandler.logWithContext(
          e2,
          stackTrace: st2,
          logSource: 'pos_quick',
          logContext: const {'op': 'cache_sale_after_update'},
        );
      }
      ref.invalidate(
        salesStreamProvider((companyId: companyId, storeId: storeId)),
      );
    }
    await ref.read(syncServiceV2Provider).pullInventoryQuantitiesForStores([
      storeId,
    ]);
    ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
    try {
      await _persistLocalAfterSaleUpdate(sale);
    } catch (e3, st3) {
      AppErrorHandler.logWithContext(
        e3,
        stackTrace: st3,
        logSource: 'pos_quick',
        logContext: const {'op': 'persist_local_after_sale_update'},
      );
    }

    router.go(AppRoutes.sales);
  }

  Future<void> _handlePayment(
    Store? store,
    Map<String, int> stockByProductId,
  ) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final userId = context.read<AuthProvider>().user?.id;
    if (companyId == null || userId == null || store == null || !_canPay) {
      return;
    }
    if (_stockWarnings(stockByProductId).isNotEmpty) {
      AppToast.error(context, 'Stock insuffisant pour certains articles.');
      return;
    }
    if (_paymentMethod == PaymentMethod.cash &&
        _amountReceivedTouched &&
        _amountReceived < _total) {
      AppToast.error(context, 'Montant reçu insuffisant.');
      return;
    }
    if (_cart.any((c) => c.quantity <= 0)) {
      AppToast.error(
        context,
        'Indiquez une quantité supérieure à 0 pour chaque ligne du panier.',
      );
      return;
    }

    if (_activeEditSaleId != null) {
      if (!ConnectivityService.instance.isOnline) {
        AppToast.error(
          context,
          'La modification nécessite une connexion internet.',
        );
        return;
      }
      setState(() => _creating = true);
      try {
        await _salesRepo.updateCompleted(
          saleId: _activeEditSaleId!,
          customerId: null,
          items: _cartToSaleItems(),
          payments: _buildPayments(),
          discount: _discount,
          saleMode: SaleMode.quickPos,
          documentType: DocumentType.thermalReceipt,
        );
        final sale = await _salesRepo.get(_activeEditSaleId!);
        if (sale == null) {
          throw Exception('Vente introuvable après mise à jour');
        }
        await _afterSaleEditSuccess(sale);
      } catch (e, st) {
        if (mounted) {
          if (shouldRecoverInventoryCachesFromRpcError(e)) {
            recoverStoreInventoryCacheAfterRpcError(
              ref,
              widget.storeId,
              _refreshSync,
            );
          }
          AppErrorHandler.show(
            context,
            e,
            stackTrace: st,
            logSource: 'pos_quick',
            logContext: const {'op': 'update_sale'},
          );
        }
      } finally {
        if (mounted) setState(() => _creating = false);
      }
      return;
    }

    final isOnline = ConnectivityService.instance.isOnline;
    setState(() => _creating = true);

    Future<void> saveOfflineAndShowReceipt(
      List<CreateSalePaymentInput> payments, {
      required String successMessage,
    }) async {
      final localId = 'sale_${DateTime.now().millisecondsSinceEpoch}';
      final pendingSaleId = 'pending:$localId';
      final now = DateTime.now();
      final isoNow = now.toUtc().toIso8601String();

      final payload = {
        'p_company_id': companyId,
        'p_store_id': widget.storeId,
        'p_customer_id': null,
        'p_created_by': userId,
        'p_items': _cart
            .map(
              (c) => {
                'product_id': c.productId,
                'quantity': c.quantity,
                'unit_price': c.unitPrice,
                'discount': 0,
              },
            )
            .toList(),
        'p_payments': payments
            .map(
              (p) => {
                'method': p.method.value,
                'amount': p.amount,
                'reference': p.reference,
              },
            )
            .toList(),
        'p_discount': _discount,
        'p_sale_mode': SaleMode.quickPos.value,
        'p_document_type': DocumentType.thermalReceipt.value,
        'p_client_request_id': newClientRequestId(),
      };

      final db = ref.read(appDatabaseProvider);
      await db.enqueuePendingAction(
        'sale',
        jsonEncode({'local_id': localId, 'rpc': payload}),
      );

      await db.upsertLocalSale(
        LocalSalesCompanion.insert(
          id: pendingSaleId,
          companyId: companyId,
          storeId: widget.storeId,
          customerId: const drift.Value(null),
          saleNumber: '— (hors ligne)',
          status: 'completed',
          subtotal: drift.Value(_subtotal),
          discount: drift.Value(_discount),
          tax: const drift.Value(0),
          total: _total,
          createdBy: userId,
          createdAt: isoNow,
          updatedAt: isoNow,
          synced: const drift.Value(false),
          saleMode: drift.Value(SaleMode.quickPos.value),
          documentType: drift.Value(DocumentType.thermalReceipt.value),
        ),
      );
      await db.upsertLocalSaleItems(
        _cart.map(
          (c) => LocalSaleItemsCompanion.insert(
            id: 'pending_item_${pendingSaleId}_${c.productId}',
            saleId: pendingSaleId,
            productId: c.productId,
            quantity: c.quantity,
            unitPrice: c.unitPrice,
            total: c.total,
            createdAt: isoNow,
          ),
        ),
      );

      for (final c in _cart) {
        final current = stockByProductId[c.productId] ?? 0;
        final newQty = (current - c.quantity).clamp(0, 0x7FFFFFFF);
        await db.upsertInventory(widget.storeId, c.productId, newQty, isoNow);
      }

      if (!mounted) return;
      ref.invalidate(inventoryQuantitiesStreamProvider(widget.storeId));
      final cashierName =
          context.read<AuthProvider>().profile?.fullName ??
          context.read<AuthProvider>().user?.email ??
          '—';
      final qrSite = await ref
          .read(appDatabaseProvider)
          .getPublicWebsiteUrl(companyId);
      if (!mounted) return;
      final receipt = ReceiptTicketData(
        storeName: store.name,
        storeLogoUrl: store.logoUrl,
        storeAddress: store.address,
        storePhone: store.phone,
        saleNumber: '— (hors ligne)',
        saleId: pendingSaleId,
        cashierName: cashierName,
        qrCompanyWebsiteUrl: qrSite,
        items: _cart
            .map(
              (c) => ReceiptItemData(
                name: c.name,
                quantity: c.quantity,
                unitPrice: c.unitPrice,
                total: c.total,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        discount: _discount,
        total: _total,
        paymentMethod: _paymentMethod == PaymentMethod.cash
            ? 'Espèces'
            : (_paymentMethod == PaymentMethod.card ? 'Carte' : 'Mobile money'),
        amountReceived:
            _paymentMethod == PaymentMethod.cash &&
                _amountReceivedTouched &&
                _amountReceived > 0
            ? _amountReceived
            : null,
        change:
            _paymentMethod == PaymentMethod.cash && _amountReceived >= _total
            ? _amountReceived - _total
            : null,
      );
      setState(() {
        _cart = [];
        _discount = 0;
        _amountReceived = 0;
        _amountReceivedTouched = false;
        _creating = false;
        _receiptData = receipt;
      });
      _clearQtyControllers();
      _discountController.clear();
      _amountReceivedController.clear();
      if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showReceiptIfNeeded(),
      );
      Future.microtask(() => _refreshSync());
      AppToast.success(context, successMessage);
    }

    try {
      final payments = _buildPayments();
      if (!isOnline) {
        try {
          await saveOfflineAndShowReceipt(
            payments,
            successMessage:
                'Vente enregistrée localement. Synchronisation à la reconnexion.',
          );
          return;
        } catch (e, st) {
          if (!mounted) return;
          setState(() => _creating = false);
          AppErrorHandler.show(
            context,
            e,
            fallback: 'Impossible d\'enregistrer la vente. Réessayez.',
            stackTrace: st,
            logSource: 'pos_quick',
            logContext: const {'op': 'offline_sale'},
          );
          return;
        }
      }
      final sale = await _salesRepo.create(
        CreateSaleInput(
          companyId: companyId,
          storeId: widget.storeId,
          customerId: null,
          items: _cart
              .map(
                (c) => CreateSaleItemInput(
                  productId: c.productId,
                  quantity: c.quantity,
                  unitPrice: c.unitPrice,
                  discount: 0,
                ),
              )
              .toList(),
          discount: _discount,
          payments: payments,
          saleMode: SaleMode.quickPos,
          documentType: DocumentType.thermalReceipt,
        ),
        userId,
      );
      if (!mounted) return;
      try {
        await ref.read(salesOfflineRepositoryProvider).upsertSale(sale);
      } catch (e2, st2) {
        AppErrorHandler.logWithContext(
          e2,
          stackTrace: st2,
          logSource: 'pos_quick',
          logContext: const {'op': 'cache_sale_after_create'},
        );
        // Vente d?j? cr??e c?t? serveur ; on continue pour afficher le ticket
      }
      if (!mounted) return;
      ref.invalidate(
        salesStreamProvider((companyId: companyId, storeId: widget.storeId)),
      );
      final cashierName =
          context.read<AuthProvider>().profile?.fullName ??
          context.read<AuthProvider>().user?.email ??
          '—';
      final qrSite = await ref
          .read(appDatabaseProvider)
          .getPublicWebsiteUrl(companyId);
      if (!mounted) return;
      final receipt = ReceiptTicketData(
        storeName: store.name,
        storeLogoUrl: store.logoUrl,
        storeAddress: store.address,
        storePhone: store.phone,
        saleNumber: sale.saleNumber,
        saleId: sale.id,
        cashierName: cashierName,
        qrCompanyWebsiteUrl: qrSite,
        items: _cart
            .map(
              (c) => ReceiptItemData(
                name: c.name,
                quantity: c.quantity,
                unitPrice: c.unitPrice,
                total: c.total,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        discount: _discount,
        total: _total,
        paymentMethod: _paymentMethod == PaymentMethod.cash
            ? 'Espèces'
            : (_paymentMethod == PaymentMethod.card ? 'Carte' : 'Mobile money'),
        amountReceived:
            _paymentMethod == PaymentMethod.cash &&
                _amountReceivedTouched &&
                _amountReceived > 0
            ? _amountReceived
            : null,
        change:
            _paymentMethod == PaymentMethod.cash && _amountReceived >= _total
            ? _amountReceived - _total
            : null,
      );
      setState(() {
        _cart = [];
        _discount = 0;
        _amountReceived = 0;
        _amountReceivedTouched = false;
        _creating = false;
        _receiptData = receipt;
      });
      _clearQtyControllers();
      _discountController.clear();
      _amountReceivedController.clear();
      if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showReceiptIfNeeded(),
      );
      AppToast.success(
        context,
        'Vente #${sale.saleNumber} enregistrée. Total: ${formatCurrency(sale.total)}',
      );
    } catch (e, st) {
      if (!mounted) return;
      if (ErrorMapper.isNetworkError(e)) {
        try {
          await saveOfflineAndShowReceipt(
            _buildPayments(),
            successMessage:
                'Connexion perdue. Vente enregistrée localement. Synchronisation à la reconnexion.',
          );
          return;
        } catch (e2, st2) {
          if (!mounted) return;
          setState(() => _creating = false);
          AppErrorHandler.show(
            context,
            e2,
            fallback: 'Impossible d\'enregistrer la vente en local. Réessayez.',
            stackTrace: st2,
            logSource: 'pos_quick',
            logContext: const {'op': 'offline_sale_after_network_error'},
          );
          return;
        }
      } else {
        if (shouldRecoverInventoryCachesFromRpcError(e)) {
          recoverStoreInventoryCacheAfterRpcError(
            ref,
            widget.storeId,
            _refreshSync,
          );
        }
        setState(() => _creating = false);
        AppErrorHandler.show(
          context,
          e,
          stackTrace: st,
          logSource: 'pos_quick',
          logContext: const {'op': 'create_sale'},
        );
      }
    }
  }

  void _showReceiptIfNeeded() {
    final data = _receiptData;
    if (data == null || !mounted || !context.mounted) return;
    final uid = context.read<AuthProvider>().user?.id;
    final cid = context.read<CompanyProvider>().currentCompanyId;
    final posSettings = context.read<PosCartSettingsProvider>();
    if (posSettings.posQuickAutoPrint) {
      final ticket = data;
      setState(() => _receiptData = null);
      unawaited(
        ReceiptThermalPrintService.printReceipt(
          ticket,
          userId: uid,
          companyId: cid,
        )
            .then((_) {
              if (mounted) {
                AppToast.success(context, 'Ticket envoyé à l\'imprimante.');
              }
            })
            .catchError((Object e, StackTrace st) {
              if (mounted) {
                AppErrorHandler.show(
                  context,
                  e,
                  fallback:
                      'Impossible d\'imprimer le ticket. Vérifiez l\'imprimante.',
                  stackTrace: st,
                  logSource: 'pos_quick',
                  logContext: const {'op': 'thermal_print_auto'},
                );
              }
            }),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => ReceiptTicketDialog(
        data: data,
        // Sync + unawaited : l’impression ne bloque ni le dialog ni la caisse.
        onPrint: () {
          if (dialogCtx.mounted) {
            Navigator.of(dialogCtx).pop();
          }
          if (mounted) {
            AppToast.info(context, 'Impression en cours...');
          }
          unawaited(
            ReceiptThermalPrintService.printReceipt(
              data,
              userId: uid,
              companyId: cid,
            )
                .then((_) {
                  if (mounted) {
                    AppToast.success(context, 'Ticket envoyé à l\'imprimante.');
                  }
                })
                .catchError((Object e, StackTrace st) {
                  if (mounted) {
                    AppErrorHandler.show(
                      context,
                      e,
                      fallback: 'Impossible d\'imprimer le ticket.',
                      stackTrace: st,
                      logSource: 'pos_quick',
                      logContext: const {'op': 'thermal_print_dialog'},
                    );
                  }
                }),
          );
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _receiptData = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    final permissions = context.watch<PermissionsProvider>();
    if (!permissions.hasLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caisse rapide')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final saleEditParam = widget.editSaleId?.trim() ?? '';
    final isSaleEditEntry = saleEditParam.isNotEmpty;
    if (!isSaleEditEntry &&
        !permissions.hasPermission(Permissions.salesCreate)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caisse rapide')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "Vous n'avez pas l'autorisation d'effectuer des ventes (caisse rapide).",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.stores),
                  icon: const Icon(Icons.list_rounded),
                  label: const Text('Retour aux boutiques'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isSaleEditEntry) {
      if (!permissions.hasPermission(Permissions.salesUpdate)) {
        return Scaffold(
          appBar: AppBar(title: const Text('Caisse rapide')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Vous n'avez pas la permission de modifier des ventes.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.sales),
                    icon: const Icon(Icons.list_rounded),
                    label: const Text('Retour aux ventes'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (_saleEditBarrierError != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Modifier une vente')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _saleEditBarrierError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.sales),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Retour aux ventes'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (_saleEditBootstrapping || _activeEditSaleId == null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Ouverture de la vente en caisse…',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final productsAsync = ref.watch(productsStreamProvider(companyId ?? ''));
    final stockAsync = ref.watch(
      inventoryQuantitiesStreamProvider(widget.storeId),
    );
    final storesAsync = ref.watch(storesStreamProvider(companyId ?? ''));

    final products = productsAsync.value ?? [];
    final stockByProductId = stockAsync.value ?? {};
    final stores = storesAsync.value ?? [];
    Store? store;
    try {
      store = stores.firstWhere((s) => s.id == widget.storeId);
    } catch (_) {}

    final loading =
        (productsAsync.isLoading && !productsAsync.hasValue) ||
        (stockAsync.isLoading && !stockAsync.hasValue) ||
        (store == null &&
            (storesAsync.isLoading ||
                (storesAsync.hasValue && stores.isNotEmpty)));
    String? error;
    if (companyId == null || widget.storeId.isEmpty) {
      error = 'Boutique non sélectionnée.';
    } else if (store == null && storesAsync.hasValue && stores.isNotEmpty) {
      error = 'Boutique introuvable.';
    } else if (productsAsync.hasError) {
      error = AppErrorHandler.toUserMessage(productsAsync.error!);
    } else if (store == null && !storesAsync.isLoading && stores.isEmpty) {
      error = 'Aucune boutique. Connectez-vous une fois pour synchroniser.';
    }

    if (!_syncTriggeredOnce &&
        companyId != null &&
        products.isEmpty &&
        !productsAsync.isLoading) {
      _syncTriggeredOnce = true;
      Future.microtask(() => _refreshSync());
    }

    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Chargement...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caisse rapide')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.stores),
                  icon: const Icon(Icons.list_rounded),
                  label: const Text('Choisir une boutique'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _filteredProducts(products, stockByProductId);
    final categories =
        ref.watch(categoriesStreamProvider(companyId ?? '')).valueOrNull ?? [];
    final auth = context.read<AuthProvider>();
    final caissierName =
        auth.profile?.fullName ?? auth.user?.email ?? 'Caissier';
    final posCart = context.watch<PosCartSettingsProvider>();

    final isOnline = ConnectivityService.instance.isOnline;
    final hidePosOrangeBar =
        MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        top: hidePosOrangeBar,
        child: Column(
          children: [
            if (!hidePosOrangeBar) _buildPosHeader(store!, caissierName),
            if (_activeEditSaleId != null) _buildSaleEditModeBanner(theme),
          if (!isOnline) _buildOfflineBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isNarrow)
                  Expanded(
                    flex: 65,
                    child: PosQuickLeftZone(
                      searchController: _searchController,
                      selectedCategoryId: _selectedCategoryId,
                      categories: categories,
                      filteredProducts: filtered,
                      stockByProductId: stockByProductId,
                      onSearchChanged: (_) => setState(() {}),
                      onSearchSubmitted: (value) =>
                          _addByBarcode(value, products, stockByProductId),
                      onCategorySelected: (id) =>
                          setState(() => _selectedCategoryId = id),
                      onAddToCart: (p) => _addToCart(p, stockByProductId),
                      onScanPressed: () =>
                          _openBarcodeScanner(products, stockByProductId),
                      onRefresh: _refreshSync,
                    ),
                  ),
                if (!isNarrow)
                  Expanded(
                    flex: 35,
                    child: PosQuickRightZone(
                      cartItemCount: _cartItemCount,
                      cartTiles: _buildQuickCartTiles(
                        stockByProductId,
                        showQuantityInput: posCart.quickShowQuantityInput,
                        showQuantityButtons: posCart.quickShowQuantityButtons,
                      ),
                      footer: _buildRightZoneFooter(store, stockByProductId),
                    ),
                  ),
                if (isNarrow)
                  Expanded(
                    child: PosQuickLeftZone(
                      searchController: _searchController,
                      selectedCategoryId: _selectedCategoryId,
                      categories: categories,
                      filteredProducts: filtered,
                      stockByProductId: stockByProductId,
                      onSearchChanged: (_) => setState(() {}),
                      onSearchSubmitted: (value) =>
                          _addByBarcode(value, products, stockByProductId),
                      onCategorySelected: (id) =>
                          setState(() => _selectedCategoryId = id),
                      onAddToCart: (p) => _addToCart(p, stockByProductId),
                      onScanPressed: () =>
                          _openBarcodeScanner(products, stockByProductId),
                      onRefresh: _refreshSync,
                    ),
                  ),
              ],
            ),
          ),
          if (isNarrow)
            _buildMobileBottomBar(
              theme,
              store,
              stockByProductId,
              showQuantityInput: posCart.quickShowQuantityInput,
              showQuantityButtons: posCart.quickShowQuantityButtons,
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildSaleEditModeBanner(ThemeData theme) {
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modification d\'une vente (ticket). Enregistrez pour appliquer — connexion requise.',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.posQuick(widget.storeId)),
                child: Text(
                  'Quitter',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banni?re discr?te quand hors ligne : les ventes sont enregistr?es localement.
  Widget _buildOfflineBanner() {
    return Material(
      color: Colors.amber.shade700,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hors ligne : les ventes seront enregistrées localement et synchronisées à la reconnexion.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header ~60px, fond orange #F97316, texte blanc. Sur mobile: layout compact pour ?viter overflow.
  /// [SafeArea] haut : texte/icônes sous encoche / barre de statut.
  Widget _buildPosHeader(Store store, String caissierName) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      color: PosQuickColors.orangePrincipal,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: isNarrow
              ? _buildPosHeaderMobile(store, caissierName)
              : _buildPosHeaderDesktop(store, caissierName),
        ),
      ),
    );
  }

  Widget _buildPosHeaderDesktop(Store store, String caissierName) {
    return Row(
      children: [
        Icon(Icons.store_rounded, color: Colors.white, size: 28),
        const SizedBox(width: 10),
        Text(
          'POS Caisse Rapide',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 24),
        Text(
          'Boutique : ${store.name}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Caissier : $caissierName',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 16),
        ValueListenableBuilder<String>(
          valueListenable: _clockLabel,
          builder: (context, time, _) => Text(
            'Heure : $time',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => _openSalesHistory(),
          icon: const Icon(
            Icons.history_rounded,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Historique ventes',
        ),
        IconButton(
          onPressed: () => _openPosSettings(store),
          icon: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Paramètres',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
          onPressed: _openSalesHistory,
          tooltip: 'Retour à l\'écran Ventes',
        ),
      ],
    );
  }

  Widget _buildPosHeaderMobile(Store store, String caissierName) {
    return Row(
      children: [
        Icon(Icons.store_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'POS Caisse Rapide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              ValueListenableBuilder<String>(
                valueListenable: _clockLabel,
                builder: (context, time, _) => Text(
                  '${store.name} • $time',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _openSalesHistory(),
          icon: const Icon(
            Icons.history_rounded,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Historique',
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        IconButton(
          onPressed: () => _openPosSettings(store),
          icon: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Paramètres',
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
          onPressed: _openSalesHistory,
          tooltip: 'Retour à l\'écran Ventes',
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ],
    );
  }

  /// Ouvre la page Ventes en filtrant sur la boutique courante.
  void _openSalesHistory() {
    context.read<CompanyProvider>().setCurrentStoreId(widget.storeId);
    context.read<SalesPageProvider>().setFilters(storeId: widget.storeId);
    context.read<SalesPageProvider>().invalidate();
    context.go(AppRoutes.sales);
  }

  /// Affiche les param?tres caisse (boutique en lecture seule ; impression automatique modifiable).
  void _openPosSettings(Store store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paramètres caisse',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _infoRow(ctx, 'Boutique', store.name),
                const SizedBox(height: 8),
                _infoRow(
                  ctx,
                  'Remise autorisée',
                  store.posDiscountEnabled ? 'Oui' : 'Non',
                ),
                const SizedBox(height: 8),
                _infoRow(ctx, 'Devise', store.currency ?? 'XOF'),
                const SizedBox(height: 16),
                Builder(
                  builder: (_) {
                    final posCart = ctx.watch<PosCartSettingsProvider>();
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Impression automatique',
                                style: Theme.of(ctx).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Après chaque vente, ne pas afficher le dialogue ticket (gain de temps).',
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        ctx,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: posCart.posQuickAutoPrint,
                          onChanged: (value) =>
                              posCart.setPosQuickAutoPrint(value),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Les autres paramètres de la boutique sont gérés par l\'administrateur.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label :',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  /// Ouvre le scan cam?ra (Android/iOS/Web). Sur Windows/Linux, indique d'utiliser le champ + lecteur USB.
  void _openBarcodeScanner(
    List<Product> products,
    Map<String, int> stockByProductId,
  ) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux) {
      AppToast.info(
        context,
        'Sur PC, utilisez le champ de recherche avec un lecteur de code-barres USB.',
      );
      return;
    }
    showBarcodeScannerDialog(
      context: context,
      onDetected: (code) => _addByBarcode(code, products, stockByProductId),
    );
  }

  List<Widget> _buildQuickCartTiles(
    Map<String, int> stockByProductId, {
    required bool showQuantityInput,
    required bool showQuantityButtons,
  }) {
    return _cart.map((c) {
      final controller = _qtyControllers.putIfAbsent(
        c.productId,
        () =>
            TextEditingController(text: c.quantity == 0 ? '' : '${c.quantity}'),
      );
      return PosQuickCartTile(
        item: c,
        stock: _effectiveStock(c.productId, stockByProductId),
        qtyController: controller,
        onQtyDelta: (delta) => _updateQty(c.productId, delta, stockByProductId),
        onSetQty: (v) => _setQty(c.productId, v, stockByProductId),
        onRemove: () => _removeCartLine(c.productId),
        showQuantityInput: showQuantityInput,
        showQuantityButtons: showQuantityButtons,
      );
    }).toList();
  }

  Widget _buildRightZoneFooter(
    Store? store,
    Map<String, int> stockByProductId,
  ) {
    final cs = Theme.of(context).colorScheme;
    final showDiscount = store?.posDiscountEnabled ?? false;
    final isCash = _paymentMethod == PaymentMethod.cash;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sous-total',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  Text(
                    formatCurrency(_subtotal),
                    style: TextStyle(
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              if (showDiscount || _discount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remise',
                      style: TextStyle(color: cs.onSurface),
                    ),
                    Text(
                      formatCurrency(_discount),
                      style: TextStyle(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    formatCurrency(_total),
                    style: const TextStyle(
                      color: PosQuickColors.orangePrincipal,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(child: _paymentButton('CASH', PaymentMethod.cash)),
              const SizedBox(width: 8),
              Expanded(child: _paymentButton('CARTE', PaymentMethod.card)),
              const SizedBox(width: 8),
              Expanded(
                child: _paymentButton('MOBILE', PaymentMethod.mobile_money),
              ),
            ],
          ),
        ),
        if (showDiscount)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: cs.onSurface),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _discount = n.clamp(0, double.infinity));
              },
              decoration: PosInputTheme.roundedField(
                context,
                radius: 10,
                labelText: 'Remise',
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
        if (isCash) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _amountReceivedController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: cs.onSurface),
              onChanged: (v) {
                setState(() {
                  _amountReceivedTouched = true;
                  _amountReceived =
                      (double.tryParse(v.replaceAll(',', '.')) ?? 0).clamp(
                        0,
                        double.infinity,
                      );
                });
              },
              decoration: PosInputTheme.roundedField(
                context,
                radius: 10,
                labelText: 'Montant reçu',
                hintText: _total > 0 ? formatCurrency(_total) : '0',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (_amountReceivedTouched && _amountReceived > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monnaie à rendre',
                    style: TextStyle(color: cs.onSurface),
                  ),
                  Text(
                    _amountReceived >= _total
                        ? formatCurrency(_amountReceived - _total)
                        : '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _amountReceived >= _total
                          ? PosQuickColors.orangePrincipal
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (_activeEditSaleId != null) {
                      context.go(AppRoutes.posQuick(widget.storeId));
                      return;
                    }
                    setState(() {
                      _cart = [];
                      _discount = 0;
                      _amountReceived = 0;
                      _amountReceivedTouched = false;
                      _discountController.clear();
                      _amountReceivedController.clear();
                    });
                    _clearQtyControllers();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                    side: BorderSide(
                      color: cs.outline.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _activeEditSaleId != null ? 'Quitter' : 'Annuler vente',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      (_canPay &&
                          _stockWarnings(stockByProductId).isEmpty &&
                          !_creating)
                      ? () => _handlePayment(store, stockByProductId)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: PosQuickColors.orangePrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_rounded, size: 22),
                  label: Text(
                    _creating
                        ? 'Enregistrement...'
                        : (_activeEditSaleId != null
                              ? 'ENREGISTRER LA MODIFICATION'
                              : 'VALIDER ET IMPRIMER'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Recherche un produit par code-barres (exact) et l'ajoute au panier.
  void _addByBarcode(
    String code,
    List<Product> products,
    Map<String, int> stockByProductId,
  ) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    Product? product;
    try {
      product = products.firstWhere(
        (p) => p.barcode != null && p.barcode!.trim() == trimmed && p.isActive,
      );
    } catch (_) {}
    if (product == null) {
      AppToast.error(context, 'Aucun produit avec ce code-barres.');
      return;
    }
    if (!_isProductShownOnTill(product, stockByProductId)) {
      AppToast.error(context, 'Produit indisponible (stock épuisé).');
      return;
    }
    _addToCart(product, stockByProductId);
    _searchController.clear();
    setState(() {});
  }

  Widget _paymentButton(String label, PaymentMethod method) {
    final selected = _paymentMethod == method;
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: () => setState(() => _paymentMethod = method),
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? PosQuickColors.orangePrincipal
            : cs.surfaceContainerHighest,
        foregroundColor: selected
            ? Colors.white
            : cs.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openCartSheet(
    Store? store,
    Map<String, int> stockByProductId, {
    required bool showQuantityInput,
    required bool showQuantityButtons,
  }) {
    if (store == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetCs = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            height: MediaQuery.sizeOf(sheetContext).height * 0.9,
            decoration: BoxDecoration(
              color: sheetCs.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            color: PosQuickColors.orangePrincipal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Panier • $_cartItemCount article${_cartItemCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: sheetCs.onSurface,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_cart.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'Panier vide',
                                style: TextStyle(
                                  color: sheetCs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                      else ...[
                        ..._buildQuickCartTiles(
                          stockByProductId,
                          showQuantityInput: showQuantityInput,
                          showQuantityButtons: showQuantityButtons,
                        ).map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: w,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Même bandeau que le bureau : moyens de paiement, remise, espèces, valider.
                      _buildRightZoneFooter(store, stockByProductId),
                    ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBottomBar(
    ThemeData theme,
    Store? store,
    Map<String, int> stockByProductId, {
    required bool showQuantityInput,
    required bool showQuantityButtons,
  }) {
    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openCartSheet(
                  store,
                  stockByProductId,
                  showQuantityInput: showQuantityInput,
                  showQuantityButtons: showQuantityButtons,
                ),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_rounded,
                          color: PosQuickColors.orangePrincipal,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Panier',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$_cartItemCount article${_cartItemCount != 1 ? 's' : ''} • ${formatCurrency(_total)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => _openCartSheet(
                store,
                stockByProductId,
                showQuantityInput: showQuantityInput,
                showQuantityButtons: showQuantityButtons,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: PosQuickColors.orangePrincipal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Voir / Payer'),
            ),
          ),
        ],
      ),
    );
  }
}
