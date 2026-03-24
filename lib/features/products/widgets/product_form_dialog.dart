import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/breakpoints.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../data/models/brand.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/repositories/products_repository.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../../data/models/product_image.dart';

const _units = [
  'pce',
  'kg',
  'L',
  'm',
  'm²',
  'lot',
  'paquet',
  'carton',
  'boîte',
  'sachet',
];

/// Unités proposées + unité issue du produit si elle est hors liste (import, ancienne donnée).
List<String> _unitChoices(String current) {
  final out = List<String>.from(_units);
  final t = current.trim();
  if (t.isNotEmpty && !out.contains(t)) {
    out.insert(0, t);
  }
  return out;
}

String _effectiveUnitValue(String current) {
  final choices = _unitChoices(current);
  final t = current.trim();
  if (t.isNotEmpty && choices.contains(t)) return t;
  return choices.contains('pce') ? 'pce' : choices.first;
}

/// Dialog création / édition produit — formulaire + images + catégorie/marque (aligné ProductFormDialog web).
class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    super.key,
    required this.companyId,
    this.currentStoreId,
    this.product,
    required this.categories,
    required this.brands,
    required this.onCategoriesChanged,
    required this.onBrandsChanged,
    required this.onSuccess,
    required this.onCancel,
  });

  final String companyId;
  final String? currentStoreId;
  final Product? product;
  final List<Category> categories;
  final List<Brand> brands;
  final VoidCallback onCategoriesChanged;
  final VoidCallback onBrandsChanged;
  final void Function(Product? savedProduct)? onSuccess;
  final VoidCallback onCancel;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockMinController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _newBrandController = TextEditingController();
  final _initialStockController = TextEditingController(text: '0');

  String _unit = 'pce';

  /// `both` | `warehouse_only` | `boutique_only`
  String _productScope = 'both';
  String? _categoryId;
  String? _brandId;
  bool _isActive = true;
  bool _loading = false;
  String? _error;
  final List<List<int>> _pendingImageBytes = [];
  final List<String> _pendingImageNames = [];
  final List<String> _pendingImageTypes = [];
  List<ProductImage> _existingImages = [];
  List<Category> _categories = [];
  List<Brand> _brands = [];

  final ProductsRepository _repo = ProductsRepository();
  final InventoryRepository _invRepo = InventoryRepository();

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _brands = List.from(widget.brands);
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.name;
      _skuController.text = p.sku ?? '';
      _barcodeController.text = p.barcode ?? '';
      _unit = p.unit;
      _purchasePriceController.text = p.purchasePrice.toString();
      _salePriceController.text = p.salePrice.toString();
      _stockMinController.text = p.stockMin.toString();
      _descriptionController.text = p.description ?? '';
      _categoryId = p.categoryId;
      _brandId = p.brandId;
      _isActive = p.isActive;
      _productScope = p.productScope;
      _existingImages = List.from(p.productImages ?? []);
    } else {
      _stockMinController.text = '5';
    }
  }

  @override
  void didUpdateWidget(ProductFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories.length != oldWidget.categories.length)
      _categories = List.from(widget.categories);
    if (widget.brands.length != oldWidget.brands.length)
      _brands = List.from(widget.brands);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _stockMinController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _newBrandController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _error = null;
        for (final f in result.files) {
          if (f.bytes != null) {
            _pendingImageBytes.add(f.bytes!);
            _pendingImageNames.add(f.name);
            _pendingImageTypes.add(
              f.extension != null ? 'image/${f.extension}' : 'image/jpeg',
            );
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = AppErrorHandler.toUserMessage(
            e,
            fallback: 'Impossible de sélectionner les images.',
          ),
        );
      }
    }
  }

  void _removePendingImage(int index) {
    setState(() {
      _pendingImageBytes.removeAt(index);
      _pendingImageNames.removeAt(index);
      _pendingImageTypes.removeAt(index);
    });
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final c = await _repo.createCategory(widget.companyId, name);
      final list = await _repo.categories(widget.companyId);
      if (mounted) {
        setState(() {
          _categories = list;
          _categoryId = c.id;
          _newCategoryController.clear();
          _loading = false;
        });
      }
      widget.onCategoriesChanged();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _addBrand() async {
    final name = _newBrandController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final b = await _repo.createBrand(widget.companyId, name);
      final list = await _repo.brands(widget.companyId);
      if (mounted) {
        setState(() {
          _brands = list;
          _brandId = b.id;
          _newBrandController.clear();
          _loading = false;
        });
      }
      widget.onBrandsChanged();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  double? _parseDouble(String v) {
    if (v.trim().isEmpty) return null;
    return double.tryParse(v.trim().replaceFirst(',', '.'));
  }

  int? _parseInt(String v) {
    if (v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Nom requis (2 caractères minimum)');
      return;
    }
    final salePrice = _parseDouble(_salePriceController.text) ?? 0;
    if (salePrice < 0) {
      setState(() => _error = 'Prix de vente doit être >= 0');
      return;
    }
    final storeId = widget.currentStoreId;
    final userId = context.read<AuthProvider>().user?.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Product? saved;
      if (widget.product != null) {
        saved = await _repo.update(widget.product!.id, {
          'name': name,
          'sku': _skuController.text.trim().isEmpty
              ? null
              : _skuController.text.trim(),
          'barcode': _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          'unit': _unit,
          'purchase_price': _parseDouble(_purchasePriceController.text) ?? 0,
          'sale_price': salePrice,
          'stock_min': _parseInt(_stockMinController.text) ?? 0,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'is_active': _isActive,
          'category_id': _categoryId,
          'brand_id': _brandId,
          'product_scope': _productScope,
        });
        for (var i = 0; i < _pendingImageBytes.length; i++) {
          await _repo.addImage(
            widget.product!.id,
            _pendingImageBytes[i],
            _pendingImageNames[i].isEmpty ? 'image.jpg' : _pendingImageNames[i],
            _pendingImageTypes[i],
          );
        }
      } else {
        final input = CreateProductInput(
          companyId: widget.companyId,
          name: name,
          sku: _skuController.text.trim().isEmpty
              ? null
              : _skuController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          unit: _unit,
          purchasePrice: _parseDouble(_purchasePriceController.text) ?? 0,
          salePrice: salePrice,
          stockMin: _parseInt(_stockMinController.text) ?? 0,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isActive: _isActive,
          categoryId: _categoryId,
          brandId: _brandId,
          productScope: _productScope,
        );
        saved = await _repo.create(input);
        final qty = _parseInt(_initialStockController.text) ?? 0;
        final stockBoutique =
            _productScope == 'both' || _productScope == 'boutique_only';
        if (qty > 0 && storeId != null && userId != null && stockBoutique) {
          await _invRepo.adjust(
            storeId,
            saved.id,
            qty,
            'Stock entrant',
            userId,
          );
        }
        for (var i = 0; i < _pendingImageBytes.length; i++) {
          await _repo.addImage(
            saved.id,
            _pendingImageBytes[i],
            _pendingImageNames[i].isEmpty ? 'image.jpg' : _pendingImageNames[i],
            _pendingImageTypes[i],
          );
        }
      }
      if (mounted) {
        setState(() => _loading = false);
        widget.onSuccess?.call(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < Breakpoints.tablet;
    final padding = isNarrow ? 16.0 : 24.0;
    final maxW = isNarrow ? screenSize.width - 32 : 520.0;
    final maxH = isNarrow ? screenSize.height * 0.88 : 700.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Modifier le produit' : 'Nouveau produit',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildImagesSection(context),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2)
                              ? 'Nom requis (2 car. min.)'
                              : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 400) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _skuController,
                                    decoration: const InputDecoration(
                                      labelText: 'SKU',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _barcodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Code-barres',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _skuController,
                                    decoration: const InputDecoration(
                                      labelText: 'SKU',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _barcodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Code-barres',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _effectiveUnitValue(_unit),
                          decoration: const InputDecoration(
                            labelText: 'Unité',
                            border: OutlineInputBorder(),
                          ),
                          items: _unitChoices(_unit)
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v ?? 'pce'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _productScope,
                          decoration: const InputDecoration(
                            labelText: 'Portée du produit',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('Dépôt et boutiques'),
                            ),
                            DropdownMenuItem(
                              value: 'warehouse_only',
                              child: Text('Dépôt uniquement (magasin)'),
                            ),
                            DropdownMenuItem(
                              value: 'boutique_only',
                              child: Text('Boutiques uniquement'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _productScope = v ?? 'both'),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 400) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _purchasePriceController,
                                    decoration: const InputDecoration(
                                      labelText: "Prix d'achat",
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _salePriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Prix de vente *',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (v) {
                                      final n = _parseDouble(v ?? '');
                                      if (n == null || n < 0)
                                        return 'Prix >= 0';
                                      return null;
                                    },
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _purchasePriceController,
                                    decoration: const InputDecoration(
                                      labelText: "Prix d'achat",
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _salePriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Prix de vente *',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (v) {
                                      final n = _parseDouble(v ?? '');
                                      if (n == null || n < 0)
                                        return 'Prix >= 0';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 400) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _stockMinController,
                                    decoration: const InputDecoration(
                                      labelText: 'Stock minimum',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                  if (!isEdit &&
                                      (_productScope == 'both' ||
                                          _productScope ==
                                              'boutique_only')) ...[
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _initialStockController,
                                      decoration: InputDecoration(
                                        labelText: 'Stock entrant',
                                        border: const OutlineInputBorder(),
                                        hintText: widget.currentStoreId != null
                                            ? 'Quantité pour la boutique'
                                            : 'Choisir une boutique',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _stockMinController,
                                    decoration: const InputDecoration(
                                      labelText: 'Stock minimum',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                if (!isEdit &&
                                    (_productScope == 'both' ||
                                        _productScope == 'boutique_only')) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _initialStockController,
                                      decoration: InputDecoration(
                                        labelText: 'Stock entrant',
                                        border: const OutlineInputBorder(),
                                        hintText: widget.currentStoreId != null
                                            ? 'Quantité pour la boutique'
                                            : 'Choisir une boutique',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCategorySection(context),
                        const SizedBox(height: 12),
                        _buildBrandSection(context),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _isActive,
                          onChanged: (v) =>
                              setState(() => _isActive = v ?? true),
                          title: const Text('Produit actif'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : widget.onCancel,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        Breakpoints.minTouchTarget,
                        Breakpoints.minTouchTarget,
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, Breakpoints.minTouchTarget),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Mettre à jour' : 'Créer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context) {
    final existing = _existingImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Images', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...existing.map(
              (img) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      img.url,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        try {
                          await _repo.deleteImage(img.id);
                          if (mounted)
                            setState(
                              () => _existingImages.removeWhere(
                                (e) => e.id == img.id,
                              ),
                            );
                        } catch (_) {}
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(
                          Breakpoints.minTouchTarget,
                          Breakpoints.minTouchTarget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(
              _pendingImageBytes.length,
              (i) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      Uint8List.fromList(_pendingImageBytes[i]),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removePendingImage(i),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(
                          Breakpoints.minTouchTarget,
                          Breakpoints.minTouchTarget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_photo_alternate,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Catégorie'),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 320;
            final seenCatIds = <String>{};
            final distinctCategories = _categories
                .where((c) => seenCatIds.add(c.id))
                .toList();
            final categoryValue =
                _categoryId != null &&
                    distinctCategories.any((c) => c.id == _categoryId)
                ? _categoryId
                : null;
            final dropdown = DropdownButtonFormField<String>(
              value: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...distinctCategories.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            );
            final newField = TextFormField(
              controller: _newCategoryController,
              decoration: const InputDecoration(
                hintText: 'Nouvelle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            );
            final addBtn = IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addCategory,
              tooltip: 'Ajouter catégorie',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(
                  Breakpoints.minTouchTarget,
                  Breakpoints.minTouchTarget,
                ),
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dropdown,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: newField),
                      addBtn,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: dropdown),
                const SizedBox(width: 8),
                Expanded(child: newField),
                addBtn,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBrandSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Marque'),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 320;
            final seenBrandIds = <String>{};
            final distinctBrands = _brands
                .where((b) => seenBrandIds.add(b.id))
                .toList();
            final brandValue =
                _brandId != null && distinctBrands.any((b) => b.id == _brandId)
                ? _brandId
                : null;
            final dropdown = DropdownButtonFormField<String>(
              value: brandValue,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...distinctBrands.map(
                  (b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _brandId = v),
            );
            final newField = TextFormField(
              controller: _newBrandController,
              decoration: const InputDecoration(
                hintText: 'Nouvelle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            );
            final addBtn = IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addBrand,
              tooltip: 'Ajouter marque',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(
                  Breakpoints.minTouchTarget,
                  Breakpoints.minTouchTarget,
                ),
              ),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dropdown,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: newField),
                      addBtn,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: dropdown),
                const SizedBox(width: 8),
                Expanded(child: newField),
                addBtn,
              ],
            );
          },
        ),
      ],
    );
  }
}
