import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../../core/config/routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/sales_page_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../shared/widgets/company_load_error_screen.dart';
import '../../../shared/utils/share_csv.dart';
import 'utils/sales_csv.dart';
import 'widgets/sale_detail_dialog.dart';
import '../../../core/utils/sale_pos_edit.dart';

const _statusLabels = {
  SaleStatus.draft: 'Brouillon',
  SaleStatus.completed: 'Complétée',
  SaleStatus.cancelled: 'Annulée',
  SaleStatus.refunded: 'Remboursée',
};

/// Type document pour la liste : priorité à document_type (stocké en local), puis sale_mode. Sans info → Thermique.
bool _isA4Invoice(Sale s) {
  if (s.documentType == DocumentType.a4Invoice) return true;
  if (s.documentType == DocumentType.thermalReceipt) return false;
  if (s.saleMode == SaleMode.invoicePos) return true;
  if (s.saleMode == SaleMode.quickPos) return false;
  return false; // champs null (anciennes ventes ou pas encore synchronisées)
}

Widget _documentTypeChip(Sale s, BuildContext context) {
  final theme = Theme.of(context);
  final isA4 = _isA4Invoice(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isA4
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.8)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isA4 ? Icons.description_rounded : Icons.receipt_long_rounded,
          size: 14,
          color: isA4
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          isA4 ? 'A4' : 'Thermique',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isA4
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

String _formatDateTime(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(d.toLocal());
  } catch (_) {
    return iso;
  }
}

/// Page Ventes — design pro : en-tête, cartes d’action, filtres, tableau/liste.
class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

const int _salesPageSize = 20;

class _SalesPageState extends ConsumerState<SalesPage> {
  final SalesRepository _repo = SalesRepository();
  final Set<String> _cancelSaleInFlight = {};
  final Set<String> _purgeCancelledInFlight = {};
  bool _syncTriggeredForEmpty = false;
  int _currentPage = 0;
  String _lastFilterKey = '';
  Timer? _salesListRefreshTimer;
  final TextEditingController _salesSearchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchDebouncing = false;
  bool _invoiceTablePosEnabled = false;
  String? _invoiceTableLoadedForCompanyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SalesPageProvider>();
      _salesSearchController.text = provider.filterSearch;
      _salesSearchController.addListener(_onSalesSearchChanged);
      _loadCompaniesIfNeeded();
      _startSalesListAutoRefresh();
    });
  }

  void _onSalesSearchChanged() {
    if (!_searchDebouncing && mounted) setState(() => _searchDebouncing = true);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<SalesPageProvider>().setSearchQuery(
        _salesSearchController.text,
      );
      if (mounted) setState(() => _searchDebouncing = false);
    });
  }

  /// Même principe que le stock POS : tirage serveur périodique pour que les ventes (statuts, nouvelles lignes)
  /// se propagent à tous les appareils connectés en ≤ 10 s, en complément du Realtime `sales`.
  void _startSalesListAutoRefresh() {
    _salesListRefreshTimer?.cancel();
    void pullSalesList() {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final companyId = context.read<CompanyProvider>().currentCompanyId;
      if (companyId == null) return;
      final provider = context.read<SalesPageProvider>();
      final storeId = provider.filterStoreId.isEmpty
          ? null
          : provider.filterStoreId;
      unawaited(
        ref
            .read(syncServiceV2Provider)
            .pullSalesFromServer(companyId: companyId, storeId: storeId),
      );
    }

    pullSalesList();
    _salesListRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => pullSalesList(),
    );
  }

  @override
  void dispose() {
    _salesListRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _salesSearchController.removeListener(_onSalesSearchChanged);
    _salesSearchController.dispose();
    super.dispose();
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    if (auth.user != null && company.companies.isEmpty && !company.loading) {
      final userId = auth.user?.id;
      if (userId != null) company.loadCompanies(userId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final currentStoreId = context.read<CompanyProvider>().currentStoreId;
    final provider = context.read<SalesPageProvider>();
    if (companyId == null) {
      if (_invoiceTableLoadedForCompanyId != null) {
        setState(() {
          _invoiceTableLoadedForCompanyId = null;
          _invoiceTablePosEnabled = false;
        });
      }
    } else {
      if (companyId != _invoiceTableLoadedForCompanyId) {
        _invoiceTableLoadedForCompanyId = companyId;
        final cached = SettingsRepository.peekInvoiceTablePosEnabled(companyId);
        if (cached != null) {
          final showTable = cached;
          setState(() => _invoiceTablePosEnabled = showTable);
        }
        SettingsRepository().getInvoiceTablePosEnabled(companyId).then((v) {
          if (!mounted) return;
          if (context.read<CompanyProvider>().currentCompanyId != companyId) {
            return;
          }
          setState(() => _invoiceTablePosEnabled = v);
        });
      }
      if (provider.filterStoreId.isEmpty && currentStoreId != null) {
        provider.setFilters(storeId: currentStoreId);
      }
      provider.loadIfNeeded(companyId);
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null) {
      try {
        await ref
            .read(syncServiceV2Provider)
            .sync(
              userId: userId,
              companyId: company.currentCompanyId,
              storeId: company.currentStoreId,
            );
      } catch (_) {}
    }
  }

  void _openDetail(String saleId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SaleDetailDialog(
        saleId: saleId,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _openEditSale(Sale sale) {
    context.read<CompanyProvider>().setCurrentStoreId(sale.storeId);
    final base = saleOpensOnInvoicePosScreen(sale)
        ? AppRoutes.pos(sale.storeId)
        : AppRoutes.posQuick(sale.storeId);
    context.go('$base?${saleEditQuery(sale.id)}');
  }

  /// RPC `cancel_sale_restore_stock` : P0001 quand la vente n’est plus « compléted » côté serveur (déjà annulée, etc.).
  bool _isCancelSaleNoLongerApplicable(Object e) {
    if (e is! PostgrestException) return false;
    if (e.code?.toString().toUpperCase() != 'P0001') return false;
    final m = e.message;
    return m.contains('Vente déjà annulée') ||
        m.toLowerCase().contains('vente deja annulee');
  }

  Future<void> _cancelSale(Sale sale) async {
    if (!_cancelSaleInFlight.add(sale.id)) return;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Annuler cette vente ?'),
          content: const Text(
            'Le stock sera rétabli. Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Oui, annuler'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final companyId = context.read<CompanyProvider>().currentCompanyId;
      final storeId = context.read<SalesPageProvider>().filterStoreId;
      final params = (
        companyId: companyId ?? '',
        storeId: storeId.isEmpty ? null : storeId,
      );
      try {
        await _repo.cancel(sale.id);
        if (!mounted) return;
        await ref
            .read(appDatabaseProvider)
            .updateLocalSaleStatus(sale.id, 'cancelled');
        if (!mounted) return;
        // Indispensable : [sync] peut être no-op si une sync est déjà en cours (_isSyncing) ;
        // le stock serveur a pourtant déjà changé après le RPC — tirage ciblé immédiat.
        await ref.read(syncServiceV2Provider).pullInventoryQuantitiesForStores([
          sale.storeId,
        ]);
        if (!mounted) return;
        ref.invalidate(inventoryQuantitiesStreamProvider(sale.storeId));
        ref.invalidate(salesStreamProvider(params));
        Future.microtask(() => _refresh());
        if (mounted) AppToast.success(context, 'Vente annulée');
      } catch (e) {
        if (_isCancelSaleNoLongerApplicable(e)) {
          try {
            final serverSale = await _repo.get(sale.id);
            if (!mounted) return;
            if (serverSale != null) {
              await ref
                  .read(appDatabaseProvider)
                  .updateLocalSaleStatus(sale.id, serverSale.status.value);
            } else {
              await ref
                  .read(appDatabaseProvider)
                  .updateLocalSaleStatus(sale.id, 'cancelled');
            }
            if (!mounted) return;
            await ref
                .read(syncServiceV2Provider)
                .pullInventoryQuantitiesForStores([sale.storeId]);
            if (!mounted) return;
            ref.invalidate(inventoryQuantitiesStreamProvider(sale.storeId));
            ref.invalidate(salesStreamProvider(params));
            Future.microtask(() => _refresh());
            if (mounted) {
              AppToast.info(
                context,
                'Cette vente était déjà dans un état non annulable sur le serveur. Liste mise à jour.',
              );
            }
          } catch (_) {
            if (mounted) AppErrorHandler.show(context, e);
          }
        } else {
          if (mounted) AppErrorHandler.show(context, e);
        }
      }
    } finally {
      _cancelSaleInFlight.remove(sale.id);
    }
  }

  Future<void> _purgeCancelledSale(Sale sale) async {
    if (sale.status != SaleStatus.cancelled) return;
    if (!_purgeCancelledInFlight.add(sale.id)) return;
    try {
      final companyId = context.read<CompanyProvider>().currentCompanyId;
      if (companyId == null || companyId.isEmpty || !mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Retirer cette vente de l\'historique ?'),
          content: Text(
            'La vente ${sale.saleNumber} est déjà annulée. Cette suppression est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Non'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Oui, supprimer'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _repo.purgeCancelledAsOwner(
        companyId: companyId,
        saleNumber: sale.saleNumber,
      );
      if (!mounted) return;
      final db = ref.read(appDatabaseProvider);
      await db.deleteLocalSaleItemsBySaleId(sale.id);
      await db.deleteLocalSale(sale.id);
      if (!mounted) return;
      final provider = context.read<SalesPageProvider>();
      final storeIdForStream = provider.filterStoreId.isEmpty
          ? null
          : provider.filterStoreId;
      ref.invalidate(
        salesStreamProvider((companyId: companyId, storeId: storeIdForStream)),
      );
      Future.microtask(() => _refresh());
      if (mounted) AppToast.success(context, 'Vente retirée de l\'historique.');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      _purgeCancelledInFlight.remove(sale.id);
    }
  }

  void _exportCsv(List<Sale> sales) {
    if (sales.isEmpty) return;
    final csv = salesToCsv(sales);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'ventes-$date.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    saveCsvFile(filename: filename, bytes: bytes).then((saved) {
      if (!mounted) return;
      if (saved) AppToast.success(context, 'CSV enregistré');
    });
  }

  List<Sale> _applyFilters(List<Sale> sales, SalesPageProvider provider) {
    var list = sales;
    if (provider.filterStatus != null) {
      list = list.where((s) => s.status == provider.filterStatus).toList();
    }
    final cashierId = provider.filterCashierUserId;
    if (cashierId != null && cashierId.isNotEmpty) {
      list = list.where((s) => s.createdBy == cashierId).toList();
    }
    final q = provider.filterSearch.trim().toLowerCase();
    if (q.isNotEmpty) {
      bool has(String? v) => v != null && v.toLowerCase().contains(q);
      list = list.where((s) {
        if (has(s.saleNumber)) return true;
        if (has(s.createdByLabel)) return true;
        if (has(s.customer?.name)) return true;
        if (has(s.customer?.phone)) return true;
        if (has(s.store?.name)) return true;
        if (formatCurrency(s.total).toLowerCase().contains(q)) return true;
        if (s.id.toLowerCase().contains(q)) return true;
        if (s.createdBy.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }
    if (provider.filterFrom.isNotEmpty) {
      list = list
          .where((s) => s.createdAt.compareTo(provider.filterFrom) >= 0)
          .toList();
    }
    if (provider.filterTo.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.createdAt.compareTo('${provider.filterTo}T23:59:59.999Z') <=
                0,
          )
          .toList();
    }
    return list;
  }

  /// Caissiers présents dans les ventes affichées (libellé depuis le cache membres).
  List<MapEntry<String, String>> _cashierOptionsFromSales(List<Sale> raw) {
    final map = <String, String>{};
    for (final s in raw) {
      final id = s.createdBy;
      if (id.isEmpty) continue;
      if (map.containsKey(id)) continue;
      final label = s.createdByLabel?.trim();
      map[id] = label != null && label.isNotEmpty
          ? label
          : (id.length >= 8 ? 'Utilisateur ${id.substring(0, 8)}…' : id);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>();
    final permissions = context.watch<PermissionsProvider>();
    final provider = context.watch<SalesPageProvider>();
    final companyId = company.currentCompanyId;
    final canAccessSales =
        permissions.hasPermission(Permissions.salesView) ||
        permissions.hasPermission(Permissions.salesCreate) ||
        permissions.hasPermission(Permissions.salesInvoiceA4) ||
        permissions.hasPermission(Permissions.salesUpdate);
    if (permissions.hasLoaded && !canAccessSales) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ventes')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Vous n'avez pas accès à cette page.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final storeIdForStream = provider.filterStoreId.isEmpty
        ? null
        : provider.filterStoreId;
    final asyncSales = ref.watch(
      salesStreamProvider((
        companyId: companyId ?? '',
        storeId: storeIdForStream,
      )),
    );
    final sales = asyncSales.valueOrNull ?? [];
    final filtered = _applyFilters(sales, provider);
    final totalCount = filtered.length;
    final pageCount = totalCount == 0
        ? 0
        : ((totalCount - 1) ~/ _salesPageSize) + 1;
    final filterKey =
        '${provider.filterStoreId}|${provider.filterStatus}|${provider.filterFrom}|${provider.filterTo}|${provider.filterSearch}|${provider.filterCashierUserId ?? ''}';
    if (filterKey != _lastFilterKey) {
      _lastFilterKey = filterKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = 0);
      });
    }
    final effectivePage = pageCount > 0 && _currentPage >= pageCount
        ? pageCount - 1
        : _currentPage;
    if (effectivePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = effectivePage);
      });
    }
    final paginatedList = filtered
        .skip(effectivePage * _salesPageSize)
        .take(_salesPageSize)
        .toList();
    final loading = asyncSales.isLoading;
    final error = asyncSales.hasError && asyncSales.error != null
        ? AppErrorHandler.toUserMessage(asyncSales.error)
        : null;

    final currentStoreId = company.currentStoreId;
    final stores = company.stores;
    Store? currentStore;
    try {
      currentStore = currentStoreId != null
          ? stores.firstWhere((s) => s.id == currentStoreId)
          : null;
    } catch (_) {}
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return CompanyLoadErrorScreen(
        message: company.loadError!,
        title: 'Ventes',
      );
    }
    if (companyId == null) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Ventes')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Ventes',
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

    if (sales.isEmpty && !loading && error == null && !_syncTriggeredForEmpty) {
      _syncTriggeredForEmpty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    if (sales.isNotEmpty) _syncTriggeredForEmpty = false;

    final description = currentStore != null
        ? 'Ventes — ${currentStore.name}'
        : 'Sélectionnez une boutique';

    return Scaffold(
      appBar: null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 20,
            vertical: isWide ? 28 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, description, filtered.length, filtered),
              const SizedBox(height: 24),
              _buildActions(context, currentStoreId, filtered.length, filtered),
              const SizedBox(height: 24),
              _buildFiltersCard(context, stores, provider, sales),
              const SizedBox(height: 24),
              if (error != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                _buildEmptyState(context)
              else ...[
                _buildSalesList(
                  context,
                  isWide,
                  paginatedList,
                  permissions.hasPermission(Permissions.salesUpdate),
                  permissions.isOwner ? _purgeCancelledSale : null,
                ),
                if (pageCount > 1) ...[
                  const SizedBox(height: 16),
                  _buildPagination(
                    context,
                    totalCount,
                    pageCount,
                    effectivePage,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String description,
    int salesCount,
    List<Sale> salesForExport,
  ) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final permissions = context.read<PermissionsProvider>();
    final canCreateSale = permissions.hasPermission(Permissions.salesCreate);
    final filledBtn =
        canCreateSale && context.read<CompanyProvider>().currentStoreId != null
        ? FilledButton.icon(
            onPressed: () {
              final id = context.read<CompanyProvider>().currentStoreId;
              if (id != null) context.go(AppRoutes.posQuick(id));
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Nouvelle vente'),
          )
        : null;
    final actionWidgets = [
      OutlinedButton.icon(
        onPressed: salesCount == 0 ? null : () => _exportCsv(salesForExport),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Enregistrer CSV'),
      ),
      ?filledBtn,
    ];
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ventes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actionWidgets),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventes',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actionWidgets,
                ),
              ),
            ],
          );
  }

  Widget _buildActions(
    BuildContext context,
    String? currentStoreId,
    int salesCount,
    List<Sale> salesForExport,
  ) {
    final permissions = context.read<PermissionsProvider>();
    final canCreateSale = permissions.hasPermission(Permissions.salesCreate);
    final canInvoiceA4 = permissions.hasPermission(Permissions.salesInvoiceA4);
    final canPosInvoice = canInvoiceA4 || canCreateSale;
    final canFactureTab =
        _invoiceTablePosEnabled &&
        permissions.hasPermission(Permissions.salesInvoiceA4Table) &&
        canPosInvoice;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    const double gap = 12.0;

    final cards = <Widget>[
      _ActionCard(
        icon: Icons.point_of_sale_rounded,
        title: 'Caisse rapide',
        subtitle: 'Ticket thermique',
        accent: true,
        enabled: canCreateSale && currentStoreId != null,
        onTap: canCreateSale && currentStoreId != null
            ? () => context.go(AppRoutes.posQuick(currentStoreId))
            : null,
      ),
      if (canInvoiceA4)
        _ActionCard(
          icon: Icons.description_rounded,
          title: 'Facture A4',
          subtitle: 'Vente détaillée',
          accent: true,
          enabled: currentStoreId != null,
          onTap: currentStoreId != null
              ? () => context.go(AppRoutes.pos(currentStoreId))
              : null,
        ),
      if (canFactureTab)
        _ActionCard(
          icon: Icons.table_chart_rounded,
          title: 'Facture A4 (tableau)',
          subtitle: 'Bandeau + tableau',
          accent: true,
          enabled: currentStoreId != null,
          onTap: currentStoreId != null
              ? () => context.go(AppRoutes.factureTab(currentStoreId))
              : null,
        ),
      _ActionCard(
        icon: Icons.shopping_cart_rounded,
        title: 'Historique des ventes',
        subtitle: '$salesCount vente(s)',
        accent: false,
        enabled: true,
        onTap: null,
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            cards[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final spacing = width < 900 ? gap : 20.0;
        final n = cards.length;
        var cols = n;
        if (n >= 4 && maxW < 1100) cols = 2;
        if (n == 3 && maxW < 640) cols = 1;
        final cardW = (maxW - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardW, child: card),
          ],
        );
      },
    );
  }

  Widget _buildFiltersCard(
    BuildContext context,
    List<Store> stores,
    SalesPageProvider provider,
    List<Sale> rawSales,
  ) {
    final theme = Theme.of(context);
    final isMobileFilters = MediaQuery.sizeOf(context).width < 500;
    final seenStoreIds = <String>{};
    final distinctStores = stores.where((s) => seenStoreIds.add(s.id)).toList();
    final storeValue =
        provider.filterStoreId.isNotEmpty &&
            distinctStores.any((s) => s.id == provider.filterStoreId)
        ? provider.filterStoreId
        : null;
    final cashiers = _cashierOptionsFromSales(rawSales);
    final cashierIds = cashiers.map((e) => e.key).toSet();
    final cashierValue =
        provider.filterCashierUserId != null &&
            provider.filterCashierUserId!.isNotEmpty &&
            cashierIds.contains(provider.filterCashierUserId)
        ? provider.filterCashierUserId
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobileFilters ? 16 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtres',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_searchDebouncing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _salesSearchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Recherche : nº vente, client, caissier, boutique, montant…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: _salesSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _salesSearchController.clear();
                          context.read<SalesPageProvider>().setSearchQuery('');
                          if (mounted) {
                            setState(() {
                              _searchDebouncing = false;
                            });
                          }
                        },
                      ),
              ),
              onChanged: (_) {
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: isMobileFilters ? 0 : 12,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: isMobileFilters ? double.infinity : 200,
                  height: 56,
                  child: DropdownButtonFormField<String?>(
                    initialValue: storeValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelText: 'Boutique',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes boutiques'),
                      ),
                      ...distinctStores.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      provider.setFilters(storeId: v ?? '');
                    },
                  ),
                ),
                SizedBox(
                  width: isMobileFilters ? double.infinity : 200,
                  height: 56,
                  child: DropdownButtonFormField<String?>(
                    initialValue: cashierValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelText: 'Caissier',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous les caissiers'),
                      ),
                      ...cashiers.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: provider.setCashierFilter,
                  ),
                ),
                SizedBox(
                  width: isMobileFilters ? double.infinity : 160,
                  height: 56,
                  child: DropdownButtonFormField<SaleStatus?>(
                    initialValue: provider.filterStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelText: 'Statut',
                    ),
                    items: [
                      const DropdownMenuItem<SaleStatus?>(
                        value: null,
                        child: Text('Tous'),
                      ),
                      ...SaleStatus.values.map(
                        (s) => DropdownMenuItem<SaleStatus?>(
                          value: s,
                          child: Text(_statusLabels[s] ?? s.name),
                        ),
                      ),
                    ],
                    onChanged: provider.setStatusFilter,
                  ),
                ),
                _DateChip(
                  label: 'Du',
                  value: provider.filterFrom,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null && mounted) {
                      provider.setFromDate(DateFormat('yyyy-MM-dd').format(d));
                    }
                  },
                ),
                _DateChip(
                  label: 'Au',
                  value: provider.filterTo,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null && mounted) {
                      provider.setToDate(DateFormat('yyyy-MM-dd').format(d));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune vente',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez une vente depuis le POS en sélectionnant une boutique.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (context.read<CompanyProvider>().currentStoreId != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  final id = context.read<CompanyProvider>().currentStoreId;
                  if (id != null) context.go(AppRoutes.posQuick(id));
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ouvrir la caisse'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList(
    BuildContext context,
    bool isWide,
    List<Sale> sales,
    bool canEditSale,
    Future<void> Function(Sale)? onPurgeCancelled,
  ) {
    if (isWide) {
      return _SalesTable(
        sales: sales,
        onView: _openDetail,
        onEdit: canEditSale ? _openEditSale : null,
        onCancel: _cancelSale,
        onPurgeCancelled: onPurgeCancelled,
      );
    }
    return _SalesCardList(
      sales: sales,
      onView: _openDetail,
      onEdit: canEditSale ? _openEditSale : null,
      onCancel: _cancelSale,
      onPurgeCancelled: onPurgeCancelled,
    );
  }

  Widget _buildPagination(
    BuildContext context,
    int totalCount,
    int pageCount,
    int currentPageIndex,
  ) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _salesPageSize + 1;
    final end = (currentPageIndex + 1) * _salesPageSize;
    final endClamped = end > totalCount ? totalCount : end;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final padH = isNarrow ? 10.0 : 16.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isNarrow)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$start – $endClamped sur $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton.filled(
              onPressed: currentPageIndex > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: currentPageIndex > 0
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: currentPageIndex > 0
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            SizedBox(width: isNarrow ? 6 : 12),
            if (isNarrow)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page ${currentPageIndex + 1} / $pageCount',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$start – $endClamped / $totalCount',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Page ${currentPageIndex + 1} / $pageCount',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(width: isNarrow ? 6 : 12),
            IconButton.filled(
              onPressed: currentPageIndex < pageCount - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: currentPageIndex < pageCount - 1
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: currentPageIndex < pageCount - 1
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool accent;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final padding = isMobile ? 16.0 : 24.0;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: accent && enabled
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    decoration: BoxDecoration(
                      color:
                          (accent && enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: isMobile ? 28 : 32,
                      color: accent && enabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 14),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(SaleStatus status, BuildContext context) {
  switch (status) {
    case SaleStatus.completed:
      return const Color(0xFF059669);
    case SaleStatus.cancelled:
    case SaleStatus.refunded:
      return const Color(0xFFDC2626);
    case SaleStatus.draft:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({
    required this.sales,
    required this.onView,
    this.onEdit,
    required this.onCancel,
    this.onPurgeCancelled,
  });

  final List<Sale> sales;
  final void Function(String saleId) onView;
  final void Function(Sale sale)? onEdit;
  final void Function(Sale sale) onCancel;
  final Future<void> Function(Sale sale)? onPurgeCancelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ),
          columns: const [
            DataColumn(label: Text('Numéro')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Boutique')),
            DataColumn(label: Text('Vente par')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Actions')),
          ],
          rows: sales.map((s) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    s.saleNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(_documentTypeChip(s, context)),
                DataCell(Text(_formatDateTime(s.createdAt))),
                DataCell(Text(s.store?.name ?? 'Boutique')),
                DataCell(Text(s.createdByLabel ?? '—')),
                DataCell(Text(s.customer?.name ?? '—')),
                DataCell(
                  Text(
                    formatCurrency(s.total),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        s.status,
                        context,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabels[s.status] ?? s.status.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(s.status, context),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_rounded, size: 20),
                        onPressed: () => onView(s.id),
                        tooltip: 'Voir le détail',
                      ),
                      if (s.status == SaleStatus.completed && onEdit != null)
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => onEdit!(s),
                          tooltip: 'Modifier la vente',
                        ),
                      if (s.status == SaleStatus.completed)
                        IconButton(
                          icon: Icon(
                            Icons.cancel_outlined,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => onCancel(s),
                          tooltip: 'Annuler la vente',
                        ),
                      if (s.status == SaleStatus.cancelled &&
                          onPurgeCancelled != null)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => onPurgeCancelled!(s),
                          tooltip: 'Purger (propriétaire)',
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SalesCardList extends StatelessWidget {
  const _SalesCardList({
    required this.sales,
    required this.onView,
    this.onEdit,
    required this.onCancel,
    this.onPurgeCancelled,
  });

  final List<Sale> sales;
  final void Function(String saleId) onView;
  final void Function(Sale sale)? onEdit;
  final void Function(Sale sale) onCancel;
  final Future<void> Function(Sale sale)? onPurgeCancelled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: sales.map((s) {
        final subtitleParts = <String>[
          s.store?.name ?? 'Boutique',
          if (s.createdByLabel != null && s.createdByLabel!.trim().isNotEmpty)
            'Par ${s.createdByLabel!.trim()}',
          if (s.customer?.name != null && s.customer!.name.trim().isNotEmpty)
            s.customer!.name,
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => onView(s.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.saleNumber,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _documentTypeChip(s, context),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              s.status,
                              context,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabels[s.status] ?? s.status.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(s.status, context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(s.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitleParts.join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            formatCurrency(s.total),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 20),
                              onPressed: () => onView(s.id),
                              tooltip: 'Voir le détail',
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                            if (s.status == SaleStatus.completed && onEdit != null)
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: () => onEdit!(s),
                                tooltip: 'Modifier la vente',
                                style: IconButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            if (s.status == SaleStatus.completed)
                              IconButton(
                                icon: Icon(
                                  Icons.cancel_outlined,
                                  size: 20,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () => onCancel(s),
                                tooltip: 'Annuler la vente',
                                style: IconButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            if (s.status == SaleStatus.cancelled &&
                                onPurgeCancelled != null)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => onPurgeCancelled!(s),
                                tooltip: 'Purger (propriétaire)',
                                style: IconButton.styleFrom(
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
