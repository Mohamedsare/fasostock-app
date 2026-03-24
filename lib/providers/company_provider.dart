import 'package:flutter/foundation.dart';
import '../core/errors/app_error_handler.dart';
import '../data/models/company.dart';
import '../data/models/store.dart';
import '../data/repositories/company_repository.dart';

/// État entreprise / boutique courante — équivalent CompanyContext (web).
class CompanyProvider extends ChangeNotifier {
  CompanyProvider({CompanyRepository? repository})
      : _repo = repository ?? CompanyRepository();

  final CompanyRepository _repo;

  List<Company> _companies = [];
  String? _currentCompanyId;
  List<Store> _stores = [];
  String? _currentStoreId;
  bool _loading = false;
  String? _loadError;

  List<Company> get companies => _companies;
  String? get currentCompanyId => _currentCompanyId;
  List<Store> get stores => _stores;
  String? get currentStoreId => _currentStoreId;
  bool get loading => _loading;
  /// Message d'erreur si le dernier chargement des entreprises a échoué (réseau, permission, etc.).
  String? get loadError => _loadError;

  Company? get currentCompany {
    if (_currentCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c.id == _currentCompanyId);
    } catch (_) {
      return null;
    }
  }

  Store? get currentStore {
    if (_currentStoreId == null) return null;
    try {
      return _stores.firstWhere((s) => s.id == _currentStoreId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCompanies(String? userId) async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    if (userId == null || userId.isEmpty) {
      _companies = [];
      _currentCompanyId = null;
      _stores = [];
      _currentStoreId = null;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      _companies = await _repo.getCompaniesForUser(userId);
      _currentCompanyId = (_currentCompanyId != null && _companies.any((c) => c.id == _currentCompanyId))
          ? _currentCompanyId
          : (_companies.isNotEmpty ? _companies.first.id : null);
      _stores = [];
      _currentStoreId = null;
      if (_currentCompanyId != null) await _loadStores();
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      _loadError = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de charger les entreprises.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadStores() async {
    if (_currentCompanyId == null) return;
    _stores = await _repo.getStoresForCompany(_currentCompanyId!);
    _currentStoreId = (_currentStoreId != null && _stores.any((s) => s.id == _currentStoreId))
        ? _currentStoreId
        : (_stores.any((s) => s.isPrimary) ? _stores.firstWhere((s) => s.isPrimary).id : (_stores.isNotEmpty ? _stores.first.id : null));
  }

  void setCurrentCompanyId(String? id) {
    _currentCompanyId = id;
    _currentStoreId = null;
    _stores = [];
    if (id != null) _repo.getStoresForCompany(id).then((list) {
      _stores = list;
      _currentStoreId = list.any((s) => s.isPrimary) ? list.firstWhere((s) => s.isPrimary).id : (list.isNotEmpty ? list.first.id : null);
      notifyListeners();
    });
    notifyListeners();
  }

  void setCurrentStoreId(String? id) {
    _currentStoreId = id;
    notifyListeners();
  }

  Future<void> refreshCompanies(String? userId) => loadCompanies(userId);

  Future<void> refreshStores() async {
    if (_currentCompanyId == null) return;
    try {
      _stores = await _repo.getStoresForCompany(_currentCompanyId!);
      _currentStoreId = (_currentStoreId != null && _stores.any((s) => s.id == _currentStoreId))
          ? _currentStoreId
          : (_stores.any((s) => s.isPrimary) ? _stores.firstWhere((s) => s.isPrimary).id : (_stores.isNotEmpty ? _stores.first.id : null));
    } catch (e, st) {
      AppErrorHandler.log(e, st);
    }
    notifyListeners();
  }
}
