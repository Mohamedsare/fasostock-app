import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;
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
import '../../../core/utils/sale_pos_edit.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/stock_cache_recovery.dart';
import '../../../core/utils/user_country_time.dart';
import '../../../core/utils/client_request_id.dart';
import '../../../data/local/drift/app_database.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/customers_repository.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/sales_page_provider.dart';
import '../../../shared/utils/format_currency.dart';
import 'pos_models.dart';
import 'services/invoice_a4_pdf_service.dart';
import 'widgets/pos_cart_panel.dart';
import 'widgets/pos_cart_tile.dart';
import 'widgets/pos_invoice_table_cart.dart';
import 'widgets/pos_main_area.dart' show PosMainArea, PosMainProductGridMode;
import '../pos_quick/pos_quick_constants.dart';

/// Page POS — lecture 100 % Drift (produits, clients, stock), sync v2 en arrière-plan.
class PosPage extends ConsumerStatefulWidget {
  const PosPage({
    super.key,
    required this.storeId,
    this.editSaleId,
    this.invoiceTableLayout = false,
  });

  final String storeId;
  /// Ouvre le POS facture avec une vente complétée à modifier (`?editSale=`).
  final String? editSaleId;
  /// Route [AppRoutes.factureTab] : panier en tableau (même PDF A4).
  final bool invoiceTableLayout;

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final CustomersRepository _customersRepo = CustomersRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

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
  final Map<String, TextEditingController> _puControllers = {};

  String? _activeEditSaleId;
  Map<String, int> _editStockRelease = {};
  bool _saleEditBootstrapping = false;
  String? _saleEditBarrierError;

  bool _invoiceTableSettingLoaded = false;
  bool _invoiceTableCompanyEnabled = false;

  /// Sync périodique : les produits (ou clients/stock) ajoutés ailleurs apparaissent sur la caisse sans qu'elle ait à rafraîchir.
  static const Duration _periodicSyncInterval = Duration(seconds: 45);

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

  @override
  void initState() {
    super.initState();
    final ep = widget.editSaleId?.trim() ?? '';
    if (ep.isNotEmpty) _saleEditBootstrapping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<CompanyProvider>().setCurrentStoreId(widget.storeId);
      if (widget.invoiceTableLayout && ep.isEmpty) {
        // Affichage immédiat : pas d'attente réseau (peek cache ou défaut optimiste).
        final cid = context.read<CompanyProvider>().currentCompanyId;
        if (cid != null) {
          final cached = SettingsRepository.peekInvoiceTablePosEnabled(cid);
          if (cached != null) {
            setState(() {
              _invoiceTableCompanyEnabled = cached;
              _invoiceTableSettingLoaded = true;
            });
          } else {
            setState(() {
              _invoiceTableCompanyEnabled = true;
              _invoiceTableSettingLoaded = true;
            });
          }
        } else {
          setState(() {
            _invoiceTableSettingLoaded = true;
            _invoiceTableCompanyEnabled = false;
          });
        }
        unawaited(_loadInvoiceTableCompanySetting());
      } else if (widget.invoiceTableLayout) {
        setState(() {
          _invoiceTableSettingLoaded = true;
          _invoiceTableCompanyEnabled = true;
        });
      }
      if (ep.isNotEmpty) await _bootstrapSaleEdit();
    });
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
    final t = formatDeviceWallClockHm(DateTime.now());
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
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'pos_background_sync',
          logContext: {
            'store_id': widget.storeId,
            'company_id': company.currentCompanyId,
          },
        );
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

  /// Rafraîchit le réglage serveur en arrière-plan (le premier rendu utilise déjà peek / optimiste).
  Future<void> _loadInvoiceTableCompanySetting() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) {
      if (mounted) {
        setState(() {
          _invoiceTableSettingLoaded = true;
          _invoiceTableCompanyEnabled = false;
        });
      }
      return;
    }
    try {
      final v = await _settingsRepo.getInvoiceTablePosEnabled(companyId);
      if (mounted) {
        setState(() {
          _invoiceTableCompanyEnabled = v;
          _invoiceTableSettingLoaded = true;
        });
      }
    } catch (e, st) {
      final peek = SettingsRepository.peekInvoiceTablePosEnabled(companyId);
      final online = ConnectivityService.instance.isOnline;
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'pos_invoice_table_settings',
        logContext: {
          'company_id': companyId,
          'online': online,
          'had_cached_peek': peek != null,
        },
      );
      if (!mounted) return;
      setState(() {
        _invoiceTableSettingLoaded = true;
        // Hors ligne ou erreur : ne pas traiter comme « entreprise désactivée ».
        _invoiceTableCompanyEnabled =
            peek ?? (!online ? true : _invoiceTableCompanyEnabled);
      });
    }
  }

  static String _puFieldText(double unitPrice) => '${unitPrice.round()}';

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

  void _ensureQtyControllersForCart() {
    for (final c in _cart) {
      _qtyControllers.putIfAbsent(
        c.productId,
        () => TextEditingController(
          text: c.quantity == 0 ? '' : '${c.quantity}',
        ),
      );
      _puControllers.putIfAbsent(
        c.productId,
        () => TextEditingController(text: _puFieldText(c.unitPrice)),
      );
    }
  }

  void _setUnitPrice(String productId, double value) {
    final pu = value.clamp(0.0, 999_999_999.0).round().toDouble();
    PosCartItem? cur;
    try {
      cur = _cart.firstWhere((c) => c.productId == productId);
    } catch (_) {
      cur = null;
    }
    if (cur == null) return;
    if (pu.round() == cur.unitPrice.round()) return;

    setState(() {
      for (final c in _cart) {
        if (c.productId == productId) {
          c.unitPrice = pu;
          c.linePriceUserSet = true;
          c.total = (c.quantity * c.unitPrice).roundToDouble();
          break;
        }
      }
    });
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
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'pos_invoice_logo_warm',
          logContext: {'store_id': store.id},
        );
      }
    });
  }

  /// Filtre recherche / catégorie ; boutique active avec stock effectif > 0.
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

  double get _subtotal => _cart.fold(0, (s, c) => s + c.total);
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  bool get _canPay => _cart.isNotEmpty && _total > 0;
  int get _cartItemCount => _cart.fold(0, (n, c) => n + c.quantity);

  List<PosCartItem> _stockWarnings(Map<String, int> stockByProductId) => _cart
      .where((c) => _effectiveStock(c.productId, stockByProductId) < c.quantity)
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
        if (mounted) {
          AppErrorHandler.show(
            context,
            e,
            stackTrace: st,
            logSource: 'pos_customer_create_offline',
            logContext: {'store_id': widget.storeId},
          );
        }
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
      if (mounted) {
        AppErrorHandler.show(
          context,
          e,
          stackTrace: st,
          logSource: 'pos_customer_create_online',
          logContext: {'store_id': widget.storeId},
        );
      }
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
    if (kInvoiceUnits.any((x) => x.toLowerCase() == u)) {
      return kInvoiceUnits.firstWhere((x) => x.toLowerCase() == u);
    }
    return 'pce';
  }

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
        final line = existing;
        final newQty = line.quantity + 1;
        if (stock >= 0 && newQty > stock) {
          _showStockLimitToast();
          return;
        }
        line.quantity = newQty;
        if (!line.linePriceUserSet) {
          line.unitPrice = p.unitPriceForCartQuantity(newQty);
        }
        line.total = newQty * line.unitPrice;
        final pid = line.productId;
        final syncPu = !line.linePriceUserSet;
        final puText = line.unitPrice;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _qtyControllers[pid]?.text =
              newQty == 0 ? '' : newQty.toString();
          if (_puControllers.containsKey(pid) && syncPu) {
            _puControllers[pid]!.text = _puFieldText(puText);
          }
        });
      } else {
        if (stock <= 0) return;
        final pu = p.unitPriceForCartQuantity(1);
        _cart.add(
          PosCartItem(
            productId: p.id,
            name: p.name,
            sku: p.sku,
            unit: _defaultUnitForProduct(p),
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
        _puControllers[productId]?.dispose();
        _puControllers.remove(productId);
      }
    });
    if (newQty != null && _qtyControllers.containsKey(productId)) {
      _qtyControllers[productId]!.text =
          newQty == 0 ? '' : newQty.toString();
      PosCartItem? line;
      try {
        line = _cart.firstWhere((c) => c.productId == productId);
      } catch (_) {
        line = null;
      }
      if (line != null &&
          _puControllers.containsKey(productId) &&
          !line.linePriceUserSet) {
        _puControllers[productId]!.text = _puFieldText(line.unitPrice);
      }
    }
  }

  void _clearQtyControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _qtyControllers.clear();
    for (final c in _puControllers.values) {
      c.dispose();
    }
    _puControllers.clear();
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
      _cart = _cart
          .map((c) {
            if (c.productId != productId) return c;
            c.quantity = clamped;
            if (!c.linePriceUserSet) {
              c.unitPrice = _catalogUnitPrice(productId, clamped);
            }
            c.total = clamped * c.unitPrice;
            return c;
          })
          .toList();
    });
    if (_puControllers.containsKey(productId) && !current.linePriceUserSet) {
      try {
        final after = _cart.firstWhere((c) => c.productId == productId);
        _puControllers[productId]!.text = _puFieldText(after.unitPrice);
      } catch (_) {}
    }
  }

  void _removeCartLine(String productId) {
    setState(() {
      _cart = _cart.where((c) => c.productId != productId).toList();
      _qtyControllers[productId]?.dispose();
      _qtyControllers.remove(productId);
      _puControllers[productId]?.dispose();
      _puControllers.remove(productId);
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
    Uri? uri;
    http.Response? response;
    try {
      uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      if (response.statusCode != 200) {
        AppErrorHandler.logWithContext(
          'Logo HTTP ${response.statusCode}',
          logSource: 'pos_fetch_invoice_logo',
          logContext: {'url_host': uri.host, 'status': response.statusCode},
        );
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'pos_fetch_invoice_logo',
        logContext: {
          'url_host': uri?.host,
          'status': response?.statusCode,
        },
      );
    }
    return null;
  }

  List<CreateSaleItemInput> _cartToSaleItems() {
    return _cart
        .map(
          (c) => CreateSaleItemInput(
            productId: c.productId,
            quantity: c.quantity,
            unitPrice: c.unitPrice,
            discount: (c.quantity * c.unitPrice - c.total).clamp(0.0, double.infinity),
          ),
        )
        .toList();
  }

  Future<void> _bootstrapSaleEdit() async {
    final rawId = widget.editSaleId?.trim() ?? '';
    if (rawId.isEmpty || !mounted) return;
    if (!context.read<PermissionsProvider>().hasPermission(Permissions.salesUpdate)) {
      setState(() {
        _saleEditBarrierError = 'Vous n\'avez pas la permission de modifier des ventes.';
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
          _saleEditBarrierError = 'Cette vente appartient à une autre boutique.';
          _saleEditBootstrapping = false;
        });
        return;
      }
      if (sale.status != SaleStatus.completed) {
        setState(() {
          _saleEditBarrierError = 'Seules les ventes complétées peuvent être modifiées.';
          _saleEditBootstrapping = false;
        });
        return;
      }
      if (!saleOpensOnInvoicePosScreen(sale)) {
        if (!mounted) return;
        context.go('${AppRoutes.posQuick(sale.storeId)}?${saleEditQuery(sale.id)}');
        return;
      }
      final items = sale.saleItems ?? await _salesRepo.getItems(sale.id);
      final payments = sale.salePayments ?? await _salesRepo.getPayments(sale.id);
      if (!mounted) return;
      final release = <String, int>{};
      final cart = <PosCartItem>[];
      for (final item in items) {
        release[item.productId] = (release[item.productId] ?? 0) + item.quantity;
        cart.add(
          PosCartItem(
            productId: item.productId,
            name: item.product?.name ?? 'Produit',
            sku: item.product?.sku,
            unit: _defaultUnitForProduct(
              Product(
                id: item.productId,
                companyId: sale.companyId,
                name: item.product?.name ?? '',
                unit: item.product?.unit ?? 'pce',
                salePrice: item.unitPrice,
                wholesalePrice: 0,
                wholesaleQty: 0,
                isActive: true,
              ),
            ),
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            total: item.total,
            imageUrl: null,
            linePriceUserSet: true,
          ),
        );
      }
      _clearQtyControllers();
      double paySum = 0;
      if (payments.isNotEmpty) {
        paySum = payments.fold<double>(0, (s, p) => s + p.amount);
      }
      setState(() {
        _editStockRelease = release;
        _cart = cart;
        _activeEditSaleId = sale.id;
        _customerId = sale.customerId ?? '';
        _discount = sale.discount;
        _discountController.text = sale.discount > 0 ? '${sale.discount}' : '';
        if (payments.isNotEmpty) {
          _paymentMethod = payments.first.method;
          _paymentMethodNotifier.value = _paymentMethod;
          _amountReceived = paySum.clamp(0, double.infinity);
          _amountReceivedController.text = paySum > 0 ? '$paySum' : '';
        }
        _saleEditBootstrapping = false;
      });
      for (final c in _cart) {
        _qtyControllers[c.productId] = TextEditingController(
          text: c.quantity == 0 ? '' : '${c.quantity}',
        );
        _puControllers[c.productId] = TextEditingController(
          text: _puFieldText(c.unitPrice),
        );
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'pos_bootstrap_sale_edit',
        logContext: {
          'store_id': widget.storeId,
          'edit_sale_id': widget.editSaleId,
        },
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
        creditDueAt: drift.Value(updated.creditDueAt),
        creditInternalNote: drift.Value(updated.creditInternalNote),
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

  Future<void> _afterInvoiceSaleEditSuccess(Sale sale) async {
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    final storeId = widget.storeId;
    final companyId = context.read<CompanyProvider>().currentCompanyId;

    context.read<CompanyProvider>().setCurrentStoreId(storeId);
    context.read<SalesPageProvider>().setFilters(storeId: storeId);
    context.read<SalesPageProvider>().invalidate();
    AppToast.success(
      context,
      'Vente #${sale.saleNumber} mise à jour.',
    );

    if (companyId != null) {
      try {
        await ref.read(salesOfflineRepositoryProvider).upsertSale(sale);
      } catch (e2, st2) {
        AppErrorHandler.logWithContext(
          e2,
          stackTrace: st2,
          logSource: 'pos_mirror_sale_local_edit',
          logContext: {
            'store_id': storeId,
            'company_id': companyId,
            'sale_id': sale.id,
          },
        );
      }
      ref.invalidate(salesStreamProvider((companyId: companyId, storeId: storeId)));
    }
    await ref.read(syncServiceV2Provider).pullInventoryQuantitiesForStores([storeId]);
    ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
    try {
      await _persistLocalAfterSaleUpdate(sale);
    } catch (e3, st3) {
      AppErrorHandler.logWithContext(
        e3,
        stackTrace: st3,
        logSource: 'pos_persist_local_after_sale_update',
        logContext: {
          'store_id': storeId,
          'company_id': companyId,
          'sale_id': sale.id,
        },
      );
    }

    router.go(AppRoutes.sales);
  }

  Future<void> _handlePayment(
    Store? store,
    List<Customer> customers,
    Map<String, int> stockByProductId,
  ) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final userId = context.read<AuthProvider>().user?.id;
    if (companyId == null || userId == null || store == null || !_canPay) {
      return;
    }
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

    if (_activeEditSaleId != null) {
      if (!ConnectivityService.instance.isOnline) {
        AppToast.error(context, 'La modification nécessite une connexion internet.');
        return;
      }
      setState(() => _creating = true);
      try {
        await _salesRepo.updateCompleted(
          saleId: _activeEditSaleId!,
          customerId: _customerId.isEmpty ? null : _customerId,
          items: _cartToSaleItems(),
          payments: _buildPayments(),
          discount: _discount,
          saleMode: SaleMode.invoicePos,
          documentType: DocumentType.a4Invoice,
        );
        final sale = await _salesRepo.get(_activeEditSaleId!);
        if (sale == null) throw Exception('Vente introuvable après mise à jour');
        await _afterInvoiceSaleEditSuccess(sale);
      } catch (e, st) {
        if (mounted) {
          if (shouldRecoverInventoryCachesFromRpcError(e)) {
            recoverStoreInventoryCacheAfterRpcError(ref, widget.storeId, _refreshSync);
          }
          AppErrorHandler.show(
            context,
            e,
            stackTrace: st,
            logSource: 'pos_update_invoice_sale',
            logContext: {
              'store_id': widget.storeId,
              'sale_id': _activeEditSaleId,
            },
          );
        }
      } finally {
        if (mounted) setState(() => _creating = false);
      }
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
        paymentLines:
            InvoiceA4PdfService.paymentLinesFromCreateInputs(payments),
        logoBytes: logoBytesOffline,
      );
      if (!mounted) return;
      setState(() {
        _cart = [];
        _discount = 0;
        _amountReceived = 0;
        _creating = false;
        _lastInvoiceA4Data = invoiceA4Offline;
      });
      _clearQtyControllers();
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
        AppErrorHandler.logWithContext(
          e2,
          stackTrace: st2,
          logSource: 'pos_mirror_sale_local',
          logContext: {
            'store_id': widget.storeId,
            'company_id': companyId,
            'sale_id': sale.id,
          },
        );
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
      final paymentLinesForPdf =
          sale.salePayments != null && sale.salePayments!.isNotEmpty
          ? InvoiceA4PdfService.paymentLinesFromSalePayments(
              sale.salePayments!,
            )
          : InvoiceA4PdfService.paymentLinesFromCreateInputs(payments);
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
        paymentLines: paymentLinesForPdf,
        logoBytes: logoBytes,
      );
      if (!mounted) return;
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
              logSource: 'pos_save_offline_after_network_fail',
              logContext: {
                'store_id': widget.storeId,
                'company_id': companyId,
              },
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
        AppErrorHandler.show(
          context,
          e,
          stackTrace: st,
          logSource: 'pos_create_invoice_sale',
          logContext: {
            'store_id': widget.storeId,
            'company_id': companyId,
          },
        );
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
        appBar: AppBar(
          title: Text(
            widget.invoiceTableLayout ? 'Facture (tableau)' : 'Facture A4',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final saleEditParam = widget.editSaleId?.trim() ?? '';
    final isSaleEditEntry = saleEditParam.isNotEmpty;
    final canInvoiceA4 =
        permissions.hasPermission(Permissions.salesInvoiceA4) ||
        permissions.hasPermission(Permissions.salesCreate);

    if (widget.invoiceTableLayout && !isSaleEditEntry) {
      if (!permissions.hasPermission(Permissions.salesInvoiceA4Table) ||
          !canInvoiceA4) {
        return Scaffold(
          appBar: AppBar(title: const Text('Facture (tableau)')),
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
                    "Vous n'avez pas accès au mode facture tableau / facture A4.",
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
      if (!_invoiceTableSettingLoaded) {
        return Scaffold(
          appBar: AppBar(title: const Text('Facture (tableau)')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Chargement…',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (!_invoiceTableCompanyEnabled) {
        return Scaffold(
          appBar: AppBar(title: const Text('Facture (tableau)')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_rows_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'L’interface facture en tableau est désactivée pour votre entreprise. '
                    'Le propriétaire peut l’activer dans Paramètres.',
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
    }

    if (!isSaleEditEntry && !widget.invoiceTableLayout && !canInvoiceA4) {
      return Scaffold(
        appBar: AppBar(title: const Text('POS Facture A4')),
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

    if (isSaleEditEntry) {
      if (!permissions.hasPermission(Permissions.salesUpdate)) {
        return Scaffold(
          appBar: AppBar(title: const Text('Facture A4')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 64, color: theme.colorScheme.error),
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
                  'Ouverture de la vente en caisse facture…',
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
                widget.invoiceTableLayout
                    ? 'Chargement facture (tableau)…'
                    : 'Chargement Facture A4...',
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

    if (widget.invoiceTableLayout) {
      final screenW = MediaQuery.sizeOf(context).width;
      final pinCategoriesInStrip = screenW < Breakpoints.tablet;

      final strip = Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
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
                _showSelectOrCreateCustomerDialog(
                  theme,
                  customers,
                ),
            onAddToCart: (p) => _addToCart(p, stockByProductId),
            onSearchChanged: (_) => setState(() {}),
            productGridMode: PosMainProductGridMode.twoRowHorizontalStrip,
            onLeavePos: _leavePosToSalesScreen,
            onSyncPressed: _refreshSync,
            pinStripProductArea: pinCategoriesInStrip,
          ),
        ),
      );

      final tableExpanded = Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            screenW >= Breakpoints.desktop ? 16 : 12,
            screenW >= Breakpoints.desktop ? 12 : 10,
            screenW >= Breakpoints.desktop ? 16 : 12,
            screenW >= Breakpoints.desktop ? 16 : 12,
          ),
          child: Builder(
            builder: (_) {
              _ensureQtyControllersForCart();
              return PosCartPanel(
                cartItemCount: _cartItemCount,
                cartTiles: _buildCartTiles(theme, stockByProductId),
                scrollBodyWithFooter: true,
                cartListBody: PosInvoiceTableCart(
                  cart: _cart,
                  effectiveStock: (pid) =>
                      _effectiveStock(pid, stockByProductId),
                  qtyControllers: _qtyControllers,
                  puControllers: _puControllers,
                  onQtyDelta: (productId, delta) => _updateQty(
                    productId,
                    delta,
                    stockByProductId,
                  ),
                  onSetQty: (productId, v) =>
                      _setQty(productId, v, stockByProductId),
                  onSetUnitPrice: _setUnitPrice,
                  onUnitChange: (productId, u) =>
                      _setUnit(productId, u),
                  onRemove: _removeCartLine,
                ),
                footer: _buildCartFooter(
                  theme,
                  store,
                  customers,
                  stockByProductId,
                ),
              );
            },
          ),
        ),
      );

      final banners = <Widget>[
        if (_activeEditSaleId != null) _buildSaleEditModeBanner(theme),
        if (!isOnline) _buildOfflineBanner(),
      ];

      // Toujours : bandeau produits borné (cible ~11 %, max 32 % de la hauteur utile) + scroll
      // interne — évite le bandeau « intrinsèque » plus grand que la zone tableau (PC < 1400 px).
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...banners,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sw = MediaQuery.sizeOf(context).width;
                    var stripH = Breakpoints.factureTabStripHeight(
                      constraints.maxHeight,
                      width: sw,
                    );
                    if (pinCategoriesInStrip) {
                      // Ultra mobile : recherche + client + catégories ; la grille strip est en **1 rangée**
                      // ([PosProductTwoRowHorizontalStrip]) — plancher pour garder des tuiles lisibles.
                      stripH = max(stripH, 318.0);
                      stripH = min(stripH, constraints.maxHeight * 0.58);
                    } else if (sw >= Breakpoints.tablet && sw < Breakpoints.shellDesktop) {
                      // Tablette uniquement (≥ 600 et \< 1024) : 2 rangées produits, un peu plus de hauteur.
                      stripH = max(stripH, 288.0);
                      stripH = min(stripH, constraints.maxHeight * 0.52);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: stripH,
                          child: ClipRect(
                            child: pinCategoriesInStrip
                                ? strip
                                : SingleChildScrollView(
                                    clipBehavior: Clip.hardEdge,
                                    physics: const ClampingScrollPhysics(),
                                    child: strip,
                                  ),
                          ),
                        ),
                        tableExpanded,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hidePosOrangeBar =
        MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        top: hidePosOrangeBar,
        child: Column(
          children: [
            if (!hidePosOrangeBar) _buildPosHeader(store!),
            if (_activeEditSaleId != null) _buildSaleEditModeBanner(theme),
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
        stock: _effectiveStock(c.productId, stockByProductId),
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
                    .withValues(alpha: 0.5),
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
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                : (_activeEditSaleId != null
                    ? 'Enregistrer la modification'
                    : 'Payer (${_labelForPayment(effectivePayment)})'),
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
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
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
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '$_cartItemCount article${_cartItemCount != 1 ? 's' : ''} · ${formatCurrency(_total)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
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
    _paymentMethodNotifier.value = _paymentMethod;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        final sheetCs = sheetTheme.colorScheme;
        return Container(
        height: MediaQuery.sizeOf(sheetContext).height * 0.85,
        decoration: BoxDecoration(
          color: sheetCs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: sheetCs.shadow.withValues(alpha: 0.2),
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
                        'Articles ($_cartItemCount)',
                        style: sheetTheme.textTheme.bodyLarge?.copyWith(
                          color: sheetCs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Panier',
                        style: sheetTheme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: sheetCs.onSurface,
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
                            style: sheetTheme.textTheme.bodyLarge?.copyWith(
                              color: sheetCs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      if (widget.invoiceTableLayout)
                        Builder(
                          builder: (_) {
                            _ensureQtyControllersForCart();
                            return PosInvoiceTableCart(
                              cart: _cart,
                              effectiveStock: (pid) =>
                                  _effectiveStock(pid, stockByProductId),
                              qtyControllers: _qtyControllers,
                              puControllers: _puControllers,
                              onQtyDelta: (productId, delta) => _updateQty(
                                productId,
                                delta,
                                stockByProductId,
                              ),
                              onSetQty: (productId, v) =>
                                  _setQty(productId, v, stockByProductId),
                              onSetUnitPrice: _setUnitPrice,
                              onUnitChange: (productId, u) =>
                                  _setUnit(productId, u),
                              onRemove: _removeCartLine,
                            );
                          },
                        )
                      else
                        ..._buildCartTiles(sheetTheme, stockByProductId),
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        color: sheetTheme.dividerColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Récapitulatif et paiement',
                        style: sheetTheme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PosQuickColors.orangePrincipal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<PaymentMethod>(
                        valueListenable: _paymentMethodNotifier,
                        builder: (_, pm, _) => _buildCartFooter(
                          sheetTheme,
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
      );
    },
    ).then((_) {});
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
              Icon(Icons.edit_note_rounded, color: theme.colorScheme.onPrimaryContainer, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modification d\'une vente (facture A4). Enregistrez pour appliquer — connexion requise.',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(
                  widget.invoiceTableLayout
                      ? AppRoutes.factureTab(widget.storeId)
                      : AppRoutes.pos(widget.storeId),
                ),
                child: Text('Quitter', style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
              ),
            ],
          ),
        ),
      ),
    );
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
                      Text(
                        widget.invoiceTableLayout ? 'Facture (tableau)' : 'POS Facture A4',
                        style: const TextStyle(
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
                Text(
                  widget.invoiceTableLayout ? 'Facture (tableau)' : 'POS Facture A4',
                  style: const TextStyle(
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
                } catch (e, st) {
                  if (ctx.mounted) {
                    AppErrorHandler.show(
                      ctx,
                      e,
                      fallback: 'Impossible d\'afficher la facture PDF.',
                      stackTrace: st,
                      logSource: 'pos_pdf_preview_build',
                    );
                  }
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
                      InvoiceA4PdfService.printPdfDirect(
                        invoiceA4,
                        userId: context.read<AuthProvider>().user?.id,
                        companyId:
                            context.read<CompanyProvider>().currentCompanyId,
                      ).then(
                        (_) {
                          if (mounted) {
                            AppToast.success(
                              context,
                              'Impression envoyée à l’imprimante.',
                            );
                          }
                        },
                        onError: (Object e, StackTrace st) {
                          if (mounted) {
                            AppErrorHandler.show(
                              context,
                              e,
                              fallback: 'Impossible d’imprimer la facture.',
                              stackTrace: st,
                              logSource: 'pos_invoice_print',
                            );
                          }
                        },
                      ),
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
                    } catch (e, st) {
                      if (ctx.mounted) {
                        AppErrorHandler.show(
                          ctx,
                          e,
                          fallback: 'Impossible de télécharger la facture.',
                          stackTrace: st,
                          logSource: 'pos_invoice_download',
                        );
                      }
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
