import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../core/errors/app_error_handler.dart';
import '../data/models/sale.dart';
import '../data/repositories/sales_repository.dart';

/// Cache des données de la page Ventes + filtres. Évite le rechargement au retour sur l'écran.
class SalesPageProvider extends ChangeNotifier {
  SalesPageProvider() {
    _repo = SalesRepository();
  }

  late final SalesRepository _repo;

  List<Sale>? _sales;
  bool _loading = false;
  String? _error;

  String _filterStoreId = '';
  SaleStatus? _filterStatus;
  String _filterFrom = '';
  String _filterTo = '';

  String? _lastCompanyId;

  List<Sale> get sales => _sales ?? <Sale>[];
  bool get loading => _loading;
  String? get error => _error;
  bool get hasData => _sales != null;

  String get filterStoreId => _filterStoreId;
  SaleStatus? get filterStatus => _filterStatus;
  String get filterFrom => _filterFrom;
  String get filterTo => _filterTo;

  void setFilters({
    String? storeId,
    SaleStatus? status,
    String? from,
    String? to,
  }) {
    if (storeId != null) _filterStoreId = storeId;
    if (status != null) _filterStatus = status;
    if (from != null) _filterFrom = from;
    if (to != null) _filterTo = to;
    notifyListeners();
  }

  /// Charge si nécessaire (pas de rechargement si même company et mêmes filtres et données en cache).
  Future<void> loadIfNeeded(String? companyId, {bool force = false}) async {
    if (companyId == null) {
      _sales = null;
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }
    if (!force && _lastCompanyId == companyId && _sales != null) {
      return;
    }
    await load(companyId, force: true);
  }

  /// Force le rechargement (ex. pull-to-refresh ou changement de filtres).
  Future<void> load(String? companyId, {bool force = false}) async {
    if (companyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.list(
        companyId,
        storeId: _filterStoreId.isEmpty ? null : _filterStoreId,
        status: _filterStatus,
        fromDate: _filterFrom.isEmpty ? null : _filterFrom,
        toDate: _filterTo.isEmpty ? null : _filterTo,
      );
      _sales = list;
      _lastCompanyId = companyId;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.toUserMessage(e);
      _loading = false;
      notifyListeners();
    }
  }

  /// Invalide le cache (ex. changement d'entreprise).
  void invalidate() {
    _lastCompanyId = null;
    _sales = null;
    _error = null;
    notifyListeners();
  }
}
