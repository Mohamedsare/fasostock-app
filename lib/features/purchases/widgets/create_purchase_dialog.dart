import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/models/product.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/purchases_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../shared/utils/format_currency.dart';

/// Ligne du formulaire (produit, quantité, prix unitaire).
class _LineRow {
  String productId = '';
  String productName = '';
  String unit = 'pce';
  int quantity = 0;
  double unitPrice = 0;
  double get lineTotal => quantity * unitPrice;
}

/// Dialog de création d'achat — boutique, fournisseur, référence, lignes, paiement optionnel.
class CreatePurchaseDialog extends ConsumerStatefulWidget {
  const CreatePurchaseDialog({
    super.key,
    required this.companyId,
    required this.stores,
    required this.suppliers,
    required this.onSuccess,
    this.initialStoreId,
  });

  final String companyId;
  final List<Store> stores;
  final List<Supplier> suppliers;
  final void Function(Purchase purchase) onSuccess;
  final String? initialStoreId;

  @override
  ConsumerState<CreatePurchaseDialog> createState() => _CreatePurchaseDialogState();
}

class _CreatePurchaseDialogState extends ConsumerState<CreatePurchaseDialog> {
  final PurchasesRepository _purchasesRepo = PurchasesRepository();

  List<Store> get _stores => widget.stores;
  List<Supplier> get _suppliers => widget.suppliers;

  String? _storeId;
  String? _supplierId;
  final TextEditingController _referenceController = TextEditingController();
  List<_LineRow> _lines = [];
  PaymentMethod _paymentMethod = PaymentMethod.transfer;
  final TextEditingController _paymentAmountController = TextEditingController(text: '0');

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Valeur initiale boutique : doit être dans la liste sinon le dropdown peut planter ou ne pas mettre à jour.
    final storeIds = _stores.map((s) => s.id).toSet();
    if (widget.initialStoreId != null && storeIds.contains(widget.initialStoreId)) {
      _storeId = widget.initialStoreId;
    } else {
      _storeId = _stores.isNotEmpty ? _stores.first.id : null;
    }
    _lines = [_LineRow()];
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_LineRow()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index));
  }

  void _updateLineProduct(int index, String? productId, List<Product> products) {
    if (productId == null || productId.isEmpty) {
      setState(() {
        _lines[index].productId = '';
        _lines[index].productName = '';
        _lines[index].unit = 'pce';
        _lines[index].unitPrice = 0;
      });
      return;
    }
    Product? p;
    for (final x in products) {
      if (x.id == productId) {
        p = x;
        break;
      }
    }
    if (p != null) {
      final product = p;
      setState(() {
        _lines[index].productId = product.id;
        _lines[index].productName = product.name;
        _lines[index].unit = product.unit;
        _lines[index].unitPrice = product.purchasePrice;
      });
    }
  }

  void _updateLineQty(int index, int value) {
    setState(() => _lines[index].quantity = value.clamp(0, 999999));
  }

  void _updateLineUnitPrice(int index, double value) {
    setState(() => _lines[index].unitPrice = value.clamp(0, double.infinity));
  }

  double get _total {
    return _lines.fold<double>(0, (s, l) => s + l.lineTotal);
  }

  bool get _canSubmit {
    if (_effectiveStoreId == null || _effectiveStoreId!.isEmpty) return false;
    if (_supplierId == null || _supplierId!.isEmpty) return false;
    return _lines.any((l) => l.productId.isNotEmpty && l.quantity > 0 && l.unitPrice >= 0);
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      AppToast.info(context, 'Sélectionnez une boutique, un fournisseur et au moins un article.');
      return;
    }
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      AppToast.info(context, 'Session expirée. Reconnectez-vous.');
      return;
    }
    setState(() => _saving = true);
    try {
      final items = _lines
          .where((l) => l.productId.isNotEmpty && l.quantity > 0 && l.unitPrice >= 0)
          .map((l) => CreatePurchaseItemInput(productId: l.productId, quantity: l.quantity, unitPrice: l.unitPrice))
          .toList();
      if (items.isEmpty) {
        AppToast.info(context, 'Ajoutez au moins un article avec quantité et prix.');
        setState(() => _saving = false);
        return;
      }
      final ref = _referenceController.text.trim();
      final paymentAmount = double.tryParse(_paymentAmountController.text.replaceAll(',', '.')) ?? 0;
      final payments = paymentAmount > 0
          ? [CreatePurchasePaymentInput(method: _paymentMethod, amount: paymentAmount)]
          : null;

      final input = CreatePurchaseInput(
        companyId: widget.companyId,
        storeId: _effectiveStoreId!,
        supplierId: _supplierId!,
        reference: ref.isEmpty ? null : ref,
        items: items,
        payments: payments,
      );
      final purchase = await _purchasesRepo.create(input, userId);
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSuccess(purchase);
      Navigator.of(context).pop();
      AppToast.success(context, 'Achat créé (brouillon)');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppErrorHandler.show(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = Breakpoints.isNarrow(MediaQuery.sizeOf(context).width);
    final productsAsync = ref.watch(productsStreamProvider(widget.companyId));
    final products =
        (productsAsync.valueOrNull ?? []).where((p) => p.isActive && p.isAvailableInBoutiqueStock).toList();
    final productsLoading = productsAsync.isLoading;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_shopping_cart_rounded),
          SizedBox(width: 10),
          Text('Nouvel achat'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: narrow ? null : 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (productsAsync.hasError) ...[
                Text(
                  AppErrorHandler.toUserMessage(productsAsync.error),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (narrow) ...[_dropdownStore(theme), const SizedBox(height: 12), _dropdownSupplier(theme)]
              else
                Row(
                  children: [
                    Expanded(child: _dropdownStore(theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _dropdownSupplier(theme)),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence (optionnel)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Articles', style: theme.textTheme.titleSmall),
                  if (productsLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('Chargement…', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                  itemBuilder: (context, i) => _buildLineRow(theme, i, products),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodField(
                      value: _paymentMethod,
                      onTap: _openPaymentMethodPicker,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _paymentAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Montant',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(formatCurrency(_total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving || !_canSubmit ? null : _submit,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer (brouillon)'),
        ),
      ],
    );
  }

  String? get _effectiveStoreId {
    if (_storeId == null) return null;
    if (_stores.any((s) => s.id == _storeId)) return _storeId;
    return _stores.isNotEmpty ? _stores.first.id : null;
  }

  void _openPaymentMethodPicker() {
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PaymentMethodPickerSheet(
        selected: _paymentMethod,
        onSelect: (v) {
          setState(() => _paymentMethod = v);
          Navigator.of(ctx).pop();
        },
        compactTiles: isMobile,
      ),
    );
  }

  Widget _dropdownStore(ThemeData theme) {
    return DropdownButtonFormField<String?>(
      initialValue: _effectiveStoreId,
      decoration: InputDecoration(
        labelText: 'Boutique *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ..._stores.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) {
        setState(() => _storeId = v);
      },
    );
  }

  Widget _dropdownSupplier(ThemeData theme) {
    final effectiveSupplierId = _supplierId != null && _suppliers.any((s) => s.id == _supplierId) ? _supplierId : null;
    return DropdownButtonFormField<String?>(
      initialValue: effectiveSupplierId,
      decoration: InputDecoration(
        labelText: 'Fournisseur *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      menuMaxHeight: 300,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ..._suppliers.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) {
        setState(() => _supplierId = v);
      },
    );
  }

  Widget _buildLineRow(ThemeData theme, int index, List<Product> products) {
    final line = _lines[index];
    final productItems = [
      const DropdownMenuItem<String?>(value: null, child: Text('Produit')),
      ...products.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String?>(
              initialValue: line.productId.isEmpty ? null : line.productId,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              isExpanded: true,
              items: productItems,
              onChanged: (v) => _updateLineProduct(index, v ?? '', products),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: line.quantity == 0 ? '' : line.quantity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Qté',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _updateLineQty(index, int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: line.unitPrice == 0 ? '' : line.unitPrice.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix unit.',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _updateLineUnitPrice(index, double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(formatCurrency(line.lineTotal), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
            onPressed: _lines.length > 1 ? () => _removeLine(index) : null,
            tooltip: 'Supprimer la ligne',
          ),
        ],
      ),
    );
  }
}

/// Champ « Paiement » : tap ouvre un bottom sheet (ultra mobile).
class _PaymentMethodField extends StatelessWidget {
  const _PaymentMethodField({
    required this.value,
    required this.onTap,
  });

  final PaymentMethod value;
  final VoidCallback onTap;

  static String _label(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return 'Espèces';
      case PaymentMethod.transfer: return 'Virement';
      case PaymentMethod.mobile_money: return 'Mobile money';
      case PaymentMethod.card: return 'Carte';
      case PaymentMethod.other: return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Paiement',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          _label(value),
          style: theme.textTheme.bodyLarge,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Bottom sheet : choix du mode de paiement (zones tactiles adaptées mobile).
class _PaymentMethodPickerSheet extends StatelessWidget {
  const _PaymentMethodPickerSheet({
    required this.selected,
    required this.onSelect,
    this.compactTiles = false,
  });

  final PaymentMethod selected;
  final void Function(PaymentMethod) onSelect;
  final bool compactTiles;

  static const List<PaymentMethod> _methods = [
    PaymentMethod.cash,
    PaymentMethod.transfer,
    PaymentMethod.mobile_money,
    PaymentMethod.card,
    PaymentMethod.other,
  ];

  static String _label(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return 'Espèces';
      case PaymentMethod.transfer: return 'Virement';
      case PaymentMethod.mobile_money: return 'Mobile money';
      case PaymentMethod.card: return 'Carte';
      case PaymentMethod.other: return 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Mode de paiement',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            ..._methods.map((m) {
              final isSelected = m == selected;
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compactTiles ? 12 : 8,
                ),
                minVerticalPadding: compactTiles ? 14 : 0,
                leading: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.payment_rounded,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                title: Text(_label(m), style: theme.textTheme.bodyLarge),
                onTap: () => onSelect(m),
              );
            }),
          ],
        ),
      ),
    );
  }
}
