import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/brand.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/products_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/products_page_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../shared/widgets/company_load_error_screen.dart';
import '../../../shared/utils/share_csv.dart';
import 'utils/products_csv.dart';
import 'widgets/brands_section.dart';
import 'widgets/categories_section.dart';
import 'widgets/import_products_csv_dialog.dart';
import 'widgets/product_form_dialog.dart';
import 'widgets/stock_range_indicator.dart';

enum _ProductsTab { products, categories, brands }

const int _productsPageSize = 20;

/// Page Produits — onglets Produits / Catégories / Marques.
/// Produits et stock lus depuis Drift (offline-first) ; sync en arrière-plan.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final ProductsRepository _repo = ProductsRepository();
  final TextEditingController _searchController = TextEditingController();

  _ProductsTab _tab = _ProductsTab.products;
  String _filterCategoryId = '';
  String _filterBrandId = '';
  bool _syncTriggeredForEmpty = false;
  int _currentProductsPage = 0;
  String _lastProductsFilterKey = '';

  /// Après import CSV : liste API + Drift + sync — évite l’impression que « rien ne s’est passé ».
  bool _syncingCatalogAfterImport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  /// Plus d'appel API au montage : tout vient de Drift (streams). Seuil stock = 5 par défaut.

  /// Même logique que web : charger les entreprises si pas encore fait (ex. ouverture directe Produits).
  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    if (auth.user != null && company.companies.isEmpty && !company.loading) {
      final userId = auth.user?.id;
      if (userId != null) company.loadCompanies(userId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    await context.read<ProductsPageProvider>().load(companyId, storeId, force: true);
    final userId = auth.user?.id;
    if (userId != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: userId, companyId: companyId, storeId: storeId);
      } catch (_) {}
    }
  }

  /// Après un import CSV réussi : récupère la liste à jour depuis l’API, écrit dans Drift, invalide le stream.
  /// Les produits s’affichent immédiatement au lieu d’attendre la fin de la sync.
  Future<void> _onImportSuccess() async {
    if (!mounted) return;
    setState(() => _syncingCatalogAfterImport = true);
    try {
      final companyId = context.read<CompanyProvider>().currentCompanyId;
      if (companyId == null) return;
      try {
        final list = await _repo.list(companyId);
        if (!mounted) return;
        await ref.read(productsOfflineRepositoryProvider).upsertFromRemote(list);
        if (!mounted) return;
        ref.invalidate(productsStreamProvider(companyId));
      } catch (_) {}
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _syncingCatalogAfterImport = false);
      }
    }
  }

  Future<void> _applyCategoryCreated(Category c) async {
    await ref.read(categoriesOfflineRepositoryProvider).upsertCategory(c);
    if (!mounted) return;
    ref.invalidate(categoriesStreamProvider(c.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyCategoryUpdated(Category c) async {
    await ref.read(categoriesOfflineRepositoryProvider).upsertCategory(c);
    if (!mounted) return;
    ref.invalidate(categoriesStreamProvider(c.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyCategoryDeleted(String id, String? companyId) async {
    if (companyId == null) return;
    await ref.read(appDatabaseProvider).deleteLocalCategory(id);
    if (!mounted) return;
    ref.invalidate(categoriesStreamProvider(companyId));
    _runSyncInBackground();
  }

  Future<void> _applyBrandCreated(Brand b) async {
    await ref.read(brandsOfflineRepositoryProvider).upsertBrand(b);
    if (!mounted) return;
    ref.invalidate(brandsStreamProvider(b.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyBrandUpdated(Brand b) async {
    await ref.read(brandsOfflineRepositoryProvider).upsertBrand(b);
    if (!mounted) return;
    ref.invalidate(brandsStreamProvider(b.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyBrandDeleted(String id, String? companyId) async {
    if (companyId == null) return;
    await ref.read(appDatabaseProvider).deleteLocalBrand(id);
    if (!mounted) return;
    ref.invalidate(brandsStreamProvider(companyId));
    _runSyncInBackground();
  }

  List<Product> _filteredProducts(List<Product> products) {
    final search = _searchController.text.trim().toLowerCase();
    return products.where((p) {
      if (search.isNotEmpty) {
        final matchName = p.name.toLowerCase().contains(search);
        final matchSku = p.sku?.toLowerCase().contains(search) ?? false;
        final matchBarcode = p.barcode?.contains(_searchController.text.trim()) ?? false;
        if (!matchName && !matchSku && !matchBarcode) return false;
      }
      if (_filterCategoryId.isNotEmpty && p.categoryId != _filterCategoryId) return false;
      if (_filterBrandId.isNotEmpty && p.brandId != _filterBrandId) return false;
      return true;
    }).toList();
  }

  void _openCreate() {
    final provider = context.read<ProductsPageProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductFormDialog(
        companyId: context.read<CompanyProvider>().currentCompanyId!,
        currentStoreId: context.read<CompanyProvider>().currentStoreId,
        categories: List<Category>.from(provider.categories),
        brands: List<Brand>.from(provider.brands),
        onCategoriesChanged: _refresh,
        onBrandsChanged: _refresh,
        onSuccess: (Product? saved) {
          Navigator.of(ctx).pop();
          if (saved != null) _applyProductChange(saved);
          if (mounted) AppToast.success(context, 'Produit créé');
        },
        onCancel: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _openEdit(Product product) {
    final provider = context.read<ProductsPageProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductFormDialog(
        companyId: product.companyId,
        currentStoreId: context.read<CompanyProvider>().currentStoreId,
        product: product,
        categories: List<Category>.from(provider.categories),
        brands: List<Brand>.from(provider.brands),
        onCategoriesChanged: _refresh,
        onBrandsChanged: _refresh,
        onSuccess: (Product? saved) {
          Navigator.of(ctx).pop();
          if (saved != null) _applyProductChange(saved);
          if (mounted) AppToast.success(context, 'Produit mis à jour');
        },
        onCancel: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _toggleActive(Product p) async {
    try {
      await _repo.setActive(p.id, !p.isActive);
      if (!mounted) return;
      await ref.read(appDatabaseProvider).updateLocalProductIsActive(p.id, !p.isActive);
      if (!mounted) return;
      ref.invalidate(productsStreamProvider(p.companyId));
      context.read<ProductsPageProvider>().setProductActive(p.id, !p.isActive);
      AppToast.success(context, p.isActive ? 'Produit désactivé' : 'Produit activé');
      _runSyncInBackground();
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  void _exportCsv(List<Product> filtered) {
    if (filtered.isEmpty) return;
    final csv = productsToCsv(filtered);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'produits-$date.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    saveCsvFile(filename: filename, bytes: bytes).then((saved) {
      if (!mounted) return;
      if (saved) AppToast.success(context, 'CSV enregistré');
    });
  }

  void _openImportCsv() {
    final company = context.read<CompanyProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => ImportProductsCsvDialog(
        companyId: company.currentCompanyId!,
        currentStoreId: company.currentStoreId,
        onSuccess: _onImportSuccess,
        onOfflineImport: (payload) async {
          await ref.read(appDatabaseProvider).enqueuePendingAction('product_import', jsonEncode(payload));
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${p.name} » sera supprimé (archivé).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      // 1. Suppression en base (serveur) — garde le offline+sync cohérent
      await _repo.softDelete(p.id);
      if (!mounted) return;
      // 2. Suppression en local (Drift) — la liste lit depuis le stream Drift, donc disparition immédiate à l'écran
      await ref.read(appDatabaseProvider).deleteLocalProduct(p.id);
      if (!mounted) return;
      // 3. Forcer le stream à réémettre la liste à jour (au cas où le watch Drift tarde)
      ref.invalidate(productsStreamProvider(p.companyId));
      context.read<ProductsPageProvider>().removeProduct(p.id);
      AppToast.success(context, 'Produit supprimé');
      _runSyncInBackground();
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  /// Lance la sync en arrière-plan sans bloquer l’UI (principe 2).
  void _runSyncInBackground() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    Future.microtask(() async {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: userId, companyId: companyId, storeId: storeId);
      } catch (_) {}
    });
  }

  /// Met à jour le cache du provider et lance une sync en arrière-plan (ne bloque pas l’UI).
  Future<void> _applyProductChange(Product saved) async {
    final storeId = context.read<CompanyProvider>().currentStoreId;
    final productsPage = context.read<ProductsPageProvider>();
    final full = await _repo.get(saved.id);
    if (full == null || !mounted) return;
    await ref.read(productsOfflineRepositoryProvider).upsertProduct(full);
    if (!mounted) return;
    ref.invalidate(productsStreamProvider(full.companyId));
    if (storeId != null && storeId.isNotEmpty) {
      try {
        await ref
            .read(syncServiceV2Provider)
            .pullInventoryQuantitiesForStores([storeId]);
      } catch (_) {}
      if (mounted) {
        ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
      }
    }
    productsPage.setProduct(full);
    _runSyncInBackground();
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>();
    final permissions = context.watch<PermissionsProvider>();
    final provider = context.watch<ProductsPageProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final canCreateProduct = permissions.hasPermission(Permissions.productsCreate);
    final canUpdateProduct = permissions.hasPermission(Permissions.productsUpdate);
    final canDeleteProduct = permissions.hasPermission(Permissions.productsDelete);
    final canAccessProducts = permissions.hasPermission(Permissions.productsView) ||
        canCreateProduct || canUpdateProduct || canDeleteProduct;

    if (permissions.hasLoaded && !canAccessProducts) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produits')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text("Vous n'avez pas accès à cette page.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    final asyncProducts = ref.watch(productsStreamProvider(companyId ?? ''));
    final asyncInventory = ref.watch(inventoryQuantitiesStreamProvider(storeId ?? ''));
    final asyncCategories = ref.watch(categoriesStreamProvider(companyId ?? ''));
    final asyncBrands = ref.watch(brandsStreamProvider(companyId ?? ''));
    final products = asyncProducts.valueOrNull ?? [];
    final stockByStore = asyncInventory.valueOrNull ?? {};
    final categories = asyncCategories.valueOrNull ?? [];
    final brands = asyncBrands.valueOrNull ?? [];
    final productsLoading = asyncProducts.isLoading;
    final productsError = asyncProducts.hasError && asyncProducts.error != null
        ? AppErrorHandler.toUserMessage(asyncProducts.error, fallback: 'Impossible de charger les produits.')
        : provider.error;

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return CompanyLoadErrorScreen(
        message: company.loadError!,
        title: 'Produits',
      );
    }
    if (companyId == null) {
      final wide900 = MediaQuery.sizeOf(context).width >= 900;
      return Scaffold(
        appBar: wide900 ? AppBar(title: const Text('Produits')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!wide900) ...[
                  Text(
                    'Produits',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Aucune entreprise. Contactez l’administrateur.'),
              ],
            ),
          ),
        ),
      );
    }

    // Liste vide : déclencher une sync une fois pour remplir Drift (premier lancement ou base vide).
    if (_tab == _ProductsTab.products && products.isEmpty && !productsLoading && productsError == null && !_syncTriggeredForEmpty) {
      _syncTriggeredForEmpty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSyncInBackground();
      });
    }
    if (products.isNotEmpty) _syncTriggeredForEmpty = false;

    final theme = Theme.of(context);
    return Stack(
      children: [
        Scaffold(
          appBar: null,
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catalogue, catégories et marques', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        if (productsError != null && _tab == _ProductsTab.products) ...[
                          const SizedBox(height: 8),
                          Text(productsError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TabChip(
                          label: 'Produits',
                          icon: Icons.inventory_2,
                          selected: _tab == _ProductsTab.products,
                          onTap: () {
                            setState(() => _tab = _ProductsTab.products);
                            if (context.read<CompanyProvider>().currentStoreId != null) _refresh();
                          },
                        ),
                        _TabChip(label: 'Catégories', icon: Icons.category, selected: _tab == _ProductsTab.categories, onTap: () => setState(() => _tab = _ProductsTab.categories)),
                        _TabChip(label: 'Marques', icon: Icons.sell, selected: _tab == _ProductsTab.brands, onTap: () => setState(() => _tab = _ProductsTab.brands)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_tab == _ProductsTab.products) ..._buildProductsTab(context, provider, products, stockByStore, categories, brands, productsLoading, productsError, companyId, storeId, isWide, canUpdateProduct, canDeleteProduct, canCreateProduct),
                if (_tab == _ProductsTab.categories)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverToBoxAdapter(
                      child: CategoriesSection(
                        companyId: companyId,
                        categories: categories,
                        onChanged: _refresh,
                        readOnly: permissions.isCashier,
                        onCategoryCreated: (c) => _applyCategoryCreated(c),
                        onCategoryUpdated: (c) => _applyCategoryUpdated(c),
                        onCategoryDeleted: (id) => _applyCategoryDeleted(id, companyId),
                      ),
                    ),
                  ),
                if (_tab == _ProductsTab.brands)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverToBoxAdapter(
                      child: BrandsSection(
                        companyId: companyId,
                        brands: brands,
                        onChanged: _refresh,
                        readOnly: permissions.isCashier,
                        onBrandCreated: (b) => _applyBrandCreated(b),
                        onBrandUpdated: (b) => _applyBrandUpdated(b),
                        onBrandDeleted: (id) => _applyBrandDeleted(id, companyId),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: _tab == _ProductsTab.products && canCreateProduct
              ? (MediaQuery.sizeOf(context).width < 900
                  ? FloatingActionButton(
                      onPressed: _openCreate,
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      highlightElevation: 8,
                      child: const Icon(Icons.add),
                    )
                  : FloatingActionButton.extended(
                      onPressed: _openCreate,
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      highlightElevation: 8,
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau produit'),
                    ))
              : null,
        ),
        if (_syncingCatalogAfterImport)
          Positioned.fill(
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.45),
                ),
                child: SafeArea(
                  child: Center(
                    child: Card(
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Mise à jour du catalogue…',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Récupération des produits, cache local et synchronisation.\n'
                              'Hors ligne : la file d’attente sera traitée à la reconnexion.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildProductsTab(BuildContext context, ProductsPageProvider provider, List<Product> products, Map<String, int> stockByStore, List<Category> categories, List<Brand> brands, bool productsLoading, String? productsError, String? companyId, String? storeId, bool isWide, bool canUpdateProduct, bool canDeleteProduct, bool canCreateProduct) {
    if (companyId == null) return [const SliverFillRemaining(child: Center(child: Text('Choisissez une entreprise')))];
    final isMobileProducts =
        MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    final filtered = _filteredProducts(products);
    final totalCount = filtered.length;
    final pageCount = totalCount == 0 ? 0 : ((totalCount - 1) ~/ _productsPageSize) + 1;
    final filterKey = '${_searchController.text}|$_filterCategoryId|$_filterBrandId';
    if (filterKey != _lastProductsFilterKey) {
      _lastProductsFilterKey = filterKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentProductsPage = 0);
      });
    }
    final effectivePage = pageCount > 0 && _currentProductsPage >= pageCount ? pageCount - 1 : _currentProductsPage;
    if (effectivePage != _currentProductsPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentProductsPage = effectivePage);
      });
    }
    final paginatedList = isMobileProducts
        ? filtered
        : filtered
            .skip(effectivePage * _productsPageSize)
            .take(_productsPageSize)
            .toList();
    final canModifyProducts = canUpdateProduct || canDeleteProduct || canCreateProduct;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canModifyProducts)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final csvBtnStyle = OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    );
                    final exportBtn = OutlinedButton.icon(
                      onPressed: filtered.isEmpty ? null : () => _exportCsv(filtered),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Enregistrer CSV'),
                      style: csvBtnStyle,
                    );
                    final importBtn = OutlinedButton.icon(
                      onPressed: _openImportCsv,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Importer CSV'),
                      style: csvBtnStyle,
                    );
                    // Même ligne : risque de débordement ~quelques px si le Wrap sous-alloue la 2e ligne.
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          exportBtn,
                          if (canCreateProduct) ...[
                            const SizedBox(height: 8),
                            importBtn,
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: exportBtn),
                        if (canCreateProduct) ...[
                          const SizedBox(width: 8),
                          Expanded(child: importBtn),
                        ],
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Rechercher nom, SKU, code-barres...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 340;
                  final seenCatIds = <String>{};
                  final distinctCategories = categories.where((c) => seenCatIds.add(c.id)).toList();
                  final categoryValue = _filterCategoryId.isNotEmpty &&
                          distinctCategories.any((c) => c.id == _filterCategoryId)
                      ? _filterCategoryId
                      : null;
                  final categoryDropdown = DropdownButtonFormField<String>(
                    initialValue: categoryValue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Toutes')),
                      ...distinctCategories.map<DropdownMenuItem<String>>(
                        (c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterCategoryId = v ?? ''),
                  );
                  final seenBrandIds = <String>{};
                  final distinctBrands = brands.where((b) => seenBrandIds.add(b.id)).toList();
                  final brandValue = _filterBrandId.isNotEmpty &&
                          distinctBrands.any((b) => b.id == _filterBrandId)
                      ? _filterBrandId
                      : null;
                  final brandDropdown = DropdownButtonFormField<String>(
                    initialValue: brandValue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Marque', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Toutes')),
                      ...distinctBrands.map<DropdownMenuItem<String>>(
                        (b) => DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterBrandId = v ?? ''),
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        categoryDropdown,
                        const SizedBox(height: 8),
                        brandDropdown,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: categoryDropdown),
                      const SizedBox(width: 8),
                      Expanded(child: brandDropdown),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      if (productsLoading)
        const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
      else if (filtered.isEmpty)
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    products.isEmpty ? 'Aucun produit pour le moment.' : 'Aucun résultat.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (products.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tirez pour synchroniser ou créez un produit.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
      else ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = paginatedList[index];
                final qty = storeId != null ? (stockByStore[p.id] ?? 0) : null;
                final threshold = p.stockMin > 0 ? p.stockMin : provider.defaultStockThreshold;
                return _ProductListTile(
                  product: p,
                  stockQuantity: qty,
                  stockAlertThreshold: threshold,
                  onEdit: () => _openEdit(p),
                  onToggleActive: () => _toggleActive(p),
                  onDelete: () => _deleteProduct(p),
                  canEdit: canUpdateProduct,
                  canDelete: canDeleteProduct,
                );
              },
              childCount: paginatedList.length,
            ),
          ),
        ),
        if (!isMobileProducts && pageCount > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: _buildProductsPagination(context, totalCount, pageCount, effectivePage),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    ];
  }

  Widget _buildProductsPagination(BuildContext context, int totalCount, int pageCount, int currentPageIndex) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _productsPageSize + 1;
    final end = (currentPageIndex + 1) * _productsPageSize;
    final endClamped = end > totalCount ? totalCount : end;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isNarrow)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$start – $endClamped sur $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            IconButton.filled(
              onPressed: currentPageIndex > 0 ? () => setState(() => _currentProductsPage--) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex > 0 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex > 0 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page ${currentPageIndex + 1} / $pageCount',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: currentPageIndex < pageCount - 1 ? () => setState(() => _currentProductsPage++) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            if (isNarrow) ...[
              const SizedBox(width: 12),
              Text(
                '$start – $endClamped / $totalCount',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: primary.withValues(alpha: 0.2),
      checkmarkColor: primary,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? primary : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? primary : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  const _ProductListTile({
    required this.product,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    this.stockQuantity,
    this.stockAlertThreshold = 5,
    this.canEdit = true,
    this.canDelete = true,
  });

  final Product product;
  final int? stockQuantity;
  final int stockAlertThreshold;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstImage = product.productImages?.isNotEmpty == true ? product.productImages!.first.url : null;
    final subtitleText = '${product.sku ?? '—'} · ${formatCurrency(product.salePrice)} · ${product.category?.name ?? '—'} · ${product.brand?.name ?? '—'}';

    final tileActions = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      minimumSize: const Size(36, 36),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: firstImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          firstImage,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (_, _, _) => Icon(Icons.inventory_2, color: theme.colorScheme.outline),
                        ),
                      )
                    : Icon(Icons.inventory_2, color: theme.colorScheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: product.isActive ? null : TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (stockQuantity != null) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: StockRangeIndicator(
                              quantity: stockQuantity!,
                              alertThreshold: stockAlertThreshold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit || canDelete)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: onEdit,
                            tooltip: 'Modifier',
                            style: tileActions,
                          ),
                          IconButton(
                            icon: Icon(product.isActive ? Icons.toggle_on : Icons.toggle_off, size: 26),
                            onPressed: onToggleActive,
                            tooltip: product.isActive ? 'Désactiver' : 'Activer',
                            style: tileActions,
                          ),
                        ],
                        if (canDelete)
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                            onPressed: onDelete,
                            tooltip: 'Supprimer',
                            style: tileActions,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
