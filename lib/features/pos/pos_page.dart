import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/config/routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/stock_cache_recovery.dart';
import '../../../core/utils/client_request_id.dart';
import '../../../data/local/drift/app_database.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/customers_repository.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/sales_page_provider.dart';
import '../../../shared/utils/format_currency.dart';
import 'pos_models.dart';
import 'services/invoice_a4_pdf_service.dart';
import 'pos_till_product_filter.dart';
import 'widgets/pos_cart_panel.dart';
import 'widgets/pos_cart_tile.dart';
import 'widgets/pos_main_area.dart';
import '../pos_quick/pos_quick_constants.dart';

/// Page POS — lecture 100 % Drift (produits, clients, stock), sync v2 en arrière-plan.
class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key, required this.storeId});

  final String storeId;

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final CustomersRepository _customersRepo = CustomersRepository();
  final SalesRepository _salesRepo = SalesRepository();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _amountReceivedController =
      TextEditingController();

  List<PosCartItem> _cart = [];
  String _customerId = '';
  double _discount = 0;
  double _amountReceived = 0;
  bool _creating = false;
  InvoiceA4Data? _lastInvoiceA4Data;
  bool _syncTriggeredOnce = false;
  Timer? _periodicSyncTimer;
  String? _logoCacheWarmedForStoreId;
  DateTime? _lastStockLimitToastAt;
  String _currentTime = '';
  Timer? _clockTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Clients créés en local (offline) ou venant d'être créés (online) avant le prochain pull.
  final List<Customer> _pendingCustomers = [];

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedCategoryId;
  late final ValueNotifier<PaymentMethod> _paymentMethodNotifier;
  final Map<String, TextEditingController> _qtyControllers = {};

  /// Sync périodique : les produits (ou clients/stock) ajoutés ailleurs apparaissent sur la caisse sans qu'elle ait à rafraîchir.
  static const Duration _periodicSyncInterval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );
    _connectivitySubscription = ConnectivityService
        .instance
        .onConnectivityChanged
        .listen((_) {
          if (mounted) setState(() {});
        });
    _paymentMethodNotifier = ValueNotifier(_paymentMethod);
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (!mounted) return;
      Future.microtask(() => _refreshSync());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _paymentMethodNotifier.dispose();
    _clearQtyControllers();
    _searchController.dispose();
    _discountController.dispose();
    _amountReceivedController.dispose();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    final t = DateFormat('HH:mm').format(DateTime.now());
    if (t != _currentTime) setState(() => _currentTime = t);
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
        AppErrorHandler.log(e, st);
      }
    }
  }

  /// Quitter le POS : écran Ventes, filtré sur la boutique courante.
  void _leavePosToSalesScreen() {
    context.read<CompanyProvider>().setCurrentStoreId(widget.storeId);
    context.read<SalesPageProvider>().setFilters(storeId: widget.storeId);
    context.read<SalesPageProvider>().invalidate();
    context.go(AppRoutes.sales);
  }

  void _warmInvoiceLogoCacheIfNeeded(Store? store) {
    if (store == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    final url = store.logoUrl;
    if (url == null || url.trim().isEmpty) return;
    if (_logoCacheWarmedForStoreId == store.id) return;
    _logoCacheWarmedForStoreId = store.id;
    Future.microtask(() async {
      try {
        final bytes = await _fetchLogoBytes(url);
        if (bytes != null && bytes.isNotEmpty) {
          await InvoiceA4PdfService.cacheLogoBytes(store.id, bytes);
        }
      } catch (_) {}
    });
  }

  /// Filtre par recherche, actifs — et masque les produits en rupture (stock ≤ 0) en caisse Facture A4.
  List<Product> _filteredProducts(
    List<Product> products,
    Map<String, int> stockByProductId,
  ) {
    final search = _searchController.text.trim().toLowerCase();
    return products.where((p) {
      if (!isProductShownOnStoreTill(p, stockByProductId)) return false;
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

  double get _subtotal => _cart.fold(0, (s, c) => s + c.total);
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  bool get _canPay => _cart.isNotEmpty && _total > 0;
  int get _cartItemCount => _cart.fold(0, (n, c) => n + c.quantity);

  List<PosCartItem> _stockWarnings(Map<String, int> stockByProductId) => _cart
      .where((c) => (stockByProductId[c.productId] ?? 0) < c.quantity)
      .toList();

  String? _selectedCustomerName(List<Customer> customers) {
    if (_customerId.isEmpty) return null;
    try {
      return customers.firstWhere((c) => c.id == _customerId).name;
    } catch (_) {
      return null;
    }
  }

  String _labelForPayment(PaymentMethod p) {
    switch (p) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.mobile_money:
        return 'Mobile money';
      case PaymentMethod.card:
        return 'Carte';
      case PaymentMethod.other:
        return 'À crédit';
      default:
        return 'Espèces';
    }
  }

  /// Acompte = montant payé maintenant. Reste à payer = _total - acompte (total, partiel ou crédit).
  /// Le backend impose `sale_payments.amount > 0`, on normalise donc toujours
  /// vers un montant strictement positif et borné au total.
  List<CreateSalePaymentInput> _buildPayments() {
    final total = _total.clamp(0.0, double.infinity);
    if (total <= 0) {
      return const <CreateSalePaymentInput>[];
    }
    final acompte = _amountReceived.clamp(0.0, double.infinity);
    if (_paymentMethod == PaymentMethod.other && acompte <= 0) {
      return [
        CreateSalePaymentInput(
          method: PaymentMethod.other,
          amount: total,
          reference: 'À crédit',
        ),
      ];
    }
    final normalized = acompte <= 0 ? total : acompte.clamp(0.01, total);
    return [CreateSalePaymentInput(method: _paymentMethod, amount: normalized)];
  }

  double get _acompte => _amountReceived.clamp(0.0, double.infinity);
  double get _resteApayer => (_total - _acompte).clamp(0.0, double.infinity);

  Future<void> _showCreateCustomerDialog(
    ThemeData theme,
    List<Customer> customers,
  ) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < Breakpoints.tablet;
    final dialogInset = isNarrow
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
        : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    final result = await showDialog<CreateCustomerResult?>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: dialogInset,
        title: const Text('Nouveau client'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  border: OutlineInputBorder(),
                  hintText: 'Nom du client',
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? '2 caractères minimum'
                    : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                  hintText: 'Optionnel',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            style: TextButton.styleFrom(
              minimumSize: const Size(
                Breakpoints.minTouchTarget,
                Breakpoints.minTouchTarget,
              ),
            ),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, Breakpoints.minTouchTarget),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim();
                Navigator.of(
                  ctx,
                ).pop(CreateCustomerResult(name: name, phone: phone));
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
    });
    if (result == null || !mounted) return;
    final name = result.name;
    final phone = result.phone;
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      final localId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await ref
            .read(appDatabaseProvider)
            .enqueuePendingAction(
              'customer',
              jsonEncode({
                'local_id': localId,
                'company_id': companyId,
                'name': name,
                'type': 'individual',
                'phone': phone,
              }),
            );
        if (!mounted) return;
        final pendingCustomer = Customer(
          id: 'pending:$localId',
          companyId: companyId,
          name: name,
          type: CustomerType.individual,
          phone: phone,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _pendingCustomers.add(pendingCustomer);
            _customerId = pendingCustomer.id;
          });
          AppToast.success(
            context,
            'Client enregistré localement. Il sera créé à la reconnexion.',
          );
        });
        Future.microtask(() => _refreshSync());
      } catch (e, st) {
        if (mounted) AppErrorHandler.show(context, e, stackTrace: st);
      }
      return;
    }
    try {
      final newCustomer = await _customersRepo.create(
        CreateCustomerInput(
          companyId: companyId,
          name: name,
          type: CustomerType.individual,
          phone: phone,
        ),
      );
      if (mounted) {
        final newCustomerFinal = newCustomer;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _pendingCustomers.add(newCustomerFinal);
            _customerId = newCustomerFinal.id;
          });
          AppToast.success(context, 'Client créé');
        });
        Future.microtask(() => _refreshSync());
      }
    } catch (e, st) {
      if (mounted) AppErrorHandler.show(context, e, stackTrace: st);
    }
  }

  Future<void> _showSelectOrCreateCustomerDialog(
    ThemeData theme,
    List<Customer> customers,
  ) async {
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < Breakpoints.tablet;
    final dialogInset = isNarrow
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
        : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    final contentWidth = isNarrow ? screenSize.width - 32 : 400.0;
    final contentHeight = isNarrow ? screenSize.height * 0.5 : 320.0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: dialogInset,
        title: const Text('Choisir un client'),
        content: SizedBox(
          width: contentWidth,
          height: contentHeight,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...customers.map((c) {
                  final selected = c.id == _customerId;
                  final customerId = c.id;
                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.person_outline_rounded,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    title: Text(c.name, overflow: TextOverflow.ellipsis),
                    subtitle: c.phone != null && c.phone!.isNotEmpty
                        ? Text(c.phone!, overflow: TextOverflow.ellipsis)
                        : null,
                    minVerticalPadding: 14,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _customerId = customerId);
                      });
                    },
                  );
                }),
                ListTile(
                  leading: Icon(
                    Icons.person_add_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Créer un client'),
                  minVerticalPadding: 14,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showCreateCustomerDialog(theme, customers);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _customerId = '');
              });
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(
                Breakpoints.minTouchTarget,
                Breakpoints.minTouchTarget,
              ),
            ),
            child: const Text('Aucun client'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(
                Breakpoints.minTouchTarget,
                Breakpoints.minTouchTarget,
              ),
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static String _defaultUnitForProduct(Product p) {
    final u = (p.unit).trim().toLowerCase();
    if (u.isEmpty) return 'pce';
    if (kInvoiceUnits.any((x) => x.toLowerCase() == u))
      return kInvoiceUnits.firstWhere((x) => x.toLowerCase() == u);
    return 'pce';
  }

  void _addToCart(Product p, Map<String, int> stockByProductId) {
    final stock = stockByProductId[p.id] ?? 0;
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
        existing.total = newQty * existing.unitPrice;
        final pid = existing.productId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _qtyControllers[pid]?.text =
              newQty == 0 ? '' : newQty.toString();
        });
      } else {
        if (stock <= 0) return;
        _cart.add(
          PosCartItem(
            productId: p.id,
            name: p.name,
            sku: p.sku,
            unit: _defaultUnitForProduct(p),
            quantity: 0,
            unitPrice: p.salePrice,
            total: 0,
            imageUrl: p.productImages?.isNotEmpty == true
                ? p.productImages!.first.url
                : null,
          ),
        );
      }
    });
  }

  void _setUnit(String productId, String unit) {
    setState(() {
      for (final c in _cart) {
        if (c.productId == productId) {
          c.unit = unit;
          return;
        }
      }
    });
  }

  void _updateQty(
    String productId,
    int delta,
    Map<String, int> stockByProductId,
  ) {
    final stock = stockByProductId[productId] ?? 0;
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
    if (newQty != null && _qtyControllers.containsKey(productId)) {
      _qtyControllers[productId]!.text =
          newQty == 0 ? '' : newQty.toString();
    }
  }

  void _clearQtyControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _qtyControllers.clear();
  }

  void _setQty(String productId, int value, Map<String, int> stockByProductId) {
    final stock = stockByProductId[productId] ?? 0;
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
      _cart = _cart
          .map((c) {
            if (c.productId != productId) return c;
            c.quantity = clamped;
            c.total = clamped * c.unitPrice;
            return c;
          })
          .toList();
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

  /// Récupère les octets du logo depuis l’URL (pour la facture A4).
  static Future<Uint8List?> _fetchLogoBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty)
        return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<void> _handlePayment(
    Store? store,
    List<Customer> customers,
    Map<String, int> stockByProductId,
  ) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final userId = context.read<AuthProvider>().user?.id;
    if (companyId == null || userId == null || store == null || !_canPay)
      return;
    if (_cart.any((c) => c.quantity <= 0)) {
      AppToast.error(
        context,
        'Indiquez une quantité supérieure à 0 pour chaque ligne du panier.',
      );
      return;
    }
    if (_stockWarnings(stockByProductId).isNotEmpty) {
      AppToast.error(context, 'Stock insuffisant pour certains articles.');
      return;
    }
    if (_paymentMethod == PaymentMethod.other && _customerId.isEmpty) {
      AppToast.error(context, 'Associez un client pour une vente à crédit.');
      return;
    }
    setState(() => _creating = true);
    Future<void> saveOfflineAndShowInvoice(
      List<CreateSalePaymentInput> payments,
    ) async {
      final localId = 'sale_${DateTime.now().millisecondsSinceEpoch}';
      final pendingSaleId = 'pending:$localId';
      final now = DateTime.now();
      final ymd = DateFormat('yyyyMMdd').format(now);
      final hm = DateFormat('HHmm').format(now);
      final prefix =
          (store.invoicePrefix != null &&
              store.invoicePrefix!.trim().isNotEmpty)
          ? store.invoicePrefix!.trim()
          : 'FV';
      final localSaleNumber =
          '$prefix-$ymd-$hm-${localId.substring(localId.length - 4)}';

      final payload = {
        'p_company_id': companyId,
        'p_store_id': widget.storeId,
        'p_customer_id': _customerId.isEmpty ? null : _customerId,
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
        'p_sale_mode': SaleMode.invoicePos.value,
        'p_document_type': DocumentType.a4Invoice.value,
        'p_client_request_id': newClientRequestId(),
      };
      // Store wrapper so sync can clean up the local "pending" sale after successful push.
      await ref
          .read(appDatabaseProvider)
          .enqueuePendingAction(
            'sale',
            jsonEncode({'local_id': localId, 'rpc': payload}),
          );

      // Create a local sale immediately so the UI + PDF look like online (with a real-ish number).
      final isoNow = now.toUtc().toIso8601String();
      await ref
          .read(appDatabaseProvider)
          .upsertLocalSale(
            LocalSalesCompanion.insert(
              id: pendingSaleId,
              companyId: companyId,
              storeId: widget.storeId,
              customerId: drift.Value(_customerId.isEmpty ? null : _customerId),
              saleNumber: localSaleNumber,
              status: 'completed',
              subtotal: drift.Value(_subtotal),
              discount: drift.Value(_discount),
              tax: const drift.Value(0),
              total: _total,
              createdBy: userId,
              createdAt: isoNow,
              updatedAt: isoNow,
              synced: const drift.Value(false),
              saleMode: drift.Value(SaleMode.invoicePos.value),
              documentType: drift.Value(DocumentType.a4Invoice.value),
            ),
          );
      await ref
          .read(appDatabaseProvider)
          .upsertLocalSaleItems(
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

      if (!mounted) return;
      Customer? selectedCustomer;
      if (_customerId.isNotEmpty) {
        try {
          selectedCustomer = customers.firstWhere((c) => c.id == _customerId);
        } catch (_) {}
      }
      final storeForInvoice = await InvoiceA4PdfService.resolveStoreForInvoice(
        store,
        allowNetwork: ConnectivityService.instance.isOnline,
      );
      Uint8List? logoBytesOffline;
      if (ConnectivityService.instance.isOnline &&
          storeForInvoice.logoUrl != null &&
          storeForInvoice.logoUrl!.isNotEmpty) {
        logoBytesOffline = await _fetchLogoBytes(storeForInvoice.logoUrl);
        if (logoBytesOffline != null && logoBytesOffline.isNotEmpty) {
          await InvoiceA4PdfService.cacheLogoBytes(
            storeForInvoice.id,
            logoBytesOffline,
          );
        }
      } else {
        logoBytesOffline = await InvoiceA4PdfService.loadCachedLogoBytes(
          storeForInvoice.id,
        );
      }
      final invoiceA4Offline = InvoiceA4Data(
        store: storeForInvoice,
        saleNumber: localSaleNumber,
        date: DateTime.now(),
        items: _cart
            .map(
              (c) => InvoiceLineData(
                description: c.name,
                quantity: c.quantity,
                unit: c.unit,
                unitPrice: c.unitPrice,
                total: c.total,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        discount: _discount,
        tax: 0,
        total: _total,
        customerName: selectedCustomer?.name,
        customerPhone: selectedCustomer?.phone,
        depositAmount: _acompte,
        logoBytes: logoBytesOffline,
      );
      setState(() {
        _cart = [];
        _discount = 0;
        _amountReceived = 0;
        _creating = false;
        _lastInvoiceA4Data = invoiceA4Offline;
      });
      _discountController.clear();
      _amountReceivedController.clear();
      if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showInvoiceA4IfNeeded(),
      );
      Future.microtask(() => _refreshSync());
      AppToast.success(
        context,
        'Vente enregistrée localement. Synchronisation à la reconnexion.',
      );
    }

    try {
      final payments = _buildPayments();
      // 1) Si le device est offline → enregistrer localement.
      if (!ConnectivityService.instance.isOnline) {
        await saveOfflineAndShowInvoice(payments);
        return;
      }

      // 2) Sinon, tenter l'enregistrement en ligne. Si l'appel réseau échoue (coupure / instable),
      // basculer automatiquement en mode offline (offline-first robuste).
      final sale = await _salesRepo.create(
        CreateSaleInput(
          companyId: companyId,
          storeId: widget.storeId,
          customerId: _customerId.isEmpty ? null : _customerId,
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
          saleMode: SaleMode.invoicePos,
          documentType: DocumentType.a4Invoice,
        ),
        userId,
      );
      if (!mounted) return;
      try {
        await ref.read(salesOfflineRepositoryProvider).upsertSale(sale);
      } catch (e2, st2) {
        AppErrorHandler.log(e2, st2);
        // Vente déjà créée côté serveur ; on continue pour afficher la facture
      }
      if (!mounted) return;
      ref.invalidate(
        salesStreamProvider((companyId: companyId, storeId: widget.storeId)),
      );
      Customer? selectedCustomer;
      if (_customerId.isNotEmpty) {
        try {
          selectedCustomer = customers.firstWhere((c) => c.id == _customerId);
        } catch (_) {}
      }
      final storeForInvoice = await InvoiceA4PdfService.resolveStoreForInvoice(
        store,
      );
      final logoBytes =
          storeForInvoice.logoUrl != null && storeForInvoice.logoUrl!.isNotEmpty
          ? await _fetchLogoBytes(storeForInvoice.logoUrl)
          : null;
      if (logoBytes != null && logoBytes.isNotEmpty) {
        await InvoiceA4PdfService.cacheLogoBytes(storeForInvoice.id, logoBytes);
      }
      final depositFromPayments = sale.salePayments != null
          ? sale.salePayments!.fold<double>(0, (s, p) => s + p.amount)
          : _acompte;
      final invoiceA4 = InvoiceA4Data(
        store: storeForInvoice,
        saleNumber: sale.saleNumber,
        date: DateTime.parse(sale.createdAt),
        items: _cart
            .map(
              (c) => InvoiceLineData(
                description: c.name,
                quantity: c.quantity,
                unit: c.unit,
                unitPrice: c.unitPrice,
                total: c.total,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        discount: _discount,
        tax: sale.tax,
        total: _total,
        customerName: selectedCustomer?.name,
        customerPhone: selectedCustomer?.phone,
        depositAmount: depositFromPayments,
        logoBytes: logoBytes,
      );
      setState(() {
        _cart = [];
        _discount = 0;
        _amountReceived = 0;
        _creating = false;
        _lastInvoiceA4Data = invoiceA4;
      });
      _clearQtyControllers();
      _discountController.clear();
      _amountReceivedController.clear();
      if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showInvoiceA4IfNeeded(),
      );
      AppToast.success(
        context,
        'Vente #${sale.saleNumber} enregistrée. Total: ${formatCurrency(sale.total)}',
      );
    } catch (e, st) {
      // Si l'enregistrement en ligne échoue à cause du réseau, on enregistre localement
      // au lieu d'afficher une erreur bloquante.
      if (ErrorMapper.isNetworkError(e)) {
        try {
          await saveOfflineAndShowInvoice(_buildPayments());
          return;
        } catch (e2, st2) {
          if (mounted) {
            setState(() => _creating = false);
            AppErrorHandler.show(
              context,
              e2,
              fallback: 'Impossible d\'enregistrer la vente. Réessayez.',
              stackTrace: st2,
            );
          }
          return;
        }
      }
      if (mounted) {
        if (shouldRecoverInventoryCachesFromRpcError(e)) {
          recoverStoreInventoryCacheAfterRpcError(
            ref,
            widget.storeId,
            _refreshSync,
          );
        }
        setState(() => _creating = false);
        AppErrorHandler.show(context, e, stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 900;
    final isOnline = ConnectivityService.instance.isOnline;
    final permissions = context.watch<PermissionsProvider>();
    if (!permissions.hasLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facture A4')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final canInvoiceA4 =
        permissions.hasPermission(Permissions.salesInvoiceA4) ||
        permissions.hasPermission(Permissions.salesCreate);
    if (!canInvoiceA4) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facture A4')),
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
                  "Vous n'avez pas le droit d'émettre des factures A4.",
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

    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final productsAsync = ref.watch(productsStreamProvider(companyId ?? ''));
    final categoriesAsync = ref.watch(categoriesStreamProvider(companyId ?? ''));
    final customersAsync = ref.watch(customersStreamProvider(companyId ?? ''));
    final stockAsync = ref.watch(
      inventoryQuantitiesStreamProvider(widget.storeId),
    );
    final storesAsync = ref.watch(storesStreamProvider(companyId ?? ''));

    final products = productsAsync.value ?? [];
    final categories = categoriesAsync.value ?? const <Category>[];
    final streamCustomers = customersAsync.value ?? [];
    final customers = [
      ...streamCustomers,
      ..._pendingCustomers.where(
        (c) => !streamCustomers.any((s) => s.id == c.id),
      ),
    ];
    final stockByProductId = stockAsync.value ?? {};
    final stores = storesAsync.value ?? [];
    Store? store;
    try {
      store = stores.firstWhere((s) => s.id == widget.storeId);
    } catch (_) {}
    _warmInvoiceLogoCacheIfNeeded(store);

    // Ne pas bloquer tout l'écran quand un stream repasse en chargement alors qu'on a déjà des données
    // (sinon chaque setState pendant la saisie quantité → spinner → le panier semble « vidé »).
    final loading =
        (productsAsync.isLoading && !productsAsync.hasValue) ||
        (customersAsync.isLoading && !customersAsync.hasValue) ||
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
        streamCustomers.isEmpty &&
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
                'Chargement Facture A4...',
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
        appBar: AppBar(title: const Text('Facture A4')),
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

    return Scaffold(
      body: Column(
        children: [
          _buildPosHeader(store!),
          if (!isOnline) _buildOfflineBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PosMainArea(
                    searchController: _searchController,
                    customerId: _customerId,
                    customers: customers,
                    filteredProducts: _filteredProducts(
                      products,
                      stockByProductId,
                    ),
                    stockByProductId: stockByProductId,
                    categories: categories,
                    selectedCategoryId: _selectedCategoryId,
                    onCustomerIdChanged: (v) =>
                        setState(() => _customerId = v ?? ''),
                    onCategorySelected: (id) =>
                        setState(() => _selectedCategoryId = id),
                    onCreateCustomer: () =>
                        _showCreateCustomerDialog(theme, customers),
                    onSelectOrCreateCustomer: () =>
                        _showSelectOrCreateCustomerDialog(theme, customers),
                    onAddToCart: (p) => _addToCart(p, stockByProductId),
                    onSearchChanged: (_) => setState(() {}),
                  ),
                ),
                if (!isNarrow)
                  SizedBox(
                    width: 380,
                    child: PosCartPanel(
                      cartItemCount: _cartItemCount,
                      cartTiles: _buildCartTiles(theme, stockByProductId),
                      footer: _buildCartFooter(
                        theme,
                        store,
                        customers,
                        stockByProductId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isNarrow)
            _buildMobileBottomBar(theme, store, customers, stockByProductId),
        ],
      ),
    );
  }

  static const List<PaymentMethod> _paymentMethods = [
    PaymentMethod.cash,
    PaymentMethod.mobile_money,
    PaymentMethod.card,
    PaymentMethod.other,
  ];

  List<Widget> _buildCartTiles(
    ThemeData theme,
    Map<String, int> stockByProductId,
  ) {
    return _cart.map((c) {
      final controller = _qtyControllers.putIfAbsent(
        c.productId,
        () => TextEditingController(
          text: c.quantity == 0 ? '' : '${c.quantity}',
        ),
      );
      return PosCartTile(
        item: c,
        stock: stockByProductId[c.productId] ?? 0,
        qtyController: controller,
        onQtyDelta: (delta) => _updateQty(c.productId, delta, stockByProductId),
        onSetQty: (v) => _setQty(c.productId, v, stockByProductId),
        onUnitChange: (u) => _setUnit(c.productId, u),
        onRemove: () => _removeCartLine(c.productId),
      );
    }).toList();
  }

  Widget _buildCartFooter(
    ThemeData theme,
    Store? store,
    List<Customer> customers,
    Map<String, int> stockByProductId, {
    PaymentMethod? paymentOverride,
    void Function(PaymentMethod)? onPaymentSelected,
  }) {
    final showDiscount = store?.posDiscountEnabled ?? false;
    final effectivePayment = paymentOverride ?? _paymentMethod;
    final isCash = effectivePayment == PaymentMethod.cash;
    void selectPayment(PaymentMethod m) {
      if (onPaymentSelected != null) {
        _paymentMethodNotifier.value = m;
        onPaymentSelected(m);
      } else {
        _paymentMethodNotifier.value = m;
        setState(() {
          _paymentMethod = m;
          if (m == PaymentMethod.other) {
            _amountReceived = 0;
            _amountReceivedController.text = '';
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_cart.isNotEmpty) ...[
          if (!isCash) ...[
            Text(
              'Client',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () =>
                  _showSelectOrCreateCustomerDialog(theme, customers),
              icon: const Icon(Icons.person_outline_rounded, size: 20),
              label: Text(
                _selectedCustomerName(customers) ??
                    'Choisir ou créer un client',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Mode de paiement',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _paymentMethods.map((m) {
              final label = m == PaymentMethod.cash
                  ? 'Espèces'
                  : m == PaymentMethod.mobile_money
                  ? 'Mobile money'
                  : m == PaymentMethod.card
                  ? 'Carte'
                  : 'À crédit';
              final selected = effectivePayment == m;
              return FilterChip(
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                selected: selected,
                onSelected: (_) => selectPayment(m),
                selectedColor: theme.colorScheme.primaryContainer,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: selected ? 1.5 : 1,
                ),
                checkmarkColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (showDiscount) ...[
            Text(
              'Remise',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _discount = n.clamp(0, double.infinity));
              },
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Acompte (montant payé maintenant)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _amountReceivedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              setState(() {
                _amountReceived = (double.tryParse(v.replaceAll(',', '.')) ?? 0)
                    .clamp(0, double.infinity);
              });
            },
            decoration: InputDecoration(
              hintText: _total > 0 ? formatCurrency(_total) : '0',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(
                0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reste à payer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatCurrency(_resteApayer),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _resteApayer > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (isCash && _amountReceived > _total) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monnaie à rendre',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatCurrency(_amountReceived - _total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              formatCurrency(_total),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              (_canPay &&
                  _stockWarnings(stockByProductId).isEmpty &&
                  !_creating)
              ? () => _handlePayment(store, customers, stockByProductId)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: PosQuickColors.orangePrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _creating
                ? 'Enregistrement...'
                : 'Payer (${_labelForPayment(effectivePayment)})',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomBar(
    ThemeData theme,
    Store? store,
    List<Customer> customers,
    Map<String, int> stockByProductId,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: PosQuickColors.fondPrincipal,
        border: const Border(top: BorderSide(color: PosQuickColors.bordure)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openCartSheet(store, customers, stockByProductId),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      color: PosQuickColors.orangePrincipal,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Panier',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$_cartItemCount article${_cartItemCount != 1 ? 's' : ''} · ${formatCurrency(_total)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PosQuickColors.textePrincipal.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _openCartSheet(store, customers, stockByProductId),
            style: FilledButton.styleFrom(
              backgroundColor: PosQuickColors.orangePrincipal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Voir / Payer'),
          ),
        ],
      ),
    );
  }

  void _openCartSheet(
    Store? store,
    List<Customer> customers,
    Map<String, int> stockByProductId,
  ) {
    final theme = Theme.of(context);
    _paymentMethodNotifier.value = _paymentMethod;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.85,
        decoration: BoxDecoration(
          color: PosQuickColors.fondSecondaire,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Articles (${_cartItemCount})',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Panier',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_cart.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Panier vide',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      ..._buildCartTiles(theme, stockByProductId),
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withOpacity(0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Récapitulatif et paiement',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PosQuickColors.orangePrincipal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<PaymentMethod>(
                        valueListenable: _paymentMethodNotifier,
                        builder: (_, pm, __) => _buildCartFooter(
                          theme,
                          store,
                          customers,
                          stockByProductId,
                          paymentOverride: pm,
                          onPaymentSelected: (m) {
                            _paymentMethodNotifier.value = m;
                            setState(() => _paymentMethod = m);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {});
  }

  Widget _buildOfflineBanner() {
    return Material(
      color: Colors.amber.shade700,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hors ligne : les factures sont enregistrées localement et synchronisées à la reconnexion.',
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

  Widget _buildPosHeader(Store store) {
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
              ? Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POS Facture A4',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${store.name} • $_currentTime',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text(
                  'POS Facture A4',
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
                  'Heure : $_currentTime',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshSync,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Actualiser',
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: _leavePosToSalesScreen,
                  tooltip: 'Retour à l\'écran Ventes',
                ),
              ],
            ),
        ),
      ),
    );
  }

  /// Ouvre un écran de visualisation du PDF facture (aperçu réel dans l'app).
  void _showPdfViewer(BuildContext context, InvoiceA4Data data) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Facture A4'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async {
                try {
                  final doc = await InvoiceA4PdfService.buildDocument(data);
                  return doc.save();
                } catch (e) {
                  if (ctx.mounted)
                    AppErrorHandler.show(
                      ctx,
                      e,
                      fallback: 'Impossible d\'afficher la facture PDF.',
                    );
                  return Uint8List(0);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Affiche la facture A4 après une vente (POS Facture A4 : pas de ticket thermique).
  void _showInvoiceA4IfNeeded() {
    final invoiceA4 = _lastInvoiceA4Data;
    if (invoiceA4 == null || !mounted || !context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Facture enregistrée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'La vente a été enregistrée. Vous pouvez voir le PDF, l\'imprimer ou télécharger la facture.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showPdfViewer(context, invoiceA4);
                    });
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  label: const Text('Voir le PDF'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      AppToast.info(context, 'Impression en cours...');
                    }
                    unawaited(
                      InvoiceA4PdfService.printPdfDirect(invoiceA4)
                          .then((_) {
                            if (mounted) {
                              AppToast.success(
                                context,
                                'Impression envoyée à l’imprimante.',
                              );
                            }
                          })
                          .catchError((Object e) {
                            if (mounted) {
                              AppErrorHandler.show(
                                context,
                                e,
                                fallback: 'Impossible d’imprimer la facture.',
                              );
                            }
                          }),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 20),
                  label: const Text('Imprimer'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final path = await InvoiceA4PdfService.downloadPdf(
                        invoiceA4,
                      );
                      if (ctx.mounted) {
                        if (path != null && path.isNotEmpty) {
                          AppToast.success(
                            ctx,
                            kIsWeb
                                ? 'PDF prêt : utilisez Partager ou enregistrez depuis l’aperçu.'
                                : 'Facture enregistrée sur l’appareil.',
                          );
                          Navigator.of(ctx).pop();
                        }
                        // Annulation du dialogue d’enregistrement : on laisse la fenêtre ouverte
                      }
                    } catch (e) {
                      if (ctx.mounted)
                        AppErrorHandler.show(
                          ctx,
                          e,
                          fallback: 'Impossible de télécharger la facture.',
                        );
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Télécharger'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _lastInvoiceA4Data = null);
    });
  }
}
