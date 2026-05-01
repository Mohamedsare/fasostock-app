import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/sale.dart';
import '../../data/models/legacy_credit.dart';
import '../../data/repositories/customers_repository.dart';
import '../../data/repositories/legacy_credit_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../shared/utils/csv_export.dart';
import '../../shared/utils/format_currency.dart';
import '../../shared/utils/share_csv.dart';
import 'credit_math.dart';
import 'widgets/credit_detail_sheet.dart';
import 'widgets/credit_pay_dialog.dart';

enum _QuickChip { all, nonPaye, partiel, enRetard, dueToday, dueWeek }

enum _CreditView { sale, customer }

/// Page Crédit — alignée `appweb/components/credit/credit-screen.tsx`.
class CreditPage extends ConsumerStatefulWidget {
  const CreditPage({super.key});

  @override
  ConsumerState<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends ConsumerState<CreditPage> {
  static const int _tablePageSize = 20;
  final _searchCtrl = TextEditingController();
  final WarehouseRepository _warehouseRepo = WarehouseRepository();
  final LegacyCreditRepository _legacyRepo = LegacyCreditRepository();
  final CustomersRepository _customersRepo = CustomersRepository();

  String _storeFilter = '';
  bool _storeFilterLockedToAll = false;
  late String _fromYmd;
  late String _toYmd;

  String _sellerId = '';
  _QuickChip _chip = _QuickChip.all;
  _CreditView _view = _CreditView.sale;

  bool _refreshSpin = false;
  int _salePage = 0;
  int _customerPage = 0;
  int _legacyPage = 0;
  CompanyProvider? _companyProvider;
  String? _subscribedCompanyId;
  final Map<String, double> _dispatchTotalsByInvoiceId = <String, double>{};
  final Set<String> _dispatchTotalsLoading = <String>{};
  final Map<String, String> _dispatchCreatorByInvoiceId = <String, String>{};
  final Set<String> _dispatchCreatorsLoading = <String>{};
  Future<List<LegacyCreditRow>>? _legacyFuture;
  bool _legacyBusy = false;
  List<LegacyCreditRow> _legacyCache = const <LegacyCreditRow>[];
  String? _legacyLoadWarning;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _fromYmd = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(n.year, n.month - 6, n.day));
    _toYmd = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month, n.day));
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureCompanyLoaded();
      final c = context.read<CompanyProvider>();
      _subscriptionToCompany(c);
    });
  }

  void _subscriptionToCompany(CompanyProvider c) {
    if (!identical(_companyProvider, c)) {
      _companyProvider?.removeListener(_onCompanyChanged);
      _companyProvider = c;
      _subscribedCompanyId = c.currentCompanyId;
      c.addListener(_onCompanyChanged);
    }
  }

  void _onCompanyChanged() {
    if (!mounted) return;
    final c = _companyProvider;
    if (c == null) return;
    final id = c.currentCompanyId;
    if (id == _subscribedCompanyId) return;
    _subscribedCompanyId = id;
    _legacyFuture = null;
  }

  ({String companyId, String? storeId, String fromYmd, String toYmd})
  _creditStreamKey(String companyId) {
    final effectiveStore = _storeFilter.isEmpty ? null : _storeFilter;
    return (
      companyId: companyId,
      storeId: effectiveStore,
      fromYmd: _fromYmd,
      toYmd: _toYmd,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.read<CompanyProvider>();
    _subscriptionToCompany(c);
  }

  void _onSearchChanged() => setState(() {});

  double _legacyPaid(LegacyCreditRow row) =>
      row.payments.fold(0.0, (s, p) => s + p.amount);

  double _legacyRemaining(LegacyCreditRow row) =>
      (row.principalAmount - _legacyPaid(row))
          .clamp(0, double.infinity)
          .toDouble();

  int _legacyOverdueDays(LegacyCreditRow row) {
    if (_legacyRemaining(row) <= creditAmountEps) return 0;
    if (row.dueAt == null || row.dueAt!.isEmpty) return 0;
    final due = DateTime.tryParse(row.dueAt!);
    if (due == null) return 0;
    final now = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final nowDay = DateTime(now.year, now.month, now.day);
    final days = nowDay.difference(dueDay).inDays;
    return days > 0 ? days : 0;
  }

  String _legacyStatus(LegacyCreditRow row) {
    final rem = _legacyRemaining(row);
    if (rem <= creditAmountEps) return 'Soldé';
    if (_legacyOverdueDays(row) > 0) return 'En retard';
    if (_legacyPaid(row) <= creditAmountEps) return 'Non payé';
    return 'Partiel';
  }

  String _legacyVendor(String? internalNote) {
    const prefix = '__VENDEUR__:';
    final raw = (internalNote ?? '').trim();
    if (!raw.startsWith(prefix)) return 'OUEDRAOGO BOUBA';
    final payloadRaw = raw.substring(prefix.length).trim();
    try {
      final payload = jsonDecode(payloadRaw);
      if (payload is Map) {
        final vendor = (payload['vendor'] ?? '').toString().trim();
        if (vendor.isNotEmpty) return vendor;
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: const {'phase': 'legacy_vendor_from_internal_note'},
      );
    }
    return 'OUEDRAOGO BOUBA';
  }

  String _buildLegacyInternalNote(String vendor, String note) {
    final v = vendor.trim();
    final n = note.trim();
    return '__VENDEUR__:${jsonEncode({'vendor': v, 'note': n.isEmpty ? null : n})}';
  }

  Future<void> _reloadLegacyCredits(String companyId) async {
    if (companyId.isEmpty) return;
    if (!mounted) return;
    final future = _legacyRepo
        .list(
          companyId: companyId,
          storeId: _storeFilter.isEmpty ? null : _storeFilter,
          fromYmd: _fromYmd,
          toYmd: _toYmd,
        )
        .then((rows) {
          if (mounted) {
            setState(() {
              _legacyCache = rows;
              _legacyLoadWarning = null;
            });
          }
          return rows;
        })
        .catchError((e, st) {
          AppErrorHandler.logWithContext(
            e,
            stackTrace: st,
            logSource: 'credit_page',
            logContext: {
              'phase': 'reload_legacy_credits',
              'company_id': companyId,
              'store_id': _storeFilter.isEmpty ? null : _storeFilter,
            },
          );
          if (mounted) {
            setState(() {
              _legacyLoadWarning = ConnectivityService.instance.isOnline
                  ? 'Impossible de recharger le crédit libre pour le moment.'
                  : 'Mode hors ligne: affichage du dernier état local du crédit libre.';
            });
          }
          return _legacyCache;
        });
    setState(() {
      _legacyFuture = future;
    });
  }

  double _dispatchPaidAmountFromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return 0;
    const marker = '__PAYMENT_INFO__::';
    final text = notes.trim();
    if (!text.startsWith(marker)) return 0;
    try {
      final payload = text.substring(marker.length).trim();
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return 0;
      final paidRaw = decoded['paid_amount'];
      if (paidRaw is num) return paidRaw.toDouble();
      return 0;
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: const {'phase': 'dispatch_paid_amount_from_notes'},
      );
      return 0;
    }
  }

  void _ensureDispatchTotalsLoaded(List<WarehouseDispatchInvoiceSummary> rows) {
    for (final r in rows) {
      if (_dispatchTotalsByInvoiceId.containsKey(r.id) ||
          _dispatchTotalsLoading.contains(r.id)) {
        continue;
      }
      _dispatchTotalsLoading.add(r.id);
      _warehouseRepo
          .getDispatchInvoiceDetails(r.id)
          .then((d) {
            if (!mounted) return;
            setState(() => _dispatchTotalsByInvoiceId[r.id] = d.subtotal);
          })
          .catchError((e, st) {
            AppErrorHandler.logWithContext(
              e,
              stackTrace: st,
              logSource: 'credit_page',
              logContext: {'phase': 'load_dispatch_total', 'invoice_id': r.id},
            );
          })
          .whenComplete(() {
            _dispatchTotalsLoading.remove(r.id);
          });
    }
  }

  void _ensureDispatchCreatorsLoaded(
    String companyId,
    List<WarehouseDispatchInvoiceSummary> rows,
  ) {
    if (companyId.isEmpty || rows.isEmpty) return;
    final missingIds = rows
        .where((r) => !_dispatchCreatorByInvoiceId.containsKey(r.id))
        .map((r) => r.id)
        .where((id) => !_dispatchCreatorsLoading.contains(id))
        .toList();
    if (missingIds.isEmpty) return;
    _dispatchCreatorsLoading.addAll(missingIds);
    _warehouseRepo
        .listDispatchCreatorsByInvoiceId(companyId, invoiceIds: missingIds)
        .then((map) {
          if (!mounted) return;
          setState(() => _dispatchCreatorByInvoiceId.addAll(map));
        })
        .catchError((e, st) {
          AppErrorHandler.logWithContext(
            e,
            stackTrace: st,
            logSource: 'credit_page',
            logContext: {
              'phase': 'load_dispatch_creators',
              'company_id': companyId,
            },
          );
        })
        .whenComplete(() {
          _dispatchCreatorsLoading.removeAll(missingIds);
        });
  }

  @override
  void dispose() {
    _companyProvider?.removeListener(_onCompanyChanged);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensureCompanyLoaded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _refreshData() async {
    final company = context.read<CompanyProvider>();
    final auth = context.read<AuthProvider>();
    final companyId = company.currentCompanyId;
    final userId = auth.user?.id;
    if (companyId == null || companyId.isEmpty || userId == null) return;

    setState(() => _refreshSpin = true);
    try {
      await ref
          .read(syncServiceV2Provider)
          .sync(
            userId: userId,
            companyId: companyId,
            storeId: company.currentStoreId,
          );
      ref.invalidate(
        creditSalesFilteredStreamProvider(_creditStreamKey(companyId)),
      );
      await _reloadLegacyCredits(companyId);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
    } finally {
      if (mounted) setState(() => _refreshSpin = false);
    }
  }

  void _syncStoreWithCompany(CompanyProvider company) {
    if (_storeFilterLockedToAll) return;
    final cur = company.currentStoreId;
    final inList = company.stores.map((s) => s.id).contains(cur);
    if (_storeFilter.isEmpty && cur != null && cur.isNotEmpty && inList) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _storeFilter = cur);
      });
    }
  }

  bool _repairDropdownsPending = false;

  /// Évite l'assert Dropdown : `value` doit exister exactement une fois dans `items`
  /// (boutique pas encore dans la liste, ID obsolète, doublons d'id).
  void _scheduleRepairInvalidSelections(
    Set<String> validStoreIds,
    List<Sale> creditBase,
  ) {
    final badStore =
        _storeFilter.isNotEmpty && !validStoreIds.contains(_storeFilter);
    final sellerOpts = _sellers(creditBase);
    final badSeller =
        _sellerId.isNotEmpty && !sellerOpts.any((e) => e.id == _sellerId);
    if (!badStore && !badSeller) return;
    if (_repairDropdownsPending) return;
    _repairDropdownsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repairDropdownsPending = false;
      if (!mounted) return;
      final ids = context
          .read<CompanyProvider>()
          .stores
          .map((s) => s.id)
          .toSet();
      var needReload = false;
      setState(() {
        if (_storeFilter.isNotEmpty && !ids.contains(_storeFilter)) {
          final cur = context.read<CompanyProvider>().currentStoreId;
          if (cur != null && ids.contains(cur)) {
            _storeFilter = cur;
            _storeFilterLockedToAll = false;
          } else {
            _storeFilter = '';
            _storeFilterLockedToAll = true;
          }
          needReload = true;
        }
        if (_sellerId.isNotEmpty && !sellerOpts.any((e) => e.id == _sellerId)) {
          _sellerId = '';
        }
      });
      if (needReload && mounted) {
        final cid = context.read<CompanyProvider>().currentCompanyId;
        if (cid != null && cid.isNotEmpty) {
          ref.invalidate(
            creditSalesFilteredStreamProvider(_creditStreamKey(cid)),
          );
        }
      }
    });
  }

  void _onStoreSelected(String? value) {
    final company = context.read<CompanyProvider>();
    final cur = company.currentStoreId ?? '';
    setState(() {
      _storeFilter = value ?? '';
      _storeFilterLockedToAll = _storeFilter != cur;
    });
    final companyId = company.currentCompanyId ?? '';
    _reloadLegacyCredits(companyId);
  }

  Future<void> _pickFromDate() async {
    final initial = DateTime.tryParse('${_fromYmd}T12:00:00') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _fromYmd = DateFormat('yyyy-MM-dd').format(picked);
        if (_toYmd.compareTo(_fromYmd) < 0) _toYmd = _fromYmd;
      });
      final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
      _reloadLegacyCredits(companyId);
    }
  }

  Future<void> _pickToDate() async {
    final initial = DateTime.tryParse('${_toYmd}T12:00:00') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _toYmd = DateFormat('yyyy-MM-dd').format(picked);
        if (_fromYmd.compareTo(_toYmd) > 0) _fromYmd = _toYmd;
      });
      final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
      _reloadLegacyCredits(companyId);
    }
  }

  void _resetCreditFilters() {
    final n = DateTime.now();
    setState(() {
      _fromYmd = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(n.year, n.month - 6, n.day));
      _toYmd = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(n.year, n.month, n.day));
      _searchCtrl.text = '';
      _sellerId = '';
      _chip = _QuickChip.all;
      _view = _CreditView.sale;
    });
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    _reloadLegacyCredits(companyId);
  }

  void _applyQuickRange(int days) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    setState(() {
      _fromYmd = DateFormat('yyyy-MM-dd').format(from);
      _toYmd = DateFormat('yyyy-MM-dd').format(now);
    });
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    _reloadLegacyCredits(companyId);
  }

  bool _matchesChip(Sale s) {
    final rem = remainingTotal(s);
    final paid = paidRealized(s);
    final hasBalance = rem > creditAmountEps;
    final hasEncaisse = paid > creditAmountEps;
    switch (_chip) {
      case _QuickChip.all:
        return true;
      case _QuickChip.nonPaye:
        return hasBalance && !hasEncaisse;
      case _QuickChip.partiel:
        return hasBalance && hasEncaisse;
      case _QuickChip.enRetard:
        return hasBalance && daysOverdue(s) > 0;
      case _QuickChip.dueToday:
        return isDueToday(s) && hasBalance;
      case _QuickChip.dueWeek:
        return isDueThisWeek(s) && hasBalance;
    }
  }

  List<Sale> _openRows(List<Sale> creditBase) =>
      creditBase.where((s) => remainingTotal(s) > creditAmountEps).toList();

  List<Sale> _filteredSales(List<Sale> creditBase) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    final rows = _openRows(creditBase).where((s) {
      if (_sellerId.isNotEmpty && s.createdBy != _sellerId) return false;
      if (!_matchesChip(s)) return false;
      if (q.isEmpty) return true;
      return (s.saleNumber.toLowerCase().contains(q)) ||
          (s.customer?.name ?? '').toLowerCase().contains(q) ||
          (s.customer?.phone ?? '')
              .replaceAll(RegExp(r'\s'), '')
              .contains(numOnly) ||
          '${s.total}'.contains(q) ||
          (s.createdByLabel ?? '').toLowerCase().contains(q);
    }).toList();
    rows.sort((a, b) {
      final db = daysOverdue(b);
      final da = daysOverdue(a);
      if (db != da) return db.compareTo(da);
      return remainingTotal(b).compareTo(remainingTotal(a));
    });
    return rows;
  }

  List<({String id, String label})> _sellers(List<Sale> creditBase) {
    final m = <String, String>{};
    for (final r in _openRows(creditBase)) {
      final uid = r.createdBy;
      if (uid.isEmpty) continue;
      m[uid] = r.createdByLabel ?? r.createdBy;
    }
    final list = m.entries.map((e) => (id: e.key, label: e.value)).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  bool _migrationHint(Object? e) {
    if (e == null) return false;
    return RegExp(
      r'credit_due_at|credit_internal_note|append_sale_payment|schema cache',
      caseSensitive: false,
    ).hasMatch(e.toString());
  }

  void _exportCsv(List<Sale> filtered) {
    const headers = [
      'Référence',
      'Client',
      'Téléphone',
      'Date',
      'Boutique',
      'Total',
      'Encaissé',
      'Reste',
      'Échéance',
      'Statut',
      'Retard (jours)',
      'Vendeur',
    ];
    final rows = filtered.map<List<CsvCell>>((s) {
      return [
        s.saleNumber,
        s.customer?.name ?? '',
        s.customer?.phone ?? '',
        _ymdFromCreated(s.createdAt),
        s.store?.name ?? '',
        formatCsvMoney(s.total),
        formatCsvMoney(paidRealized(s)),
        formatCsvMoney(remainingTotal(s)),
        DateFormat('yyyy-MM-dd').format(effectiveDueAt(s)),
        creditStatusLabel(creditLineStatus(s)),
        daysOverdue(s),
        s.createdByLabel ?? '',
      ];
    }).toList();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final csv = buildCsv(headers: headers, rows: rows, separator: ';');
    final bytes = encodeCsv(csv);
    saveCsvFile(filename: 'credit-ventes-$date.csv', bytes: bytes).then((
      saved,
    ) {
      if (!mounted) return;
      if (saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CSV enregistré')));
      }
    });
  }

  static String _ymdFromCreated(String createdAt) {
    try {
      final d = DateTime.tryParse(createdAt);
      if (d != null) return DateFormat('yyyy-MM-dd').format(d.toLocal());
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: {'phase': 'ymd_from_created', 'created_at': createdAt},
      );
    }
    return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  }

  Color _statusPillBg(CreditLineStatus st, ThemeData theme) {
    switch (st) {
      case CreditLineStatus.solde:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case CreditLineStatus.enRetard:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case CreditLineStatus.partiel:
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case CreditLineStatus.nonPaye:
        return theme.colorScheme.onSurface.withValues(alpha: 0.08);
      case CreditLineStatus.annule:
        return theme.colorScheme.onSurface.withValues(alpha: 0.06);
    }
  }

  Color _statusPillFg(CreditLineStatus st, ThemeData theme) {
    switch (st) {
      case CreditLineStatus.solde:
        return const Color(0xFF047857);
      case CreditLineStatus.enRetard:
        return const Color(0xFFB91C1C);
      case CreditLineStatus.partiel:
        return const Color(0xFFB45309);
      case CreditLineStatus.nonPaye:
        return theme.brightness == Brightness.dark
            ? Colors.white70
            : const Color(0xFF374151);
      case CreditLineStatus.annule:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Color _dueTone(Sale s) {
    switch (dueBadgeVariant(s)) {
      case DueBadgeVariant.late:
        return const Color(0xFFDC2626);
      case DueBadgeVariant.soon:
        return const Color(0xFFD97706);
      case DueBadgeVariant.ok:
        return const Color(0xFF047857);
    }
  }

  Future<void> _openDetail(String saleId, String companyId) async {
    final facade = ref.read(creditSyncFacadeProvider);
    void refreshList() {
      if (!mounted) return;
      ref.invalidate(
        creditSalesFilteredStreamProvider(_creditStreamKey(companyId)),
      );
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
      pageBuilder: (ctx, anim, sec) {
        final h = MediaQuery.sizeOf(ctx).height;
        final w = MediaQuery.sizeOf(ctx).width;
        final panelW = w >= 560 ? 460.0 : w * 0.92;
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelW,
            height: h,
            child: Material(
              elevation: 12,
              clipBehavior: Clip.hardEdge,
              child: CreditDetailSheet(
                saleId: saleId,
                companyId: companyId,
                credit: facade,
                onClose: () => Navigator.of(ctx).pop(),
                onRefreshList: refreshList,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPay(Sale sale, String companyId) async {
    final facade = ref.read(creditSyncFacadeProvider);
    void refreshList() {
      if (!mounted) return;
      ref.invalidate(
        creditSalesFilteredStreamProvider(_creditStreamKey(companyId)),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          CreditPayDialog(sale: sale, credit: facade, onSuccess: refreshList),
    );
    if (ok == true && mounted) refreshList();
  }

  Future<void> _openDispatchDetail(String invoiceId) async {
    if (!ConnectivityService.instance.isOnline) {
      AppToast.info(
        context,
        'Détail du bon disponible après reconnexion internet.',
      );
      return;
    }
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bon de sortie'),
          content: FutureBuilder<WarehouseDispatchInvoiceDetails>(
            future: _warehouseRepo.getDispatchInvoiceDetails(invoiceId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError || !snap.hasData) {
                return const Text('Impossible de charger le détail du bon.');
              }
              final d = snap.data!;
              return SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.documentNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.customerName ?? 'Sans client',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      ...d.lines.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(l.productName)),
                              Text(
                                '${l.quantity} × ${formatCurrency(l.unitPrice)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total ${formatCurrency(d.subtotal)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDispatchPay({
    required String companyId,
    required WarehouseDispatchInvoiceSummary row,
    required double total,
    required double alreadyPaid,
  }) async {
    final remaining = (total - alreadyPaid)
        .clamp(0, double.infinity)
        .toDouble();
    if (remaining <= creditAmountEps) return;
    var method = 'cash';
    var mobileProvider = 'orange_money';
    var submitting = false;
    final amountCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final theme = Theme.of(ctx);
          final canSubmit = !submitting;
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Encaisser (bon de sortie)'),
                const SizedBox(height: 2),
                Text(
                  row.documentNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _miniAmountCard(
                            theme,
                            'Déjà encaissé',
                            formatCurrency(alreadyPaid),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniAmountCard(
                            theme,
                            'Reste',
                            formatCurrency(remaining),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mode de paiement',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Espèces',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: method == 'cash'
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          selected: method == 'cash',
                          selectedColor: const Color(0xFFF97316),
                          backgroundColor: const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: method == 'cash'
                                ? const Color(0xFFEA580C)
                                : const Color(0xFFD1D5DB),
                          ),
                          onSelected: submitting
                              ? null
                              : (_) => setLocal(() => method = 'cash'),
                          showCheckmark: false,
                        ),
                        ChoiceChip(
                          label: Text(
                            'Mobile money',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: method == 'mobile_money'
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          selected: method == 'mobile_money',
                          selectedColor: const Color(0xFFF97316),
                          backgroundColor: const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: method == 'mobile_money'
                                ? const Color(0xFFEA580C)
                                : const Color(0xFFD1D5DB),
                          ),
                          onSelected: submitting
                              ? null
                              : (_) => setLocal(() => method = 'mobile_money'),
                          showCheckmark: false,
                        ),
                        ChoiceChip(
                          label: Text(
                            'Carte',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: method == 'card'
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          selected: method == 'card',
                          selectedColor: const Color(0xFFF97316),
                          backgroundColor: const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: method == 'card'
                                ? const Color(0xFFEA580C)
                                : const Color(0xFFD1D5DB),
                          ),
                          onSelected: submitting
                              ? null
                              : (_) => setLocal(() => method = 'card'),
                          showCheckmark: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (method == 'cash') ...[
                      TextField(
                        controller: amountCtrl,
                        enabled: !submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Montant à encaisser (F CFA)',
                          hintText: 'Ex: 150000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (method == 'mobile_money') ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(mobileProvider),
                        initialValue: mobileProvider,
                        decoration: const InputDecoration(
                          labelText: 'Opérateur',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'orange_money',
                            child: Text('Orange Money'),
                          ),
                          DropdownMenuItem(
                            value: 'moov_money',
                            child: Text('Moov Money'),
                          ),
                          DropdownMenuItem(value: 'wave', child: Text('Wave')),
                        ],
                        onChanged: submitting
                            ? null
                            : (v) => setLocal(
                                () => mobileProvider = v ?? 'orange_money',
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: !canSubmit
                    ? null
                    : () async {
                        double? amount;
                        if (method == 'cash') {
                          final parsed = double.tryParse(
                            amountCtrl.text.trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) return;
                          amount = parsed > remaining ? remaining : parsed;
                        } else {
                          amount = null;
                        }
                        setLocal(() => submitting = true);
                        try {
                          if (ConnectivityService.instance.isOnline) {
                            await _warehouseRepo.appendDispatchPayment(
                              companyId: companyId,
                              invoiceId: row.id,
                              method: method,
                              amount: amount,
                              mobileProvider: method == 'mobile_money'
                                  ? mobileProvider
                                  : null,
                            );
                          } else {
                            await ref
                                .read(appDatabaseProvider)
                                .enqueuePendingAction(
                                  'warehouse_dispatch_append_payment',
                                  jsonEncode({
                                    'company_id': companyId,
                                    'invoice_id': row.id,
                                    'method': method,
                                    'amount': amount,
                                    'mobile_provider': method == 'mobile_money'
                                        ? mobileProvider
                                        : null,
                                  }),
                                );
                          }
                          if (!mounted) return;
                          await _refreshData();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ConnectivityService.instance.isOnline
                                      ? 'Paiement enregistré.'
                                      : 'Paiement enregistré hors ligne. Synchronisation à la reconnexion.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setLocal(() => submitting = false);
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openLegacyCreate(String companyId, String storeId) async {
    final customers = await _customersRepo.list(companyId);
    if (!mounted) return;
    String? customerId = customers.isNotEmpty ? customers.first.id : null;
    final titleCtrl = TextEditingController(text: 'Crédit libre');
    final amountCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau crédit libre'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(customerId),
                    initialValue: customerId,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      border: OutlineInputBorder(),
                    ),
                    items: customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => customerId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Échéance (yyyy-MM-dd)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vendorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vendeur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note interne',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _legacyBusy ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: _legacyBusy
                ? null
                : () async {
                    final amount = double.tryParse(
                      amountCtrl.text.trim().replaceAll(',', '.'),
                    );
                    if (customerId == null || amount == null || amount <= 0) {
                      return;
                    }
                    final authUserId =
                        context.read<AuthProvider>().user?.id ?? 'offline';
                    final currentStoreName = context
                        .read<CompanyProvider>()
                        .currentStore
                        ?.name;
                    setState(() => _legacyBusy = true);
                    try {
                      final cleanTitle = titleCtrl.text.trim().isEmpty
                          ? 'Crédit libre'
                          : titleCtrl.text.trim();
                      final dueAtIso = dueCtrl.text.trim().isEmpty
                          ? null
                          : '${dueCtrl.text.trim()}T12:00:00.000Z';
                      final internal = _buildLegacyInternalNote(
                        vendorCtrl.text.trim(),
                        noteCtrl.text.trim(),
                      );
                      if (ConnectivityService.instance.isOnline) {
                        await _legacyRepo.create(
                          companyId: companyId,
                          storeId: storeId,
                          customerId: customerId!,
                          title: cleanTitle,
                          amount: amount,
                          dueAtIso: dueAtIso,
                          internalNote: internal,
                        );
                      } else {
                        final localId =
                            'pending_legacy_${DateTime.now().millisecondsSinceEpoch}';
                        await ref
                            .read(appDatabaseProvider)
                            .enqueuePendingAction(
                              'legacy_credit_create',
                              jsonEncode({
                                'company_id': companyId,
                                'store_id': storeId,
                                'customer_id': customerId,
                                'title': cleanTitle,
                                'amount': amount,
                                'due_at_iso': dueAtIso,
                                'internal_note': internal,
                              }),
                            );
                        final selected = customers
                            .where((c) => c.id == customerId)
                            .toList();
                        final customer = selected.isNotEmpty
                            ? selected.first
                            : null;
                        final createdAt = DateTime.now()
                            .toUtc()
                            .toIso8601String();
                        final local = LegacyCreditRow(
                          id: localId,
                          companyId: companyId,
                          storeId: storeId,
                          customerId: customerId!,
                          title: cleanTitle,
                          principalAmount: amount,
                          dueAt: dueAtIso,
                          internalNote: internal,
                          createdBy: authUserId,
                          createdAt: createdAt,
                          updatedAt: createdAt,
                          storeName: currentStoreName,
                          customerName: customer?.name,
                          customerPhone: customer?.phone,
                          payments: const <LegacyCreditPayment>[],
                        );
                        _legacyCache = [local, ..._legacyCache];
                      }
                      if (!mounted) return;
                      await _reloadLegacyCredits(companyId);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (!ConnectivityService.instance.isOnline && mounted) {
                        AppToast.success(
                          context,
                          'Crédit libre créé hors ligne. Synchronisation à la reconnexion.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _legacyBusy = false);
                    }
                  },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegacyPay(String companyId, LegacyCreditRow row) async {
    if (row.id.startsWith('pending_legacy_')) {
      AppToast.info(
        context,
        'Ce crédit libre est en attente de synchronisation. Réessayez après reconnexion.',
      );
      return;
    }
    var method = 'cash';
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encaisser crédit libre'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reste: ${formatCurrency(_legacyRemaining(row))}',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(method),
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                    DropdownMenuItem(
                      value: 'mobile_money',
                      child: Text('Mobile money'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('Carte')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Virement'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? 'cash'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Référence',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _legacyBusy ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: _legacyBusy
                ? null
                : () async {
                    final amount = double.tryParse(
                      amountCtrl.text.trim().replaceAll(',', '.'),
                    );
                    if (amount == null || amount <= 0) return;
                    setState(() => _legacyBusy = true);
                    try {
                      final refValue = refCtrl.text.trim().isEmpty
                          ? null
                          : refCtrl.text.trim();
                      if (ConnectivityService.instance.isOnline) {
                        await _legacyRepo.appendPayment(
                          creditId: row.id,
                          method: method,
                          amount: amount,
                          reference: refValue,
                        );
                      } else {
                        await ref
                            .read(appDatabaseProvider)
                            .enqueuePendingAction(
                              'legacy_credit_append_payment',
                              jsonEncode({
                                'credit_id': row.id,
                                'method': method,
                                'amount': amount,
                                'reference': refValue,
                              }),
                            );
                        final createdAt = DateTime.now()
                            .toUtc()
                            .toIso8601String();
                        final payment = LegacyCreditPayment(
                          id: 'pending_pay_${DateTime.now().millisecondsSinceEpoch}',
                          method: method,
                          amount: amount,
                          reference: refValue,
                          createdAt: createdAt,
                        );
                        _legacyCache = _legacyCache.map((r) {
                          if (r.id != row.id) return r;
                          return LegacyCreditRow(
                            id: r.id,
                            companyId: r.companyId,
                            storeId: r.storeId,
                            customerId: r.customerId,
                            title: r.title,
                            principalAmount: r.principalAmount,
                            dueAt: r.dueAt,
                            internalNote: r.internalNote,
                            createdBy: r.createdBy,
                            createdAt: r.createdAt,
                            updatedAt: createdAt,
                            storeName: r.storeName,
                            customerName: r.customerName,
                            customerPhone: r.customerPhone,
                            payments: [...r.payments, payment],
                          );
                        }).toList();
                      }
                      if (!mounted) return;
                      await _reloadLegacyCredits(companyId);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (!ConnectivityService.instance.isOnline && mounted) {
                        AppToast.success(
                          context,
                          'Encaissement enregistré hors ligne. Synchronisation à la reconnexion.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _legacyBusy = false);
                    }
                  },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegacyHistory(LegacyCreditRow row) async {
    final ordered = [...row.payments]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Historique des paiements'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: ordered.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Aucun paiement.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = ordered[i];
                    final when = DateTime.tryParse(p.createdAt);
                    final methodLabel = switch (p.method.trim().toLowerCase()) {
                      'cash' => 'Espèces',
                      'mobile_money' => 'Mobile money',
                      'card' => 'Carte',
                      'transfer' => 'Virement',
                      _ => p.method,
                    };
                    final stamp = when == null
                        ? p.createdAt
                        : DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'fr_FR',
                          ).format(when.toLocal());
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        color: theme.colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatCurrency(p.amount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        methodLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (p.reference != null &&
                                        p.reference!.trim().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          p.reference!.trim(),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            stamp,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

  Future<void> _deleteLegacy(String companyId, LegacyCreditRow row) async {
    if (row.id.startsWith('pending_legacy_')) {
      AppToast.info(
        context,
        'Ce crédit libre est en attente de synchronisation. Réessayez après reconnexion.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce crédit libre ?'),
        content: Text(
          'Supprimer "${row.title}" et son historique de paiements ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _legacyBusy = true);
    try {
      if (ConnectivityService.instance.isOnline) {
        await _legacyRepo.delete(creditId: row.id);
      } else {
        await ref
            .read(appDatabaseProvider)
            .enqueuePendingAction(
              'legacy_credit_delete',
              jsonEncode({'credit_id': row.id}),
            );
        _legacyCache = _legacyCache.where((r) => r.id != row.id).toList();
      }
      if (!mounted) return;
      await _reloadLegacyCredits(companyId);
      if (!ConnectivityService.instance.isOnline && mounted) {
        AppToast.success(
          context,
          'Suppression enregistrée hors ligne. Synchronisation à la reconnexion.',
        );
      }
    } finally {
      if (mounted) setState(() => _legacyBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final company = context.watch<CompanyProvider>();
    final perm = context.watch<PermissionsProvider>();
    _syncStoreWithCompany(company);

    final canExport = perm.hasPermission(Permissions.salesView);
    final canPay = perm.hasPermission(Permissions.salesUpdate);

    if (!perm.hasLoaded || company.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!perm.canAccessCredit) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Crédit',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ventes à crédit et créances clients',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vous n\'avez pas accès à cette section.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      );
    }

    final companyId = company.currentCompanyId ?? '';
    _legacyFuture ??= _legacyRepo.list(
      companyId: companyId,
      storeId: _storeFilter.isEmpty ? null : _storeFilter,
      fromYmd: _fromYmd,
      toYmd: _toYmd,
    );
    final creditAsync = ref.watch(
      creditSalesFilteredStreamProvider(_creditStreamKey(companyId)),
    );
    final dispatchAsync = ref.watch(
      warehouseDispatchInvoicesStreamProvider(companyId),
    );
    final creditRows = creditAsync.valueOrNull ?? const <Sale>[];
    final dispatchRows =
        dispatchAsync.valueOrNull ?? const <WarehouseDispatchInvoiceSummary>[];
    final members =
        ref.watch(companyMembersStreamProvider(companyId)).valueOrNull ??
        const [];
    final memberNameByUserId = <String, String>{
      for (final m in members)
        m.userId: (m.profile?.fullName?.trim().isNotEmpty ?? false)
            ? m.profile!.fullName!.trim()
            : (m.email?.trim().isNotEmpty ?? false)
            ? m.email!.trim()
            : m.userId,
    };
    final creditStreamError = creditAsync.error;
    final creditListLoading = creditAsync.isLoading && !creditAsync.hasValue;
    _ensureDispatchTotalsLoaded(dispatchRows);
    _ensureDispatchCreatorsLoaded(companyId, dispatchRows);

    final open = _openRows(creditRows);
    var totalRem = 0.0;
    var totalPaidAll = 0.0;
    var totalSaleTotal = 0.0;
    var overdue = 0.0;
    var dueToday = 0.0;
    var dueWeek = 0.0;
    final debtors = <String>{};
    for (final s in creditRows) {
      totalPaidAll += paidRealized(s);
    }
    for (final s in open) {
      final rem = remainingTotal(s);
      totalRem += rem;
      totalSaleTotal += s.total;
      final cid = s.customerId;
      if (cid != null) debtors.add(cid);
      if (daysOverdue(s) > 0) overdue += rem;
      if (isDueToday(s)) {
        dueToday += rem;
      } else if (isDueThisWeek(s)) {
        dueWeek += rem;
      }
    }

    for (final d in dispatchRows) {
      final paidRaw = _dispatchPaidAmountFromNotes(d.notes);
      final total = _dispatchTotalsByInvoiceId[d.id];
      final paid = total == null ? paidRaw : paidRaw.clamp(0, total).toDouble();
      final rem = total == null
          ? 0.0
          : (total - paid).clamp(0, double.infinity).toDouble();
      totalPaidAll += paid;
      totalRem += rem;
      totalSaleTotal += total ?? 0;
    }

    final filtered = _filteredSales(creditRows);
    final qDispatch = _searchCtrl.text.trim().toLowerCase();
    final filteredDispatchCredits = dispatchRows.where((d) {
      final total = _dispatchTotalsByInvoiceId[d.id];
      if (total == null) return true;
      final paid = _dispatchPaidAmountFromNotes(d.notes).clamp(0, total);
      final remaining = (total - paid).clamp(0, double.infinity);
      if (remaining <= creditAmountEps) return false;
      if (_sellerId.isNotEmpty) return false;
      switch (_chip) {
        case _QuickChip.all:
          break;
        case _QuickChip.nonPaye:
          if (!(remaining > creditAmountEps && paid <= creditAmountEps)) {
            return false;
          }
          break;
        case _QuickChip.partiel:
          if (!(remaining > creditAmountEps && paid > creditAmountEps)) {
            return false;
          }
          break;
        case _QuickChip.enRetard:
        case _QuickChip.dueToday:
        case _QuickChip.dueWeek:
          return false;
      }
      if (qDispatch.isEmpty) return true;
      final doc = d.documentNumber.toLowerCase();
      final customer = (d.customerName ?? '').toLowerCase();
      final created = d.createdAt.toLowerCase();
      return doc.contains(qDispatch) ||
          customer.contains(qDispatch) ||
          created.contains(qDispatch) ||
          'bon depot'.contains(qDispatch) ||
          'depot'.contains(qDispatch);
    }).toList();
    final customerRows = buildCustomerAggregates(filtered);
    final saleTotalRows = filtered.length + filteredDispatchCredits.length;
    final saleTotalPages = saleTotalRows == 0
        ? 1
        : ((saleTotalRows - 1) ~/ _tablePageSize) + 1;
    final salePage = _salePage.clamp(0, saleTotalPages - 1);
    final saleStart = salePage * _tablePageSize;
    final saleEnd = (saleStart + _tablePageSize).clamp(0, saleTotalRows);
    final salesLen = filtered.length;
    final pagedSales = saleStart >= salesLen
        ? const <Sale>[]
        : filtered.sublist(saleStart, saleEnd.clamp(0, salesLen));
    final dispatchStart = (saleStart - salesLen).clamp(
      0,
      filteredDispatchCredits.length,
    );
    final dispatchEnd = (saleEnd - salesLen).clamp(
      0,
      filteredDispatchCredits.length,
    );
    final pagedDispatchCredits = dispatchStart >= dispatchEnd
        ? const <WarehouseDispatchInvoiceSummary>[]
        : filteredDispatchCredits.sublist(dispatchStart, dispatchEnd);

    final customerTotalRows = customerRows.length;
    final customerTotalPages = customerTotalRows == 0
        ? 1
        : ((customerTotalRows - 1) ~/ _tablePageSize) + 1;
    final customerPage = _customerPage.clamp(0, customerTotalPages - 1);
    final customerStart = customerPage * _tablePageSize;
    final customerEnd = (customerStart + _tablePageSize).clamp(
      0,
      customerTotalRows,
    );
    final pagedCustomerRows = customerRows.isEmpty
        ? const <CustomerCreditAgg>[]
        : customerRows.sublist(customerStart, customerEnd);
    final activeFilterCount =
        (_searchCtrl.text.trim().isNotEmpty ? 1 : 0) +
        (_sellerId.isNotEmpty ? 1 : 0) +
        (_chip != _QuickChip.all ? 1 : 0) +
        (_view != _CreditView.sale ? 1 : 0);

    final storeMap = <String, String>{};
    for (final s in company.stores) {
      if (s.id.isEmpty) continue;
      storeMap[s.id] = s.name;
    }
    final validStoreIds = storeMap.keys.toSet();
    _scheduleRepairInvalidSelections(validStoreIds, creditRows);
    final storeDropdownValue = _storeFilter.isEmpty
        ? ''
        : (validStoreIds.contains(_storeFilter) ? _storeFilter : '');
    final sellerDropdownValue = _sellerId.isEmpty
        ? ''
        : (_sellers(creditRows).any((e) => e.id == _sellerId) ? _sellerId : '');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crédit client',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Encours, échéances, paiements partiels — aligné sur vos ventes complétées avec client',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_migrationHint(creditStreamError))
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base de données à mettre à jour',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Appliquez la migration Supabase (colonnes credit_due_at, fonction append_sale_payment), puis rechargez.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_migrationHint(creditStreamError)) const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BOUTIQUE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(storeDropdownValue),
                          isDense: true,
                          isExpanded: true,
                          initialValue: storeDropdownValue,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Toutes les boutiques'),
                            ),
                            ...storeMap.entries.map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _onStoreSelected,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_fromYmd),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '—',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickToDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_toYmd),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(7),
                        child: const Text('7j'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(30),
                        child: const Text('30j'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(90),
                        child: const Text('90j'),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _refreshSpin ? null : _refreshData,
                        icon: _refreshSpin
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('Actualiser'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _resetCreditFilters,
                        child: const Text('Réinitialiser'),
                      ),
                      if (canExport) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => _exportCsv(filtered),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('CSV'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (ctx, c) {
              final wide = c.maxWidth >= 900;
              final cols = wide ? 3 : 2;
              Widget kpi(
                String label,
                String value, {
                String? subtitle,
                IconData? icon,
                Color? iconBg,
                Color? iconFg,
                bool accent = false,
              }) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    side: accent
                        ? BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 16 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (icon != null)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      (iconBg ??
                                              theme
                                                  .colorScheme
                                                  .primaryContainer)
                                          .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color: iconFg ?? theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              // Hauteur fixe : avec 2 colonnes, childAspectRatio ~1.45 rendait les cartes trop basses
              // (label + montant + sous-titre → overflow vertical sur mobile).
              final textScale = MediaQuery.textScalerOf(ctx).scale(14) / 14.0;
              final mainExtent =
                  (wide ? 128.0 : 158.0) * textScale.clamp(1.0, 1.35);
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: mainExtent,
                ),
                children: [
                  kpi(
                    'Restant à recouvrer',
                    formatCurrency(totalRem),
                    icon: Icons.account_balance_wallet,
                    iconBg: const Color(0xFFE85D2C).withValues(alpha: 0.12),
                    iconFg: const Color(0xFFE85D2C),
                    accent: true,
                  ),
                  kpi(
                    'Déjà encaissé',
                    formatCurrency(totalPaidAll),
                    subtitle: 'Tous dossiers',
                    icon: Icons.payments,
                    iconBg: Colors.green.withValues(alpha: 0.12),
                    iconFg: Colors.green.shade700,
                  ),
                  kpi(
                    'Crédit total (ventes)',
                    formatCurrency(totalSaleTotal),
                    subtitle: 'TTC sur la période filtrée',
                    icon: Icons.receipt_long,
                    iconBg: Colors.lightBlue.withValues(alpha: 0.12),
                    iconFg: Colors.blue.shade700,
                  ),
                  kpi(
                    'Ventes avec solde',
                    '${open.length}',
                    icon: Icons.shopping_cart,
                    iconBg: Colors.blue.withValues(alpha: 0.12),
                    iconFg: Colors.blue.shade800,
                  ),
                  kpi(
                    'Clients débiteurs',
                    '${debtors.length}',
                    icon: Icons.people,
                    iconBg: Colors.deepPurple.withValues(alpha: 0.12),
                    iconFg: Colors.deepPurple.shade700,
                  ),
                  kpi(
                    'En retard',
                    formatCurrency(overdue),
                    icon: Icons.warning_amber,
                    iconBg: Colors.red.withValues(alpha: 0.12),
                    iconFg: Colors.red.shade700,
                  ),
                  kpi(
                    'Échéance aujourd\'hui',
                    formatCurrency(dueToday),
                    icon: Icons.today,
                    iconBg: Colors.amber.withValues(alpha: 0.15),
                    iconFg: Colors.amber.shade900,
                  ),
                  kpi(
                    'Échéance cette semaine',
                    formatCurrency(dueWeek),
                    icon: Icons.date_range,
                    iconBg: Colors.teal.withValues(alpha: 0.12),
                    iconFg: Colors.teal.shade800,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Client, téléphone, référence, montant, vendeur…',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String>(sellerDropdownValue),
                          isDense: true,
                          isExpanded: true,
                          initialValue: sellerDropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Vendeur',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tous vendeurs'),
                            ),
                            ..._sellers(creditRows).map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  e.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _sellerId = v ?? ''),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _viewToggle(theme, 'Par vente', _CreditView.sale),
                            _viewToggle(
                              theme,
                              'Par client',
                              _CreditView.customer,
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text('Filtres actifs: $activeFilterCount'),
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        labelStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chipBtn(theme, _QuickChip.all, 'Tous'),
                      _chipBtn(theme, _QuickChip.nonPaye, 'Non payés'),
                      _chipBtn(theme, _QuickChip.partiel, 'Partiels'),
                      _chipBtn(theme, _QuickChip.enRetard, 'En retard'),
                      _chipBtn(theme, _QuickChip.dueToday, 'Échéance jour'),
                      _chipBtn(theme, _QuickChip.dueWeek, 'Échéance semaine'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (creditStreamError != null && !_migrationHint(creditStreamError))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                AppErrorHandler.toUserMessage(
                  creditStreamError,
                  fallback: 'Erreur de chargement',
                ),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: creditListLoading && creditRows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _view == _CreditView.sale
                ? _saleTable(
                    theme,
                    pagedSales,
                    pagedDispatchCredits,
                    memberNameByUserId,
                    canPay,
                    companyId,
                  )
                : _customerTable(theme, pagedCustomerRows),
          ),
          if (_view == _CreditView.sale)
            _tablePager(
              page: salePage,
              totalPages: saleTotalPages,
              start: saleStart,
              end: saleEnd,
              totalItems: saleTotalRows,
              onPrev: salePage > 0
                  ? () => setState(() => _salePage = salePage - 1)
                  : null,
              onNext: salePage < saleTotalPages - 1
                  ? () => setState(() => _salePage = salePage + 1)
                  : null,
            )
          else
            _tablePager(
              page: customerPage,
              totalPages: customerTotalPages,
              start: customerStart,
              end: customerEnd,
              totalItems: customerTotalRows,
              onPrev: customerPage > 0
                  ? () => setState(() => _customerPage = customerPage - 1)
                  : null,
              onNext: customerPage < customerTotalPages - 1
                  ? () => setState(() => _customerPage = customerPage + 1)
                  : null,
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crédit libre (anciens soldes)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Encours hors ventes FasoStock',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (perm.isOwner && _storeFilter.isNotEmpty)
                        FilledButton(
                          onPressed: _legacyBusy
                              ? null
                              : () =>
                                    _openLegacyCreate(companyId, _storeFilter),
                          child: const Text('+ Nouveau'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<LegacyCreditRow>>(
                    future: _legacyFuture,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final rows = (snap.data ?? const <LegacyCreditRow>[])
                          .where((r) => _legacyRemaining(r) > creditAmountEps)
                          .toList();
                      final legacyTotalRows = rows.length;
                      final legacyTotalPages = legacyTotalRows == 0
                          ? 1
                          : ((legacyTotalRows - 1) ~/ _tablePageSize) + 1;
                      final legacyPage = _legacyPage.clamp(
                        0,
                        legacyTotalPages - 1,
                      );
                      final legacyStart = legacyPage * _tablePageSize;
                      final legacyEnd = (legacyStart + _tablePageSize).clamp(
                        0,
                        legacyTotalRows,
                      );
                      final pagedLegacyRows = rows.isEmpty
                          ? const <LegacyCreditRow>[]
                          : rows.sublist(legacyStart, legacyEnd);
                      final totalOpen = rows.fold<double>(
                        0,
                        (s, r) => s + _legacyRemaining(r),
                      );
                      if (rows.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reste total crédit libre: ${formatCurrency(totalOpen)}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Aucun crédit libre ouvert.'),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_legacyLoadWarning != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _legacyLoadWarning!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          Text(
                            'Reste total crédit libre: ${formatCurrency(totalOpen)}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Client')),
                                DataColumn(label: Text('Libellé')),
                                DataColumn(label: Text('Vendeur')),
                                DataColumn(label: Text('Entreprise')),
                                DataColumn(
                                  label: Text('Montant'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Encaissé'),
                                  numeric: true,
                                ),
                                DataColumn(label: Text('Reste'), numeric: true),
                                DataColumn(label: Text('Échéance')),
                                DataColumn(label: Text('Statut')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: pagedLegacyRows.map((r) {
                                final overdue = _legacyOverdueDays(r);
                                return DataRow(
                                  cells: [
                                    DataCell(Text(r.customerName ?? '—')),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          r.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(_legacyVendor(r.internalNote)),
                                    ),
                                    DataCell(
                                      Text(company.currentCompany?.name ?? '—'),
                                    ),
                                    DataCell(
                                      Text(formatCurrency(r.principalAmount)),
                                    ),
                                    DataCell(
                                      Text(
                                        formatCurrency(_legacyPaid(r)),
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        formatCurrency(_legacyRemaining(r)),
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.dueAt == null
                                            ? '—'
                                            : DateFormat(
                                                'dd/MM/yyyy',
                                                'fr_FR',
                                              ).format(
                                                DateTime.tryParse(r.dueAt!) ??
                                                    DateTime.now(),
                                              ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        overdue > 0
                                            ? '${_legacyStatus(r)} (+$overdue j)'
                                            : _legacyStatus(r),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () =>
                                                _openLegacyHistory(r),
                                            child: const Text('Paiements'),
                                          ),
                                          const SizedBox(width: 6),
                                          if (canPay)
                                            FilledButton(
                                              onPressed: () =>
                                                  _openLegacyPay(companyId, r),
                                              child: const Text('Encaisser'),
                                            ),
                                          if (perm.isOwner) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              onPressed: _legacyBusy
                                                  ? null
                                                  : () => _deleteLegacy(
                                                      companyId,
                                                      r,
                                                    ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          _tablePager(
                            page: legacyPage,
                            totalPages: legacyTotalPages,
                            start: legacyStart,
                            end: legacyEnd,
                            totalItems: legacyTotalRows,
                            onPrev: legacyPage > 0
                                ? () => setState(
                                    () => _legacyPage = legacyPage - 1,
                                  )
                                : null,
                            onNext: legacyPage < legacyTotalPages - 1
                                ? () => setState(
                                    () => _legacyPage = legacyPage + 1,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Reçu après paiement : utilisez le détail vente depuis ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => context.go(AppRoutes.sales),
                      child: Text(
                        'Ventes',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' (impression ticket / facture). Rappels SMS / WhatsApp : à brancher côté intégration.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }

  Widget _viewToggle(ThemeData theme, String label, _CreditView v) {
    final sel = _view == v;
    return Material(
      color: sel ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _view = v),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: sel
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipBtn(ThemeData theme, _QuickChip c, String label) {
    final sel = _chip == c;
    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: sel,
      onSelected: (_) => setState(() => _chip = c),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: sel ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _miniAmountCard(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleTable(
    ThemeData theme,
    List<Sale> sales,
    List<WarehouseDispatchInvoiceSummary> dispatchRows,
    Map<String, String> memberNameByUserId,
    bool canPay,
    String companyId,
  ) {
    if (sales.isEmpty && dispatchRows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune ligne pour ces filtres.')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        columns: const [
          DataColumn(label: Text('Réf.')),
          DataColumn(label: Text('Source')),
          DataColumn(label: Text('Client')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Boutique')),
          DataColumn(label: Text('Total'), numeric: true),
          DataColumn(label: Text('Encaissé'), numeric: true),
          DataColumn(label: Text('Reste'), numeric: true),
          DataColumn(label: Text('Échéance')),
          DataColumn(label: Text('Statut')),
          DataColumn(label: Text('Vendeur')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          ...sales.map((s) {
            final st = creditLineStatus(s);
            final rem = remainingTotal(s);
            final overdueDays = daysOverdue(s);
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    s.saleNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Vente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    s.customer?.name ?? '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    DateFormat('dd/MM/yyyy', 'fr_FR').format(
                      DateTime.tryParse(s.createdAt)?.toLocal() ??
                          DateTime.now(),
                    ),
                  ),
                ),
                DataCell(
                  Text(s.store?.name ?? '—', overflow: TextOverflow.ellipsis),
                ),
                DataCell(
                  Text(formatCurrency(s.total), textAlign: TextAlign.end),
                ),
                DataCell(
                  Text(
                    formatCurrency(paidRealized(s)),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    formatCurrency(rem),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: _dueTone(s),
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: DateFormat(
                            'dd/MM/yyyy',
                            'fr_FR',
                          ).format(effectiveDueAt(s)),
                        ),
                        if (overdueDays > 0)
                          TextSpan(
                            text: ' (+$overdueDays j)',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusPillBg(st, theme),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      creditStatusLabel(st),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _statusPillFg(st, theme),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    s.createdByLabel ?? '—',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _openDetail(s.id, companyId),
                        child: const Text('Voir'),
                      ),
                      if (canPay && rem > creditAmountEps)
                        FilledButton(
                          onPressed: () => _openPay(s, companyId),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Encaisser'),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
          ...dispatchRows.map((d) {
            final total = _dispatchTotalsByInvoiceId[d.id];
            final paidRaw = _dispatchPaidAmountFromNotes(d.notes);
            final paid = total == null
                ? paidRaw
                : paidRaw.clamp(0, total).toDouble();
            final remaining = total == null
                ? null
                : (total - paid).clamp(0, double.infinity).toDouble();
            final hasBalance = remaining == null || remaining > creditAmountEps;
            final hasPaid = paid > creditAmountEps;
            final status = !hasBalance
                ? CreditLineStatus.solde
                : hasPaid
                ? CreditLineStatus.partiel
                : CreditLineStatus.nonPaye;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    d.documentNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Bon dépôt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.lightBlue.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(d.customerName ?? '—')),
                DataCell(
                  Text(
                    DateFormat('dd/MM/yyyy', 'fr_FR').format(
                      DateTime.tryParse(d.createdAt)?.toLocal() ??
                          DateTime.now(),
                    ),
                  ),
                ),
                const DataCell(Text('Dépôt')),
                DataCell(Text(total == null ? '…' : formatCurrency(total))),
                DataCell(
                  Text(
                    formatCurrency(paid),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    remaining == null ? '…' : formatCurrency(remaining),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(const Text('—')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusPillBg(status, theme),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      creditStatusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _statusPillFg(status, theme),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    memberNameByUserId[_dispatchCreatorByInvoiceId[d.id]] ??
                        _dispatchCreatorByInvoiceId[d.id] ??
                        d.createdBy ??
                        '—',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _openDispatchDetail(d.id),
                        child: const Text('Voir'),
                      ),
                      if (canPay &&
                          remaining != null &&
                          remaining > creditAmountEps) ...[
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: total == null
                              ? null
                              : () => _openDispatchPay(
                                  companyId: companyId,
                                  row: d,
                                  total: total,
                                  alreadyPaid: paid,
                                ),
                          child: const Text('Encaisser'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _customerTable(ThemeData theme, List<CustomerCreditAgg> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun client débiteur pour ces filtres.')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        columns: const [
          DataColumn(label: Text('Client')),
          DataColumn(label: Text('Tél.')),
          DataColumn(label: Text('Crédits')),
          DataColumn(label: Text('Total dû'), numeric: true),
          DataColumn(label: Text('En retard'), numeric: true),
          DataColumn(label: Text('Dernier paiement')),
          DataColumn(label: Text('Proch. échéance')),
          DataColumn(label: Text('Risque')),
          DataColumn(label: Text('Action')),
        ],
        rows: rows.map((c) {
          final riskLabel = c.risk == 'critique'
              ? 'Critique'
              : c.risk == 'attention'
              ? 'Attention'
              : 'Normal';
          final riskBg = c.risk == 'critique'
              ? Colors.red.withValues(alpha: 0.2)
              : c.risk == 'attention'
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.15);
          final riskFg = c.risk == 'critique'
              ? Colors.red.shade900
              : c.risk == 'attention'
              ? Colors.amber.shade900
              : Colors.green.shade800;
          return DataRow(
            cells: [
              DataCell(
                Text(
                  c.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DataCell(Text(c.phone ?? '—', overflow: TextOverflow.ellipsis)),
              DataCell(Text('${c.openSaleCount}')),
              DataCell(
                Text(
                  formatCurrency(c.totalDue),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  formatCurrency(c.overdueAmount),
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
              DataCell(
                Text(
                  c.lastPaymentAt != null
                      ? DateFormat(
                          'dd/MM/yyyy',
                          'fr_FR',
                        ).format(c.lastPaymentAt!.toLocal())
                      : '—',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DataCell(
                Text(
                  c.nextDueAt != null
                      ? DateFormat('dd/MM/yyyy', 'fr_FR').format(c.nextDueAt!)
                      : '—',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: riskBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    riskLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: riskFg,
                    ),
                  ),
                ),
              ),
              DataCell(
                TextButton(
                  onPressed: () => context.go(AppRoutes.customers),
                  child: const Text('Clients'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _tablePager({
    required int page,
    required int totalPages,
    required int start,
    required int end,
    required int totalItems,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    if (totalItems <= _tablePageSize) return const SizedBox.shrink();
    final startLabel = totalItems == 0 ? 0 : start + 1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$startLabel – $end sur $totalItems',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 6),
          Text('Page ${page + 1} / $totalPages'),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
