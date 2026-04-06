import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/sale.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../providers/permissions_provider.dart';
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
  final _searchCtrl = TextEditingController();

  String _storeFilter = '';
  bool _storeFilterLockedToAll = false;
  late String _fromYmd;
  late String _toYmd;

  String _sellerId = '';
  _QuickChip _chip = _QuickChip.all;
  _CreditView _view = _CreditView.sale;

  bool _refreshSpin = false;
  CompanyProvider? _companyProvider;
  String? _subscribedCompanyId;

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
  }

  ({String companyId, String? storeId, String fromYmd, String toYmd}) _creditStreamKey(
    String companyId,
  ) {
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
      await ref.read(syncServiceV2Provider).sync(
            userId: userId,
            companyId: companyId,
            storeId: company.currentStoreId,
          );
      ref.invalidate(creditSalesFilteredStreamProvider(_creditStreamKey(companyId)));
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
  void _scheduleRepairInvalidSelections(Set<String> validStoreIds, List<Sale> creditBase) {
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
          ref.invalidate(creditSalesFilteredStreamProvider(_creditStreamKey(cid)));
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
    }
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
    const head =
        'reference,client,telephone,date,boutique,total,encaisse,reste,echeance,statut,retard_jours,vendeur';
    final lines = <String>[head];
    for (final s in filtered) {
      lines.add(
        [
          _escapeCsv(s.saleNumber),
          _escapeCsv(s.customer?.name ?? ''),
          _escapeCsv(s.customer?.phone ?? ''),
          _escapeCsv(_ymdFromCreated(s.createdAt)),
          _escapeCsv(s.store?.name ?? ''),
          _escapeCsv('${s.total}'),
          _escapeCsv('${paidRealized(s)}'),
          _escapeCsv('${remainingTotal(s)}'),
          _escapeCsv(DateFormat('yyyy-MM-dd').format(effectiveDueAt(s))),
          _escapeCsv(creditStatusLabel(creditLineStatus(s))),
          _escapeCsv('${daysOverdue(s)}'),
          _escapeCsv(s.createdByLabel ?? ''),
        ].join(','),
      );
    }
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bytes = Uint8List.fromList(utf8.encode(lines.join('\n')));
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
    } catch (_) {}
    return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  }

  static String _escapeCsv(String v) {
    const sep = ',';
    const q = '"';
    if (v.contains(sep) || v.contains(q) || v.contains('\n')) {
      return '$q${v.replaceAll(q, '$q$q')}$q';
    }
    return v;
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
      ref.invalidate(creditSalesFilteredStreamProvider(_creditStreamKey(companyId)));
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
      ref.invalidate(creditSalesFilteredStreamProvider(_creditStreamKey(companyId)));
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreditPayDialog(sale: sale, credit: facade, onSuccess: refreshList),
    );
    if (ok == true && mounted) refreshList();
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
    final creditAsync = ref.watch(creditSalesFilteredStreamProvider(_creditStreamKey(companyId)));
    final creditRows = creditAsync.valueOrNull ?? const <Sale>[];
    final creditStreamError = creditAsync.error;
    final creditListLoading = creditAsync.isLoading && !creditAsync.hasValue;

    final open = _openRows(creditRows);
    var totalRem = 0.0;
    var totalPaidOpen = 0.0;
    var totalSaleTotal = 0.0;
    var overdue = 0.0;
    var dueToday = 0.0;
    var dueWeek = 0.0;
    final debtors = <String>{};
    for (final s in open) {
      final rem = remainingTotal(s);
      totalRem += rem;
      totalPaidOpen += paidRealized(s);
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

    final filtered = _filteredSales(creditRows);
    final customerRows = buildCustomerAggregates(filtered);

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
                          isDense: true,
                          isExpanded: true,
                          value: storeDropdownValue,
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
              final textScale =
                  MediaQuery.textScalerOf(ctx).scale(14) / 14.0;
              final mainExtent = (wide ? 128.0 : 158.0) *
                  textScale.clamp(1.0, 1.35);
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
                    formatCurrency(totalPaidOpen),
                    subtitle: 'Dossiers ouverts',
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
                          isDense: true,
                          isExpanded: true,
                          value: sellerDropdownValue,
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
                ? _saleTable(theme, filtered, canPay, companyId)
                : _customerTable(theme, customerRows),
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

  Widget _saleTable(ThemeData theme, List<Sale> sales, bool canPay, String companyId) {
    if (sales.isEmpty) {
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
        rows: sales.map((s) {
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
                Text(s.customer?.name ?? '—', overflow: TextOverflow.ellipsis),
              ),
              DataCell(
                Text(
                  DateFormat('dd/MM/yyyy', 'fr_FR').format(
                    DateTime.tryParse(s.createdAt)?.toLocal() ?? DateTime.now(),
                  ),
                ),
              ),
              DataCell(
                Text(s.store?.name ?? '—', overflow: TextOverflow.ellipsis),
              ),
              DataCell(Text(formatCurrency(s.total), textAlign: TextAlign.end)),
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
        }).toList(),
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
}
