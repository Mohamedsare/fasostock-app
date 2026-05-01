import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/local/drift/app_database.dart';
import '../../data/models/category.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/repositories/customers_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../shared/utils/format_currency.dart';
import '../pos/pos_models.dart';
import '../pos/widgets/pos_cart_panel.dart';
import '../pos/widgets/pos_invoice_table_cart.dart';
import '../pos/widgets/pos_main_area.dart'
    show PosMainArea, PosMainProductGridMode;
import '../pos_quick/pos_quick_constants.dart';
import 'warehouse_ui_helpers.dart';

/// Hauteur intrinsèque du bandeau facture-tab (recherche + client + catégories + 2 rangées produits).
/// Si la zone allouée est plus petite, un scroll vertical interne est nécessaire (miniatures qui « partent »).
const double _kFactureStripContentIdealHeight = 458.0;

/// Sortie du dépôt avec bon — même disposition que le POS **Facture A4 (tableau)**.
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

class _WarehouseDispatchInvoiceDialogState
    extends ConsumerState<WarehouseDispatchInvoiceDialog> {
  static const String _dispatchPaymentNotePrefix = '__PAYMENT_INFO__:';
  final CustomersRepository _customersRepo = CustomersRepository();
  final TextEditingController _searchController = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<PosCartItem> _cart = [];
  String _customerId = '';
  String? _selectedCategoryId;
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _puControllers = {};

  final List<Customer> _pendingCustomers = [];

  bool _saving = false;
  bool _creatingCustomer = false;
  DateTime? _lastStockLimitToastAt;
  _DispatchPaymentMode? _paymentMode;
  String _cashPaidDraft = '';
  _DispatchMobileProvider? _mobileProvider;

  List<Product> get _activeProducts =>
      widget.products
          .where((p) => p.isActive && p.isAvailableInWarehouse)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Customer> get _customers =>
      ref.watch(customersStreamProvider(widget.companyId)).valueOrNull ?? [];

  List<Category> get _categories =>
      ref.watch(categoriesStreamProvider(widget.companyId)).valueOrNull ?? [];

  List<Customer> get _sortedCustomers {
    final list = List<Customer>.from(_customers);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Stream + clients créés localement dans cette session.
  List<Customer> get _customersForUi {
    final base = _sortedCustomers;
    final ids = {for (final c in base) c.id};
    final extra = _pendingCustomers.where((c) => !ids.contains(c.id));
    return [...base, ...extra];
  }

  int get _cartItemCount => _cart.fold(0, (n, c) => n + c.quantity);

  double get _grandTotal => _cart.fold(0.0, (s, c) => s + c.total);

  int _effectiveStock(String productId) =>
      widget.warehouseQuantities[productId] ?? 0;

  bool _isProductShownInWarehouse(Product p) {
    if (!p.isActive) return false;
    if (!p.isAvailableInWarehouse) return false;
    return _effectiveStock(p.id) > 0;
  }

  List<Product> _filteredProducts(Map<String, int> stockByProductId) {
    final search = _searchController.text.trim().toLowerCase();
    return _activeProducts.where((p) {
      if (!_isProductShownInWarehouse(p)) return false;
      final stock = stockByProductId[p.id] ?? 0;
      if (stock <= 0) return false;
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

  static String _puFieldText(double unitPrice) => '${unitPrice.round()}';

  static String _defaultUnitForProduct(Product p) {
    final u = (p.unit).trim().toLowerCase();
    if (u.isEmpty) return 'pce';
    if (kInvoiceUnits.any((x) => x.toLowerCase() == u)) {
      return kInvoiceUnits.firstWhere((x) => x.toLowerCase() == u);
    }
    return 'pce';
  }

  void _ensureQtyControllersForCart() {
    for (final c in _cart) {
      _qtyControllers.putIfAbsent(
        c.productId,
        () =>
            TextEditingController(text: c.quantity == 0 ? '' : '${c.quantity}'),
      );
      _puControllers.putIfAbsent(
        c.productId,
        () => TextEditingController(text: _puFieldText(c.unitPrice)),
      );
    }
  }

  void _clearCartControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _qtyControllers.clear();
    for (final c in _puControllers.values) {
      c.dispose();
    }
    _puControllers.clear();
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
          c.total = (c.quantity * c.unitPrice).roundToDouble();
          break;
        }
      }
    });
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
          _qtyControllers[pid]?.text = newQty == 0 ? '' : '$newQty';
        });
      } else {
        if (stock <= 0) return;
        _cart.add(
          PosCartItem(
            productId: p.id,
            name: p.name,
            sku: p.sku,
            unit: _defaultUnitForProduct(p),
            quantity: 1,
            unitPrice: p.salePrice,
            total: p.salePrice,
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
      if (_cart.length < beforeLen) {
        _qtyControllers[productId]?.dispose();
        _qtyControllers.remove(productId);
        _puControllers[productId]?.dispose();
        _puControllers.remove(productId);
      }
    });
    if (newQty != null && _qtyControllers.containsKey(productId)) {
      _qtyControllers[productId]!.text = newQty == 0 ? '' : '$newQty';
    }
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
          : '${current.quantity}';
      return;
    }

    final clamped = requested;
    setState(() {
      _cart = _cart.map((c) {
        if (c.productId != productId) return c;
        c.quantity = clamped;
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
    AppToast.info(context, 'Quantité ajustée au stock disponible au dépôt.');
  }

  /// Après [Navigator.pop] d’un dialogue, l’overlay peut encore être en phase de layout ;
  /// un [setState] immédiat déclenche souvent `!_skipMarkNeedsLayout` dans `overlay.dart`.
  Future<void> _waitForOverlayToSettle() async {
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<void> _syncAfterCustomerChange() async {
    try {
      final auth = context.read<AuthProvider>();
      final company = context.read<CompanyProvider>();
      final uid = auth.user?.id;
      if (uid == null) return;
      await ref
          .read(syncServiceV2Provider)
          .sync(
            userId: uid,
            companyId: company.currentCompanyId ?? widget.companyId,
            storeId: null,
          );
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_invoice_sync_after_customer', e, st);
    }
  }

  Future<void> _showSelectCustomerDialog() async {
    final theme = Theme.of(context);
    final customers = _customersForUi;
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
                        if (!mounted) return;
                        setState(() => _customerId = customerId);
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
                      if (!mounted) return;
                      _openCreateCustomerDialog();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateCustomerDialog() async {
    final result = await showDialog<_NewCustomerResult?>(
      context: context,
      builder: (ctx) => const _NewCustomerDialog(),
    );
    if (result == null || !mounted) return;
    await _waitForOverlayToSettle();
    if (!mounted) return;
    await _createCustomer(name: result.name, phone: result.phone);
  }

  Future<void> _createCustomer({required String name, String? phone}) async {
    await _waitForOverlayToSettle();
    if (!mounted) return;
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
        setState(() {
          _pendingCustomers.add(pending);
          _customerId = pending.id;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppToast.success(
            context,
            'Client enregistré. Il sera envoyé à la reconnexion.',
          );
        });
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
      setState(() {
        _pendingCustomers.add(created);
        _customerId = created.id;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppToast.success(
          context,
          'Client ajouté. Vous pouvez continuer le bon.',
        );
      });
      Future.microtask(_syncAfterCustomerChange);
      return;
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_invoice_create_customer', e, st);
      final shouldFallbackOffline =
          ErrorMapper.isNetworkError(e) ||
          !ConnectivityService.instance.isOnline;
      if (shouldFallbackOffline) {
        try {
          final companyId = widget.companyId;
          final db = ref.read(appDatabaseProvider);
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
          if (mounted) {
            setState(() {
              _pendingCustomers.add(pending);
              _customerId = pending.id;
            });
            AppToast.success(
              context,
              'Réseau indisponible: client enregistré localement et synchronisé à la reconnexion.',
            );
            Future.microtask(_syncAfterCustomerChange);
          }
          return;
        } catch (e2, st2) {
          WarehouseUi.logOp(
            'dispatch_invoice_create_customer_offline_fallback',
            e2,
            st2,
          );
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppErrorHandler.show(context, e);
      });
    } finally {
      if (mounted) setState(() => _creatingCustomer = false);
    }
  }

  void _resetDispatchForm() {
    _clearCartControllers();
    _cart = [];
    _notesCtrl.clear();
    _customerId = '';
    _paymentMode = null;
    _cashPaidDraft = '';
    _mobileProvider = null;
    _selectedCategoryId = null;
    _searchController.clear();
  }

  Customer? _resolveCustomer() {
    try {
      return _customersForUi.firstWhere((c) => c.id == _customerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final customer = _resolveCustomer();
    if (customer == null || _customerId.trim().isEmpty) {
      AppToast.info(
        context,
        'Choisissez d’abord la personne ou le client qui reçoit la marchandise.',
      );
      return;
    }
    if (_cart.isEmpty) {
      AppToast.info(context, 'Ajoutez au moins un article depuis le bandeau.');
      return;
    }
    if (_paymentMode == null) {
      AppToast.info(
        context,
        'Choisissez d\'abord un mode de paiement (Espèces, Mobile money, Carte ou À crédit).',
      );
      return;
    }

    final inputs = <WarehouseDispatchLineInput>[];
    final productById = {for (final p in widget.products) p.id: p};
    for (final line in _cart) {
      final p = productById[line.productId];
      if (p == null) {
        AppToast.info(context, 'Article inconnu dans le catalogue.');
        return;
      }
      final qty = line.quantity;
      if (qty <= 0) {
        AppToast.info(
          context,
          'Indiquez une quantité correcte pour chaque article.',
        );
        return;
      }
      final price = line.unitPrice;
      if (price < 0) {
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
      inputs.add(
        WarehouseDispatchLineInput(
          productId: p.id,
          quantity: qty,
          unitPrice: price,
        ),
      );
    }

    var paidAmount = 0.0;
    if (_paymentMode == _DispatchPaymentMode.cash) {
      final raw = _cashPaidDraft.trim();
      if (raw.isEmpty) {
        AppToast.info(
          context,
          'Indiquez le montant reçu en espèces. Vous pouvez saisir un montant partiel ou complet.',
        );
        return;
      }
      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        AppToast.info(
          context,
          'Montant espèces invalide. Entrez un nombre valide (ex: 5000).',
        );
        return;
      }
      paidAmount = parsed > _grandTotal ? _grandTotal : parsed;
      if (parsed > _grandTotal) {
        AppToast.info(
          context,
          'Montant espèces ajusté au total de la facture.',
        );
      }
    } else if (_paymentMode == _DispatchPaymentMode.mobileMoney ||
        _paymentMode == _DispatchPaymentMode.card) {
      if (_paymentMode == _DispatchPaymentMode.mobileMoney &&
          _mobileProvider == null) {
        AppToast.info(
          context,
          'Choisissez l\'opérateur Mobile money (Orange Money, Moov Money ou Wave).',
        );
        return;
      }
      paidAmount = _grandTotal;
    } else {
      paidAmount = 0;
    }

    final paymentInfo = <String, dynamic>{
      'mode': _paymentMode!.value,
      'paid_amount': paidAmount.round(),
      'mobile_provider': _paymentMode == _DispatchPaymentMode.mobileMoney
          ? _mobileProvider!.value
          : null,
    };

    setState(() => _saving = true);
    try {
      final customerPendingSync = customer.id.startsWith('pending:');
      final canEnqueueOffline = widget.onOfflineEnqueue != null;
      if ((customerPendingSync || !ConnectivityService.instance.isOnline) &&
          canEnqueueOffline) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'customer_id': customer.id,
          'notes': '$_dispatchPaymentNotePrefix${jsonEncode(paymentInfo)}',
          'lines': inputs.map((e) => e.toJson()).toList(),
        });
        if (mounted) {
          AppToast.success(
            context,
            customerPendingSync
                ? 'Client en attente de synchronisation: bon enregistré localement.'
                : 'Enregistré. Envoi dès que la connexion revient.',
          );
          await widget.onSuccess();
          if (!mounted) return;
          setState(() {
            _saving = false;
            _resetDispatchForm();
          });
        }
        return;
      }
      final res = await widget.warehouseRepo.createDispatchInvoice(
        companyId: widget.companyId,
        customerId: customer.id,
        notes: '$_dispatchPaymentNotePrefix${jsonEncode(paymentInfo)}',
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
          'customer_id': customer.id,
          'notes': '$_dispatchPaymentNotePrefix${jsonEncode(paymentInfo)}',
          'lines': inputs.map((e) => e.toJson()).toList(),
        });
        if (mounted) {
          AppToast.success(
            context,
            'Enregistré. Envoi dès que la connexion revient.',
          );
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
    _searchController.dispose();
    _notesCtrl.dispose();
    _clearCartControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stockByProductId = widget.warehouseQuantities;
    final filtered = _filteredProducts(stockByProductId);
    final hasCustomers = _customersForUi.isNotEmpty;
    final canSubmit =
        !_saving &&
        !_creatingCustomer &&
        hasCustomers &&
        _customerId.isNotEmpty &&
        _paymentMode != null &&
        _cart.isNotEmpty;

    _ensureQtyControllersForCart();

    final maxH = MediaQuery.sizeOf(context).height * 0.94;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    final strip = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: PosMainArea(
          searchController: _searchController,
          customerId: _customerId,
          customers: _customersForUi,
          filteredProducts: filtered,
          stockByProductId: stockByProductId,
          categories: _categories,
          selectedCategoryId: _selectedCategoryId,
          onCustomerIdChanged: (v) => setState(() => _customerId = v ?? ''),
          onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
          onCreateCustomer: () {
            if (_saving || _creatingCustomer) return;
            _openCreateCustomerDialog();
          },
          onSelectOrCreateCustomer: () {
            if (_saving || _creatingCustomer) return;
            _showSelectCustomerDialog();
          },
          onAddToCart: (p) => _addToCart(p, stockByProductId),
          onSearchChanged: (_) => setState(() {}),
          productGridMode: PosMainProductGridMode.twoRowHorizontalStrip,
          onLeavePos: () => Navigator.pop(context),
          leavePosTooltip: 'Fermer',
          showCustomerRow: true,
        ),
      ),
    );

    final tablePanel = Expanded(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wide ? 16 : 12,
          wide ? 12 : 10,
          wide ? 16 : 12,
          wide ? 16 : 12,
        ),
        child: PosCartPanel(
          panelTitleOverride: 'Facture / sortie dépôt',
          cartItemCount: _cartItemCount,
          cartTiles: const [],
          scrollBodyWithFooter: true,
          cartListBody: _cart.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: Center(
                    child: Text(
                      'Ajoutez des produits depuis le bandeau ci‑dessus.\n'
                      'Les lignes s’affichent en tableau comme sur la caisse « Facture tab. ».',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              : PosInvoiceTableCart(
                  cart: _cart,
                  effectiveStock: (pid) => stockByProductId[pid] ?? 0,
                  qtyControllers: _qtyControllers,
                  puControllers: _puControllers,
                  onQtyDelta: (productId, delta) =>
                      _updateQty(productId, delta, stockByProductId),
                  onSetQty: (productId, v) =>
                      _setQty(productId, v, stockByProductId),
                  onSetUnitPrice: _setUnitPrice,
                  onUnitChange: _setUnit,
                  onRemove: _removeCartLine,
                ),
          footer: _dispatchFooter(hasCustomers, canSubmit),
        ),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1200 : 640,
          maxHeight: maxH,
        ),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sw = MediaQuery.sizeOf(context).width;
                    final stripH = Breakpoints.factureTabStripHeight(
                      constraints.maxHeight,
                      width: sw,
                    );
                    // Laisser assez de place au bandeau pour éviter un scroll vertical
                    // qui fait disparaître les miniatures quand l’écran le permet.
                    // Moitié bandeau / moitié tableau (zone utile sous le dialogue).
                    final maxStripAlloc = (constraints.maxHeight * 0.5).clamp(
                      200.0,
                      constraints.maxHeight,
                    );
                    final targetStripH = math.max(
                      stripH,
                      math.min(_kFactureStripContentIdealHeight, maxStripAlloc),
                    );
                    // Scroll vertical seulement si le bandeau complet ne tient pas (évite le « clignotement » des vignettes).
                    final needsVerticalStripScroll =
                        targetStripH < _kFactureStripContentIdealHeight - 4;
                    final stripHost = needsVerticalStripScroll
                        ? ClipRect(
                            child: SingleChildScrollView(
                              clipBehavior: Clip.hardEdge,
                              physics: const ClampingScrollPhysics(),
                              child: strip,
                            ),
                          )
                        : strip;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: targetStripH, child: stripHost),
                        tablePanel,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dispatchFooter(bool hasCustomers, bool canSubmit) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _notesCtrl,
                enabled: !_saving,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (facultatif)',
                  hintText: 'Motif de sortie, précisions…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mode de paiement',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _paymentChip(_DispatchPaymentMode.cash, 'Espèces'),
                  _paymentChip(
                    _DispatchPaymentMode.mobileMoney,
                    'Mobile money',
                  ),
                  _paymentChip(_DispatchPaymentMode.card, 'Carte'),
                  _paymentChip(_DispatchPaymentMode.credit, 'À crédit'),
                ],
              ),
              if (_paymentMode == _DispatchPaymentMode.cash) ...[
                const SizedBox(height: 8),
                TextField(
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => setState(() => _cashPaidDraft = v),
                  decoration: InputDecoration(
                    labelText: 'Montant reçu (espèces)',
                    hintText: '0 à ${_grandTotal.round()}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vous pouvez saisir un montant partiel ou complet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_paymentMode == _DispatchPaymentMode.mobileMoney) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _providerChip(
                      _DispatchMobileProvider.orangeMoney,
                      'Orange Money',
                    ),
                    _providerChip(
                      _DispatchMobileProvider.moovMoney,
                      'Moov Money',
                    ),
                    _providerChip(_DispatchMobileProvider.wave, 'Wave'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
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
                        !hasCustomers
                            ? 'Ajoutez d’abord un client'
                            : _paymentMode == null
                            ? 'Choisissez le mode de paiement'
                            : _cart.isEmpty
                            ? 'Ajoutez des articles'
                            : _customerId.isEmpty
                            ? 'Choisissez le client (bandeau)'
                            : 'Enregistrer le bon de sortie',
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

  Widget _paymentChip(_DispatchPaymentMode mode, String label) {
    final selected = _paymentMode == mode;
    final enabled = !_saving;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected
              ? Colors.white
              : (enabled ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF)),
        ),
      ),
      selected: selected,
      selectedColor: PosQuickColors.orangePrincipal,
      backgroundColor: const Color(0xFFF3F4F6),
      side: BorderSide(
        color: selected
            ? PosQuickColors.orangePrincipal
            : const Color(0xFFD1D5DB),
      ),
      onSelected: _saving
          ? null
          : (_) => setState(() {
              _paymentMode = mode;
              if (mode != _DispatchPaymentMode.cash) _cashPaidDraft = '';
              if (mode != _DispatchPaymentMode.mobileMoney) {
                _mobileProvider = null;
              }
            }),
      showCheckmark: false,
    );
  }

  Widget _providerChip(_DispatchMobileProvider p, String label) {
    final selected = _mobileProvider == p;
    final enabled = !_saving;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected
              ? Colors.white
              : (enabled ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF)),
        ),
      ),
      selected: selected,
      selectedColor: PosQuickColors.orangePrincipal,
      backgroundColor: const Color(0xFFF3F4F6),
      side: BorderSide(
        color: selected
            ? PosQuickColors.orangePrincipal
            : const Color(0xFFD1D5DB),
      ),
      onSelected: _saving ? null : (_) => setState(() => _mobileProvider = p),
      showCheckmark: false,
    );
  }
}

enum _DispatchPaymentMode { cash, mobileMoney, card, credit }

extension on _DispatchPaymentMode {
  String get value => switch (this) {
    _DispatchPaymentMode.cash => 'cash',
    _DispatchPaymentMode.mobileMoney => 'mobile_money',
    _DispatchPaymentMode.card => 'card',
    _DispatchPaymentMode.credit => 'credit',
  };
}

enum _DispatchMobileProvider { orangeMoney, moovMoney, wave }

extension on _DispatchMobileProvider {
  String get value => switch (this) {
    _DispatchMobileProvider.orangeMoney => 'orange_money',
    _DispatchMobileProvider.moovMoney => 'moov_money',
    _DispatchMobileProvider.wave => 'wave',
  };
}

/// Données renvoyées par [_NewCustomerDialog] ; les [TextEditingController] y sont gérés
/// dans l’état du dialogue pour éviter toute utilisation après [dispose].
class _NewCustomerResult {
  const _NewCustomerResult({required this.name, this.phone});
  final String name;
  final String? phone;
}

class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Nouveau client'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Renseignez au minimum le nom. Le téléphone aide à le retrouver.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex. : Amadou Diallo',
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Au moins 2 lettres'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(
                context,
                _NewCustomerResult(
                  name: _nameCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim().isEmpty
                      ? null
                      : _phoneCtrl.text.trim(),
                ),
              );
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
