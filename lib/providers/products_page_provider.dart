import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../core/errors/app_error_handler.dart';
import '../data/models/brand.dart';
import '../data/models/category.dart';
import '../data/models/product.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/repositories/products_repository.dart';
import '../data/repositories/settings_repository.dart';

/// Cache des données de la page Produits. Évite le rechargement au retour sur l'écran.
class ProductsPageProvider extends ChangeNotifier {
  ProductsPageProvider() {
    _repo = ProductsRepository();
    _invRepo = InventoryRepository();
    _settingsRepo = SettingsRepository();
  }

  late final ProductsRepository _repo;
  late final InventoryRepository _invRepo;
  late final SettingsRepository _settingsRepo;

  List<Product>? _products;
  List<Category>? _categories;
  List<Brand>? _brands;
  Map<String, int> _stockByStore = {};
  int _defaultStockThreshold = 5;
  bool _loading = false;
  String? _error;

  String? _lastCompanyId;
  String? _lastStoreId;

  List<Product> get products => _products ?? <Product>[];
  List<Category> get categories => _categories ?? <Category>[];
  List<Brand> get brands => _brands ?? <Brand>[];
  Map<String, int> get stockByStore => _stockByStore;
  int get defaultStockThreshold => _defaultStockThreshold;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _products != null;

  /// Charge si nécessaire (pas de rechargement si même company/store et données déjà en cache).
  Future<void> loadIfNeeded(String? companyId, String? storeId, {bool force = false}) async {
    if (companyId == null) {
      _products = null;
      _categories = null;
      _brands = null;
      _stockByStore = {};
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }
    if (!force && _lastCompanyId == companyId && _lastStoreId == storeId && _products != null) {
      return;
    }
    await load(companyId, storeId, force: true);
  }

  /// Force le rechargement (ex. pull-to-refresh).
  Future<void> load(String? companyId, String? storeId, {bool force = false}) async {
    if (companyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.list(companyId),
        _repo.categories(companyId),
        _repo.brands(companyId),
      ]);
      Map<String, int> stockByStore = {};
      var defaultStockThreshold = 5;
      if (storeId != null) {
        stockByStore = await _invRepo.getStockByStore(storeId);
        defaultStockThreshold = await _settingsRepo.getDefaultStockAlertThreshold(companyId);
      }
      _products = results[0] as List<Product>;
      _categories = results[1] as List<Category>;
      _brands = results[2] as List<Brand>;
      _stockByStore = stockByStore;
      _defaultStockThreshold = defaultStockThreshold;
      _lastCompanyId = companyId;
      _lastStoreId = storeId;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.toUserMessage(e);
      _loading = false;
      notifyListeners();
    }
  }

  /// Remplace ou ajoute un produit (après création/édition).
  void setProduct(Product product) {
    if (_products == null) return;
    final i = _products!.indexWhere((e) => e.id == product.id);
    if (i >= 0) {
      _products = List.from(_products!)..[i] = product;
    } else {
      _products = [product, ..._products!];
    }
    notifyListeners();
  }

  /// Met à jour isActive d'un produit (après activer/désactiver).
  void setProductActive(String productId, bool isActive) {
    if (_products == null) return;
    _products = _products!.map((p) {
      if (p.id != productId) return p;
      return Product(
        id: p.id,
        companyId: p.companyId,
        name: p.name,
        sku: p.sku,
        barcode: p.barcode,
        unit: p.unit,
        purchasePrice: p.purchasePrice,
        salePrice: p.salePrice,
        wholesalePrice: p.wholesalePrice,
        wholesaleQty: p.wholesaleQty,
        minPrice: p.minPrice,
        stockMin: p.stockMin,
        description: p.description,
        isActive: isActive,
        categoryId: p.categoryId,
        brandId: p.brandId,
        category: p.category,
        brand: p.brand,
        productImages: p.productImages,
        productScope: p.productScope,
      );
    }).toList();
    notifyListeners();
  }

  /// Retire un produit de la liste (après suppression).
  void removeProduct(String productId) {
    if (_products == null) return;
    _products = _products!.where((e) => e.id != productId).toList();
    notifyListeners();
  }

  /// Invalide le cache (ex. changement d'entreprise côté CompanyProvider).
  void invalidate() {
    _lastCompanyId = null;
    _lastStoreId = null;
    _products = null;
    _categories = null;
    _brands = null;
    _stockByStore = {};
    _error = null;
    notifyListeners();
  }
}
