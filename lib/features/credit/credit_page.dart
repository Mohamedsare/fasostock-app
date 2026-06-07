import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../core/connectivity/connectivity_service.dart';
import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/credit_repayment_receipt_number.dart';
import '../../core/utils/operation_datetime.dart';
import '../../data/models/append_payment_result.dart';
import '../../data/models/sale.dart';
import '../../data/models/legacy_credit.dart';
import '../../data/models/store.dart';
import '../../data/repositories/customers_repository.dart';
import '../../data/repositories/stores_repository.dart';
import '../../data/repositories/legacy_credit_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../shared/utils/csv_export.dart';
import '../../shared/utils/format_currency.dart';
import '../../shared/widgets/mobile/fs_mobile_page_header.dart';
import '../../shared/utils/save_bytes_file.dart';
import '../../shared/utils/share_csv.dart';
import '../../shared/widgets/fs_horizontal_scroll.dart';
import '../pos/services/invoice_a4_pdf_service.dart';
import 'credit_math.dart';
import 'widgets/credit_detail_sheet.dart';
import 'widgets/credit_pay_dialog.dart';

/// Couleur d'accent des reçus crédit : valeur embarquée API d’abord, puis boutique du document (multi-magasins).
String? _resolvedCreditReceiptPrimaryHex({
  String? fromEmbeddedSale,
  required Store? receiptStore,
  required Store? currentStore,
}) {
  for (final h in <String?>[
    fromEmbeddedSale,
    receiptStore?.primaryColor,
    currentStore?.primaryColor,
  ]) {
    final t = h?.trim();
    if (t != null && t.isNotEmpty) return t;
  }
  return null;
}

int? _parseStoreColorStringToInt32(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  final rgba = RegExp(
    r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})',
    caseSensitive: false,
  ).firstMatch(s);
  if (rgba != null) {
    final r = int.tryParse(rgba.group(1)!);
    final g = int.tryParse(rgba.group(2)!);
    final b = int.tryParse(rgba.group(3)!);
    if (r != null &&
        g != null &&
        b != null &&
        r <= 255 &&
        g <= 255 &&
        b <= 255) {
      return 0xFF000000 | (r << 16) | (g << 8) | b;
    }
  }
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 8) {
    s = s.substring(2);
  }
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return 0xFF000000 | v;
}

PdfColor _creditReceiptAccentPdf(String? hex) {
  final v = _parseStoreColorStringToInt32(hex);
  if (v != null) return PdfColor.fromInt(v);
  return const PdfColor.fromInt(0xFFF97316);
}

enum _QuickChip { all, nonPaye, partiel, enRetard, dueToday, dueWeek, soldes }

/// Ligne « Top relance » — aligné `topRelanceRows` (web).
class _RelanceRow {
  const _RelanceRow({
    required this.key,
    required this.customerName,
    this.phone,
    required this.openCount,
    required this.totalDue,
    required this.overdueDue,
    required this.maxDelayDays,
    required this.dueTodayDue,
  });

  final String key;
  final String customerName;
  final String? phone;
  final int openCount;
  final double totalDue;
  final double overdueDue;
  final int maxDelayDays;
  final double dueTodayDue;
}

class _RelanceAccum {
  String customerName = '';
  String? phone;
  double totalDue = 0;
  double overdueDue = 0;
  double dueTodayDue = 0;
  int openCount = 0;
  int maxDelayDays = 0;
}

class _CreditRepaymentReceiptData {
  const _CreditRepaymentReceiptData({
    required this.receiptNumber,
    required this.issuedAt,
    required this.companyName,
    required this.storeId,
    required this.store,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.storeLogoUrl,
    required this.customerName,
    required this.customerPhone,
    required this.creditTitle,
    required this.paymentMethodLabel,
    required this.paymentReference,
    required this.amountPaid,
    required this.amountTendered,
    required this.changeDue,
    required this.previousBalance,
    required this.newBalance,
    required this.settled,
    required this.note,
    this.embeddedStorePrimaryHex,
  });

  final String receiptNumber;
  final DateTime issuedAt;
  final String companyName;
  final String? storeId;
  final Store? store;
  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? storeLogoUrl;
  final String customerName;
  final String? customerPhone;
  final String creditTitle;
  final String paymentMethodLabel;
  final String? paymentReference;
  final double amountPaid;
  final double? amountTendered;
  final double? changeDue;
  final double previousBalance;
  final double newBalance;
  final bool settled;
  final String? note;

  /// `stores.primary_color` depuis le détail vente/API (liste `CompanyProvider` souvent périmère).
  final String? embeddedStorePrimaryHex;
}

enum _CreditView { sale, customer }

enum _SettledHistoryKind { creditLibre, venteNormale }

/// Ligne d’« Historique soldé » : crédit libre (legacy) ou vente POS soldée.
class _SettledHistoryRow {
  const _SettledHistoryRow.creditLibre(this.legacy)
    : kind = _SettledHistoryKind.creditLibre,
      sale = null;
  const _SettledHistoryRow.venteNormale(this.sale)
    : kind = _SettledHistoryKind.venteNormale,
      legacy = null;

  final _SettledHistoryKind kind;
  final LegacyCreditRow? legacy;
  final Sale? sale;
}

/// Page Crédit — alignée `appweb/components/credit/credit-screen.tsx`.
class CreditPage extends ConsumerStatefulWidget {
  const CreditPage({super.key});

  @override
  ConsumerState<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends ConsumerState<CreditPage> {
  static const int _tablePageSize = 20;
  /// Décalle le filtrage après la frappe ; un peu plus court pour coller à la saisie.
  static const Duration _searchDebounce = Duration(milliseconds: 140);
  final _searchCtrl = TextEditingController();
  final _legacySearchCtrl = TextEditingController();
  final _legacyHistorySearchCtrl = TextEditingController();
  String _appliedMainSearchText = '';
  String _appliedLegacySectionText = '';
  String _appliedLegacyHistoryText = '';
  Timer? _debounceAppliedMain;
  Timer? _debounceAppliedLegacySection;
  Timer? _debounceAppliedLegacyHist;
  final WarehouseRepository _warehouseRepo = WarehouseRepository();
  final LegacyCreditRepository _legacyRepo = LegacyCreditRepository();
  final CustomersRepository _customersRepo = CustomersRepository();

  String _storeFilter = '';
  late String _fromYmd;
  late String _toYmd;

  String _sellerId = '';
  _QuickChip _chip = _QuickChip.all;
  _CreditView _view = _CreditView.sale;

  bool _refreshSpin = false;
  int _salePage = 0;
  int _customerPage = 0;
  int _legacyPage = 0;
  /// Pagination « Historique — crédits libres soldés » (indépendante du crédit libre ouvert).
  int _legacySettledPage = 0;
  bool _legacyShowSettled = true;
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
  _CreditRepaymentReceiptData? _receiptData;
  RealtimeChannel? _legacyRealtimeChannel;
  RealtimeChannel? _dispatchRealtimeChannel;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _legacyRealtimeDebounce;
  Timer? _dispatchRealtimeDebounce;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _fromYmd = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime(n.year, n.month - 6, n.day));
    _toYmd = DateFormat('yyyy-MM-dd').format(DateTime(n.year, n.month, n.day));
    _searchCtrl.addListener(_onSearchChanged);
    _legacySearchCtrl.addListener(_onLegacySearchChanged);
    _legacyHistorySearchCtrl.addListener(_onLegacyHistorySearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureCompanyLoaded();
      final c = context.read<CompanyProvider>();
      _subscriptionToCompany(c);
      _initLegacyRealtime();
      _initDispatchRealtime();
    });
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((
      online,
    ) {
      if (!mounted) return;
      if (online) {
        _initLegacyRealtime();
        _initDispatchRealtime();
        unawaited(_refreshData());
      } else {
        _legacyRealtimeChannel?.unsubscribe();
        _legacyRealtimeChannel = null;
        _dispatchRealtimeChannel?.unsubscribe();
        _dispatchRealtimeChannel = null;
      }
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
    _initLegacyRealtime();
    _initDispatchRealtime();
  }

  void _scheduleLegacyRealtimeReload() {
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    if (companyId.isEmpty || !ConnectivityService.instance.isOnline) return;
    _legacyRealtimeDebounce?.cancel();
    _legacyRealtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _reloadLegacyCredits(companyId);
    });
  }

  void _initLegacyRealtime() {
    _legacyRealtimeChannel?.unsubscribe();
    _legacyRealtimeChannel = null;
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    if (companyId.isEmpty || !ConnectivityService.instance.isOnline) return;

    final channelName =
        'credit-legacy-$companyId-${_storeFilter.isEmpty ? "all" : _storeFilter}';
    final channel = Supabase.instance.client.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'legacy_customer_credits',
      callback: (_) => _scheduleLegacyRealtimeReload(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'legacy_customer_credit_payments',
      callback: (_) => _scheduleLegacyRealtimeReload(),
    );
    channel.subscribe();
    _legacyRealtimeChannel = channel;
  }

  void _scheduleDispatchRealtimeReload() {
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    if (companyId.isEmpty || !ConnectivityService.instance.isOnline) return;
    _dispatchRealtimeDebounce?.cancel();
    _dispatchRealtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.invalidate(warehouseDispatchInvoicesStreamProvider(companyId));
      setState(() {
        _dispatchTotalsByInvoiceId.clear();
        _dispatchCreatorByInvoiceId.clear();
      });
    });
  }

  void _initDispatchRealtime() {
    _dispatchRealtimeChannel?.unsubscribe();
    _dispatchRealtimeChannel = null;
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    if (companyId.isEmpty || !ConnectivityService.instance.isOnline) return;
    final channel = Supabase.instance.client.channel('credit-dispatch-$companyId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'warehouse_dispatch_invoices',
      callback: (_) => _scheduleDispatchRealtimeReload(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'warehouse_dispatch_invoice_lines',
      callback: (_) => _scheduleDispatchRealtimeReload(),
    );
    channel.subscribe();
    _dispatchRealtimeChannel = channel;
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

  void _cancelSearchDebounces() {
    _debounceAppliedMain?.cancel();
    _debounceAppliedMain = null;
    _debounceAppliedLegacySection?.cancel();
    _debounceAppliedLegacySection = null;
    _debounceAppliedLegacyHist?.cancel();
    _debounceAppliedLegacyHist = null;
  }

  /// Applique le filtre hors du flux synchrone IME / notifier : [setState] après le prochain tick
  /// d’event loop, avec rejet si le texte a encore changé (anti-course après debounce).
  void _creditSearchApplyAsyncIfUnchanged(
    TextEditingController c,
    String snapshot,
    VoidCallback update,
  ) {
    Future<void>.delayed(Duration.zero, () {
      if (!mounted) return;
      if (c.text != snapshot) return;
      setState(update);
    });
  }

  void _scheduleAppliedMainSearch() {
    _debounceAppliedMain?.cancel();
    final raw = _searchCtrl.text;
    if (raw.trim().isEmpty) {
      _debounceAppliedMain = null;
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) return;
        if (_searchCtrl.text.trim().isNotEmpty) return;
        setState(() {
          _appliedMainSearchText = '';
          _salePage = 0;
          _customerPage = 0;
          _legacyPage = 0;
          _legacySettledPage = 0;
        });
      });
      return;
    }
    _debounceAppliedMain = Timer(_searchDebounce, () {
      if (!mounted) return;
      final snapshot = _searchCtrl.text;
      _creditSearchApplyAsyncIfUnchanged(_searchCtrl, snapshot, () {
        _appliedMainSearchText = snapshot;
        _salePage = 0;
        _customerPage = 0;
        _legacyPage = 0;
        _legacySettledPage = 0;
      });
    });
  }

  void _onSearchChanged() => _scheduleAppliedMainSearch();

  void _scheduleAppliedLegacySection() {
    _debounceAppliedLegacySection?.cancel();
    final raw = _legacySearchCtrl.text;
    if (raw.trim().isEmpty) {
      _debounceAppliedLegacySection = null;
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) return;
        if (_legacySearchCtrl.text.trim().isNotEmpty) return;
        setState(() {
          _appliedLegacySectionText = '';
          _legacyPage = 0;
          _legacySettledPage = 0;
        });
      });
      return;
    }
    _debounceAppliedLegacySection = Timer(_searchDebounce, () {
      if (!mounted) return;
      final snapshot = _legacySearchCtrl.text;
      _creditSearchApplyAsyncIfUnchanged(_legacySearchCtrl, snapshot, () {
        _appliedLegacySectionText = snapshot;
        _legacyPage = 0;
        _legacySettledPage = 0;
      });
    });
  }

  void _onLegacySearchChanged() => _scheduleAppliedLegacySection();

  void _scheduleAppliedLegacyHist() {
    _debounceAppliedLegacyHist?.cancel();
    final raw = _legacyHistorySearchCtrl.text;
    if (raw.trim().isEmpty) {
      _debounceAppliedLegacyHist = null;
      Future<void>.delayed(Duration.zero, () {
        if (!mounted) return;
        if (_legacyHistorySearchCtrl.text.trim().isNotEmpty) return;
        setState(() {
          _appliedLegacyHistoryText = '';
          _legacySettledPage = 0;
        });
      });
      return;
    }
    _debounceAppliedLegacyHist = Timer(_searchDebounce, () {
      if (!mounted) return;
      final snapshot = _legacyHistorySearchCtrl.text;
      _creditSearchApplyAsyncIfUnchanged(_legacyHistorySearchCtrl, snapshot, () {
        _appliedLegacyHistoryText = snapshot;
        _legacySettledPage = 0;
      });
    });
  }

  void _onLegacyHistorySearchChanged() => _scheduleAppliedLegacyHist();

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

  /// Aligné `parseDispatchPaymentInfo` (web `credit-screen.tsx`).
  ({String mode, double paidAmount}) _parseDispatchPaymentInfo(
    String? notes,
    double totalAmount,
  ) {
    final raw = (notes ?? '').trim();
    if (!raw.startsWith('__PAYMENT_INFO__')) {
      return (mode: 'credit', paidAmount: 0.0);
    }
    final payloadRaw = raw.startsWith('__PAYMENT_INFO__::')
        ? raw.substring('__PAYMENT_INFO__::'.length).trim()
        : raw.startsWith('__PAYMENT_INFO__:')
        ? raw.substring('__PAYMENT_INFO__:'.length).trim()
        : '';
    if (payloadRaw.isEmpty) {
      return (mode: 'credit', paidAmount: 0.0);
    }
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) throw FormatException('not a map');
      final modeStr = (decoded['mode'] ?? 'credit').toString();
      final paidRaw = decoded['paid_amount'];
      final paidNum = paidRaw is num
          ? paidRaw.toDouble()
          : double.tryParse('$paidRaw') ?? 0.0;
      if (modeStr == 'cash') {
        final paid = paidNum.clamp(0, totalAmount).toDouble();
        return (mode: 'cash', paidAmount: paid);
      }
      if (modeStr == 'credit') {
        return (mode: 'credit', paidAmount: 0.0);
      }
      if (modeStr == 'card' || modeStr == 'mobile_money') {
        return (mode: modeStr, paidAmount: totalAmount);
      }
    } catch (e, st) {
      final modeStr = payloadRaw;
      if (modeStr == 'cash') {
        return (mode: 'cash', paidAmount: totalAmount);
      }
      if (modeStr == 'credit') {
        return (mode: 'credit', paidAmount: 0.0);
      }
      if (modeStr == 'card' || modeStr == 'mobile_money') {
        return (mode: modeStr, paidAmount: totalAmount);
      }
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: const {'phase': 'dispatch_payment_info'},
      );
    }
    return (mode: 'credit', paidAmount: 0.0);
  }

  double _dispatchPaidAmountFromNotes(String? notes, double totalAmount) {
    return _parseDispatchPaymentInfo(notes, totalAmount).paidAmount;
  }

  String? _humanDispatchNote(String? notes, double totalAmount) {
    final info = _parseDispatchPaymentInfo(notes, totalAmount);
    switch (info.mode) {
      case 'credit':
        return 'Paiement: À crédit (non encaissé)';
      case 'card':
        return 'Paiement: Carte (encaissé)';
      case 'mobile_money':
        return 'Paiement: Mobile money (encaissé)';
      case 'cash':
        return 'Paiement: Espèces (${formatCurrency(info.paidAmount)} encaissé)';
      default:
        return null;
    }
  }

  List<WarehouseDispatchInvoiceSummary> _dispatchInvoicesInPeriod(
    List<WarehouseDispatchInvoiceSummary> rows,
    String fromYmd,
    String toYmd,
  ) {
    late final DateTime start;
    late final DateTime end;
    try {
      start = DateTime.parse('${fromYmd}T00:00:00.000Z');
      end = DateTime.parse('${toYmd}T23:59:59.999Z');
    } catch (_) {
      return rows;
    }
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    return rows.where((r) {
      final d = DateTime.tryParse(r.createdAt);
      if (d == null) return false;
      final ms = d.millisecondsSinceEpoch;
      return ms >= startMs && ms <= endMs;
    }).toList();
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
    _cancelSearchDebounces();
    _legacyRealtimeDebounce?.cancel();
    _dispatchRealtimeDebounce?.cancel();
    _legacyRealtimeChannel?.unsubscribe();
    _dispatchRealtimeChannel?.unsubscribe();
    _connectivitySub?.cancel();
    _companyProvider?.removeListener(_onCompanyChanged);
    _searchCtrl.removeListener(_onSearchChanged);
    _legacySearchCtrl.removeListener(_onLegacySearchChanged);
    _legacyHistorySearchCtrl.removeListener(_onLegacyHistorySearchChanged);
    _searchCtrl.dispose();
    _legacySearchCtrl.dispose();
    _legacyHistorySearchCtrl.dispose();
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
    // Alignement web: par défaut conserver "Toutes les boutiques" (value = '').
    // On ne force plus la boutique courante automatiquement.
    if (_storeFilter.isEmpty) return;
    final ids = company.stores.map((s) => s.id).toSet();
    if (ids.contains(_storeFilter)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _storeFilter = '';
      });
    });
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
          } else {
            _storeFilter = '';
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
    setState(() {
      _storeFilter = value ?? '';
    });
    final companyId = company.currentCompanyId ?? '';
    _reloadLegacyCredits(companyId);
    _initLegacyRealtime();
    _initDispatchRealtime();
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
      _initLegacyRealtime();
      _initDispatchRealtime();
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
      _initLegacyRealtime();
      _initDispatchRealtime();
    }
  }

  void _resetCreditFilters() {
    _cancelSearchDebounces();
    final n = DateTime.now();
    setState(() {
      _fromYmd = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(n.year, n.month - 6, n.day));
      _toYmd = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(n.year, n.month, n.day));
      _searchCtrl.text = '';
      _legacySearchCtrl.text = '';
      _legacyHistorySearchCtrl.text = '';
      _appliedMainSearchText = '';
      _appliedLegacySectionText = '';
      _appliedLegacyHistoryText = '';
      _sellerId = '';
      _chip = _QuickChip.all;
      _view = _CreditView.sale;
      _salePage = 0;
      _customerPage = 0;
      _legacyPage = 0;
      _legacySettledPage = 0;
    });
    final companyId = context.read<CompanyProvider>().currentCompanyId ?? '';
    _reloadLegacyCredits(companyId);
    _initLegacyRealtime();
    _initDispatchRealtime();
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
    _initLegacyRealtime();
    _initDispatchRealtime();
  }

  bool _matchesChip(Sale s) {
    final rem = remainingTotal(s);
    final paid = paidRealized(s);
    final hasBalance = rem > creditAmountEps;
    final hasEncaisse = paid > creditAmountEps;
    switch (_chip) {
      case _QuickChip.soldes:
        if (s.status == SaleStatus.cancelled || s.status == SaleStatus.refunded) {
          return false;
        }
        return saleHadCreditBooking(s) && rem <= creditAmountEps;
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

  /// Aligné `salesTableSource` (web) : période complète si puce « Soldés ».
  List<Sale> _salesTableSource(List<Sale> creditBase) =>
      _chip == _QuickChip.soldes ? creditBase : _openRows(creditBase);

  /// Plus le score est élevé, plus la ligne doit remonter (recherche active).
  int _saleSearchRelevance(Sale s, String q, String numOnly) {
    if (q.isEmpty && numOnly.isEmpty) return 0;
    var score = 0;
    final saleNum = s.saleNumber.toLowerCase();
    final name = (s.customer?.name ?? '').toLowerCase();
    final phoneDigits = (s.customer?.phone ?? '').replaceAll(RegExp(r'\s'), '');
    final seller = (s.createdByLabel ?? '').toLowerCase();
    final tot = '${s.total}';

    void bumpField(String hay, int prefixWt, int containsWt) {
      if (hay.isEmpty || !hay.contains(q)) return;
      score += hay.startsWith(q) ? prefixWt : containsWt;
      score += math.max(0, 28 - math.min(hay.indexOf(q), 28));
    }

    bumpField(saleNum, 120, 56);
    bumpField(name, 112, 52);
    if (numOnly.isNotEmpty && phoneDigits.contains(numOnly)) {
      score += phoneDigits.startsWith(numOnly) ? 92 : 50;
      score += math.max(0, 16 - math.min(phoneDigits.indexOf(numOnly), 16));
    }
    if (tot.contains(q)) score += 40;
    bumpField(seller, 42, 26);
    return score;
  }

  /// Filtrage texte sur une vente (recherche principale / historique / etc.).
  bool _saleRowMatchesSingleQuery(Sale s, String qRaw) {
    final q = qRaw.trim().toLowerCase();
    if (q.isEmpty) return true;
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    return s.saleNumber.toLowerCase().contains(q) ||
        (s.customer?.name ?? '').toLowerCase().contains(q) ||
        (s.customer?.phone ?? '')
            .replaceAll(RegExp(r'\s'), '')
            .contains(numOnly) ||
        '${s.total}'.contains(q) ||
        (s.createdByLabel ?? '').toLowerCase().contains(q) ||
        (s.store?.name ?? '').toLowerCase().contains(q) ||
        s.id.toLowerCase().contains(q);
  }

  int _saleRowRelevanceAgainstQuery(Sale s, String qRaw) {
    final q = qRaw.trim().toLowerCase();
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    return _saleSearchRelevance(s, q, numOnly);
  }

  bool _isSaleSettledCreditNormale(Sale s) {
    if (s.status == SaleStatus.cancelled || s.status == SaleStatus.refunded) {
      return false;
    }
    return saleHadCreditBooking(s) && remainingTotal(s) <= creditAmountEps;
  }

  List<Sale> _settledSalesMatchingMainOnly(List<Sale> creditBase) {
    return creditBase.where((s) {
      if (!_isSaleSettledCreditNormale(s)) return false;
      if (_sellerId.isNotEmpty && s.createdBy != _sellerId) return false;
      return _saleRowMatchesSingleQuery(s, _appliedMainSearchText);
    }).toList();
  }

  List<Sale> _settledSalesMatchingMainAndHistory(List<Sale> creditBase) {
    return _settledSalesMatchingMainOnly(creditBase)
        .where((s) => _saleRowMatchesSingleQuery(s, _appliedLegacyHistoryText))
        .toList();
  }

  int _saleSettledHistoryRelevance(Sale s) =>
      _saleRowRelevanceAgainstQuery(s, _appliedMainSearchText) +
      _saleRowRelevanceAgainstQuery(s, _appliedLegacyHistoryText);

  int _customerAggSearchRelevance(
    CustomerCreditAgg c,
    String q,
    String numOnly,
  ) {
    if (q.isEmpty && numOnly.isEmpty) return 0;
    var score = 0;
    final name = c.customerName.toLowerCase();
    final phoneDigits = (c.phone ?? '').replaceAll(RegExp(r'\s'), '');
    if (name.contains(q)) {
      score += name.startsWith(q) ? 115 : 54;
      score += math.max(0, 28 - math.min(name.indexOf(q), 28));
    }
    if (numOnly.isNotEmpty && phoneDigits.contains(numOnly)) {
      score += phoneDigits.startsWith(numOnly) ? 95 : 52;
      score += math.max(0, 16 - math.min(phoneDigits.indexOf(numOnly), 16));
    }
    return score;
  }

  int _dispatchSearchRelevance(
    WarehouseDispatchInvoiceSummary d,
    String q,
    double? totalKnown,
  ) {
    if (q.isEmpty) return 0;
    var score = 0;
    final doc = d.documentNumber.toLowerCase();
    final cust = (d.customerName ?? '').toLowerCase();
    final cre = d.createdAt.toLowerCase();

    void bump(String hay, int prefixWt, int containsWt) {
      if (hay.isEmpty || !hay.contains(q)) return;
      score += hay.startsWith(q) ? prefixWt : containsWt;
      score += math.max(0, 26 - math.min(hay.indexOf(q), 26));
    }

    bump(doc, 118, 55);
    bump(cust, 108, 50);
    if (cre.contains(q)) score += 24;
    if (totalKnown != null && '$totalKnown'.contains(q)) score += 38;
    return score;
  }

  List<Sale> _filteredSales(List<Sale> creditBase) {
    final q = _appliedMainSearchText.trim().toLowerCase();
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    final rows = _salesTableSource(creditBase).where((s) {
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
      if (q.isNotEmpty || numOnly.isNotEmpty) {
        final rab = _saleSearchRelevance(b, q, numOnly);
        final raa = _saleSearchRelevance(a, q, numOnly);
        if (rab != raa) return rab.compareTo(raa);
      }
      final db = daysOverdue(b);
      final da = daysOverdue(a);
      if (db != da) return db.compareTo(da);
      return remainingTotal(b).compareTo(remainingTotal(a));
    });
    return rows;
  }

  bool _legacyRowMatchesSingleQuery(LegacyCreditRow row, String qRaw) {
    final q = qRaw.trim().toLowerCase();
    if (q.isEmpty) return true;
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    final vendor = _legacyVendor(row.internalNote).toLowerCase();
    final paid = _legacyPaid(row);
    final rem = _legacyRemaining(row);
    return (row.customerName ?? '').toLowerCase().contains(q) ||
        (row.customerPhone ?? '')
            .replaceAll(RegExp(r'\s'), '')
            .contains(numOnly) ||
        row.title.toLowerCase().contains(q) ||
        '${row.principalAmount}'.contains(q) ||
        '$paid'.contains(q) ||
        '$rem'.contains(q) ||
        vendor.contains(q) ||
        (row.storeName ?? '').toLowerCase().contains(q) ||
        row.id.toLowerCase().contains(q);
  }

  bool _legacyRowMatchesSearch(LegacyCreditRow row) =>
      _legacyRowMatchesSingleQuery(row, _appliedMainSearchText) &&
      _legacyRowMatchesSingleQuery(row, _appliedLegacySectionText);

  /// Score aligné sur les champs de [_legacyRowMatchesSingleQuery].
  int _legacyRowRelevanceAgainstQuery(LegacyCreditRow row, String qRaw) {
    final q = qRaw.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final numOnly = q.replaceAll(RegExp(r'\s'), '');
    var score = 0;
    final vendor = _legacyVendor(row.internalNote).toLowerCase();
    final name = (row.customerName ?? '').toLowerCase();
    final phoneDigits = (row.customerPhone ?? '').replaceAll(RegExp(r'\s'), '');
    final title = row.title.toLowerCase();
    final store = (row.storeName ?? '').toLowerCase();
    final bid = row.id.toLowerCase();
    final paid = _legacyPaid(row);
    final rem = _legacyRemaining(row);
    final prin = '${row.principalAmount}';
    final paidStr = '$paid';
    final remStr = '$rem';

    void bump(String hay, int prefixWt, int containsWt) {
      if (hay.isEmpty || !hay.contains(q)) return;
      score += hay.startsWith(q) ? prefixWt : containsWt;
      score += math.max(0, 24 - math.min(hay.indexOf(q), 24));
    }

    bump(name, 108, 52);
    bump(title, 92, 46);
    bump(vendor, 40, 22);
    bump(store, 42, 24);
    bump(bid, 38, 24);
    if (numOnly.isNotEmpty && phoneDigits.contains(numOnly)) {
      score += phoneDigits.startsWith(numOnly) ? 94 : 52;
      score +=
          math.max(0, 14 - math.min(phoneDigits.indexOf(numOnly), 14));
    }
    if (prin.contains(q)) score += 34;
    if (paidStr.contains(q)) score += 28;
    if (remStr.contains(q)) score += 28;
    return score;
  }

  int _legacyCreditLibreCombinedRelevance(LegacyCreditRow row) =>
      _legacyRowRelevanceAgainstQuery(row, _appliedMainSearchText) +
      _legacyRowRelevanceAgainstQuery(row, _appliedLegacySectionText);

  int _legacySoldesCombinedRelevance(LegacyCreditRow row) =>
      _legacyCreditLibreCombinedRelevance(row) +
      _legacyRowRelevanceAgainstQuery(row, _appliedLegacyHistoryText);

  void _sortLegacyOpenRows(List<LegacyCreditRow> list) {
    final mq = _appliedMainSearchText.trim();
    final sq = _appliedLegacySectionText.trim();
    final hasRel = mq.isNotEmpty || sq.isNotEmpty;
    list.sort((a, b) {
      if (hasRel) {
        final rb = _legacyCreditLibreCombinedRelevance(b);
        final ra = _legacyCreditLibreCombinedRelevance(a);
        if (rb != ra) return rb.compareTo(ra);
      }
      final ob = _legacyOverdueDays(b);
      final oa = _legacyOverdueDays(a);
      if (ob != oa) return ob.compareTo(oa);
      return _legacyRemaining(b).compareTo(_legacyRemaining(a));
    });
  }

  /// Historique soldé (crédit libre + ventes) : pertinence puis date.
  void _sortSettledHistoryRows(List<_SettledHistoryRow> list) {
    final mq = _appliedMainSearchText.trim();
    final sq = _appliedLegacySectionText.trim();
    final hq = _appliedLegacyHistoryText.trim();
    final hasRel = mq.isNotEmpty || sq.isNotEmpty || hq.isNotEmpty;
    int rel(_SettledHistoryRow x) {
      switch (x.kind) {
        case _SettledHistoryKind.creditLibre:
          final l = x.legacy;
          return l != null ? _legacySoldesCombinedRelevance(l) : 0;
        case _SettledHistoryKind.venteNormale:
          final s = x.sale;
          return s != null ? _saleSettledHistoryRelevance(s) : 0;
      }
    }

    String createdAt(_SettledHistoryRow x) {
      switch (x.kind) {
        case _SettledHistoryKind.creditLibre:
          return x.legacy?.createdAt ?? '';
        case _SettledHistoryKind.venteNormale:
          return x.sale?.createdAt ?? '';
      }
    }

    list.sort((a, b) {
      if (hasRel) {
        final rb = rel(b);
        final ra = rel(a);
        if (rb != ra) return rb.compareTo(ra);
      }
      return createdAt(b).compareTo(createdAt(a));
    });
  }

  List<({String id, String label})> _sellers(List<Sale> creditBase) {
    final m = <String, String>{};
    for (final r in creditBase) {
      if (!saleHadCreditBooking(r) && remainingTotal(r) <= creditAmountEps) {
        continue;
      }
      final uid = r.createdBy;
      if (uid.isEmpty) continue;
      m[uid] = r.createdByLabel ?? r.createdBy;
    }
    final list = m.entries.map((e) => (id: e.key, label: e.value)).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  List<_RelanceRow> _computeTopRelance(
    List<Sale> openSales,
    List<LegacyCreditRow> legacyRows,
  ) {
    final map = <String, _RelanceAccum>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final s in openSales) {
      final rem = remainingTotal(s);
      if (rem <= creditAmountEps) continue;
      final key = s.customerId != null
          ? 'sale-${s.customerId}'
          : 'sale-unknown-${s.id}';
      final acc = map.putIfAbsent(key, () => _RelanceAccum());
      acc.customerName = s.customer?.name ?? 'Client non renseigné';
      acc.phone ??= s.customer?.phone;
      acc.totalDue += rem;
      final due = effectiveDueAt(s);
      final dueDay = DateTime(due.year, due.month, due.day);
      final delay = today.difference(dueDay).inDays;
      final delayPos = delay > 0 ? delay : 0;
      if (delayPos > 0) acc.overdueDue += rem;
      if (dueDay == today) acc.dueTodayDue += rem;
      acc.openCount += 1;
      if (delayPos > acc.maxDelayDays) acc.maxDelayDays = delayPos;
    }

    for (final l in legacyRows) {
      final rem = _legacyRemaining(l);
      if (rem <= creditAmountEps) continue;
      final key = 'legacy-${l.customerId}';
      final acc = map.putIfAbsent(key, () => _RelanceAccum());
      acc.customerName = l.customerName ?? 'Client non renseigné';
      acc.phone ??= l.customerPhone;
      acc.totalDue += rem;
      var delayPos = 0;
      if (l.dueAt != null && l.dueAt!.isNotEmpty) {
        final due = DateTime.tryParse(l.dueAt!);
        if (due != null) {
          final dueDay = DateTime(due.year, due.month, due.day);
          final delay = today.difference(dueDay).inDays;
          delayPos = delay > 0 ? delay : 0;
          if (delayPos > 0) acc.overdueDue += rem;
          if (dueDay == today) acc.dueTodayDue += rem;
        }
      }
      acc.openCount += 1;
      if (delayPos > acc.maxDelayDays) acc.maxDelayDays = delayPos;
    }

    final out = map.entries
        .map(
          (e) => _RelanceRow(
            key: e.key,
            customerName: e.value.customerName,
            phone: e.value.phone,
            openCount: e.value.openCount,
            totalDue: e.value.totalDue,
            overdueDue: e.value.overdueDue,
            maxDelayDays: e.value.maxDelayDays,
            dueTodayDue: e.value.dueTodayDue,
          ),
        )
        .toList();
    out.sort((a, b) {
      if (b.overdueDue != a.overdueDue) {
        return b.overdueDue.compareTo(a.overdueDue);
      }
      if (b.maxDelayDays != a.maxDelayDays) {
        return b.maxDelayDays.compareTo(a.maxDelayDays);
      }
      return b.totalDue.compareTo(a.totalDue);
    });
    return out.length > 5 ? out.sublist(0, 5) : out;
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

  Future<void> _exportCreditExcel(List<Sale> filtered) async {
    final excel = xls.Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Crédit'];
    sheet.appendRow([
      xls.TextCellValue('Référence'),
      xls.TextCellValue('Client'),
      xls.TextCellValue('Téléphone'),
      xls.TextCellValue('Date'),
      xls.TextCellValue('Boutique'),
      xls.TextCellValue('Total'),
      xls.TextCellValue('Encaissé'),
      xls.TextCellValue('Reste'),
      xls.TextCellValue('Échéance'),
      xls.TextCellValue('Statut'),
      xls.TextCellValue('Retard (jours)'),
      xls.TextCellValue('Vendeur'),
    ]);
    for (final s in filtered) {
      sheet.appendRow([
        xls.TextCellValue(s.saleNumber),
        xls.TextCellValue(s.customer?.name ?? ''),
        xls.TextCellValue(s.customer?.phone ?? ''),
        xls.TextCellValue(_ymdFromCreated(s.createdAt)),
        xls.TextCellValue(s.store?.name ?? ''),
        xls.DoubleCellValue(s.total),
        xls.DoubleCellValue(paidRealized(s)),
        xls.DoubleCellValue(remainingTotal(s)),
        xls.TextCellValue(DateFormat('yyyy-MM-dd').format(effectiveDueAt(s))),
        xls.TextCellValue(creditStatusLabel(creditLineStatus(s))),
        xls.IntCellValue(daysOverdue(s)),
        xls.TextCellValue(s.createdByLabel ?? ''),
      ]);
    }
    final encoded = excel.encode();
    if (encoded == null) return;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ok = await saveBytesFile(
      dialogTitle: 'Enregistrer le fichier Excel',
      filename: 'credit-ventes-$date.xlsx',
      bytes: Uint8List.fromList(encoded),
      allowedExtensions: const ['xlsx'],
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier Excel enregistré')),
      );
    }
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

    final payload = await showDialog<CreditPaymentReceiptPayload>(
      context: context,
      builder: (ctx) =>
          CreditPayDialog(sale: sale, credit: facade, onSuccess: refreshList),
    );
    if (payload != null && mounted) {
      refreshList();
      final data = _buildSaleReceiptData(payload);
      await _showCreditRepaymentReceiptActions(data);
    }
  }

  Future<void> _openDispatchDetailRt(
    String invoiceId, {
    required String companyId,
    required bool canPay,
    WarehouseDispatchInvoiceSummary? summary,
  }) async {
    if (!ConnectivityService.instance.isOnline) {
      AppToast.info(
        context,
        'Détail du bon disponible après reconnexion internet.',
      );
      return;
    }
    final theme = Theme.of(context);
    Future<WarehouseDispatchInvoiceDetails> detailFuture = _warehouseRepo
        .getDispatchInvoiceDetails(invoiceId);
    Timer? autoRefresh;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          autoRefresh ??= Timer.periodic(const Duration(seconds: 10), (_) {
            if (!ConnectivityService.instance.isOnline) return;
            detailFuture = _warehouseRepo.getDispatchInvoiceDetails(invoiceId);
            if (ctx.mounted) setLocal(() {});
          });
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Bon de sortie')),
                IconButton(
                  tooltip: 'Actualiser',
                  onPressed: () {
                    detailFuture = _warehouseRepo.getDispatchInvoiceDetails(
                      invoiceId,
                    );
                    setLocal(() {});
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            content: FutureBuilder<WarehouseDispatchInvoiceDetails>(
              future: detailFuture,
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
                final sub = d.subtotal;
                final paid = _dispatchPaidAmountFromNotes(d.notes, sub);
                final rem = (sub - paid).clamp(0.0, double.infinity);
                final noteHuman = _humanDispatchNote(d.notes, sub);
                final online = ConnectivityService.instance.isOnline;
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
                          formatOperationDateTime(d.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: online
                                ? Colors.green.withValues(alpha: 0.10)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            online
                                ? 'Temps réel actif (auto-refresh)'
                                : 'Hors ligne: dernière donnée locale',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: online
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Client : ${d.customerName ?? '—'}'
                          '${d.customerPhone != null && d.customerPhone!.isNotEmpty ? ' · ${d.customerPhone}' : ''}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (noteHuman != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            noteHuman,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
                        if (canPay && rem > creditAmountEps) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () {
                                autoRefresh?.cancel();
                                Navigator.of(ctx).pop();
                                final row = summary ??
                                    WarehouseDispatchInvoiceSummary(
                                      id: d.id,
                                      companyId: d.companyId,
                                      documentNumber: d.documentNumber,
                                      createdAt: d.createdAt,
                                      customerId: d.customerId,
                                      customerName: d.customerName,
                                      notes: d.notes,
                                      createdBy: null,
                                    );
                                _openDispatchPay(
                                  companyId: companyId,
                                  row: row,
                                  total: sub,
                                  alreadyPaid: paid,
                                );
                              },
                              child: const Text('Encaisser'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  autoRefresh?.cancel();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
    autoRefresh?.cancel();
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
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          labelText: 'Montant reçu (F CFA)',
                          hintText: 'Reste ${remaining.round()}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final t = double.tryParse(
                                amountCtrl.text.trim().replaceAll(',', '.'),
                              ) ??
                              0;
                          if (t <= creditAmountEps) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Saisissez le montant reçu en espèces.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            );
                          }
                          final app = t > remaining ? remaining : t;
                          final ch = math.max(0.0, t - app);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Imputé au bon : ${formatCurrency(app)}'
                              '${ch > creditAmountEps ? ' · Monnaie à rendre : ${formatCurrency(ch)}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Cette méthode solde le bon en totalité.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                        double? rpcAmount;
                        var tenderedCash = 0.0;
                        if (method == 'cash') {
                          final parsed = double.tryParse(
                            amountCtrl.text.trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= creditAmountEps) {
                            return;
                          }
                          tenderedCash = parsed;
                          rpcAmount = tenderedCash;
                        } else {
                          rpcAmount = null;
                        }
                        setLocal(() => submitting = true);
                        try {
                          if (ConnectivityService.instance.isOnline) {
                            await _warehouseRepo.appendDispatchPayment(
                              companyId: companyId,
                              invoiceId: row.id,
                              method: method,
                              amount: rpcAmount,
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
                                    'amount': rpcAmount,
                                    'mobile_provider': method == 'mobile_money'
                                        ? mobileProvider
                                        : null,
                                  }),
                                );
                          }
                          if (!mounted) return;
                          final applied = method == 'cash'
                              ? math.min(tenderedCash, remaining)
                              : remaining;
                          final changeDue = method == 'cash'
                              ? math.max(0.0, tenderedCash - applied)
                              : 0.0;
                          await _refreshData();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            if (ConnectivityService.instance.isOnline) {
                              if (method == 'cash' &&
                                  changeDue > creditAmountEps) {
                                AppToast.success(
                                  context,
                                  'Paiement enregistré. Monnaie à rendre : '
                                  '${formatCurrency(changeDue)}.',
                                );
                              } else {
                                AppToast.success(
                                  context,
                                  'Paiement enregistré.',
                                );
                              }
                            } else {
                              AppToast.success(
                                context,
                                'Paiement enregistré hors ligne. '
                                'Synchronisation à la reconnexion.',
                              );
                            }
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
    var payMode = 'cash';
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final theme = Theme.of(ctx);
          final rem = _legacyRemaining(row);
          final tendered =
              double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ??
                  0.0;
          final isCash = payMode == 'cash';
          final applied = isCash
              ? math.min(tendered, rem)
              : tendered.clamp(0.0, rem + creditAmountEps);
          final changeDue =
              isCash ? math.max(0.0, tendered - applied) : 0.0;
          final nonCashOver =
              !isCash && tendered > rem + creditAmountEps && tendered > 0;

          return AlertDialog(
            title: const Text('Encaisser crédit libre'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${row.customerName ?? 'Client'} — reste ${formatCurrency(rem)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(payMode),
                    initialValue: payMode,
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                      DropdownMenuItem(
                        value: 'orange_money',
                        child: Text('Orange money'),
                      ),
                      DropdownMenuItem(
                        value: 'moov_money',
                        child: Text('Moov money'),
                      ),
                      DropdownMenuItem(value: 'wave', child: Text('Wave')),
                      DropdownMenuItem(value: 'card', child: Text('Carte')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Virement'),
                      ),
                    ],
                    onChanged: _legacyBusy
                        ? null
                        : (v) => setLocal(() => payMode = v ?? 'cash'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    enabled: !_legacyBusy,
                    onChanged: (_) => setLocal(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: isCash
                          ? 'Montant reçu (espèces)'
                          : 'Montant encaissé',
                      hintText: rem > 0 ? formatCurrency(rem) : '0',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (isCash && tendered > creditAmountEps) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Imputé au solde : ${formatCurrency(applied)}'
                      '${changeDue > creditAmountEps ? ' · Monnaie à rendre : ${formatCurrency(changeDue)}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (nonCashOver)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Le montant ne peut pas dépasser le reste (${formatCurrency(rem)}).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refCtrl,
                    enabled: !_legacyBusy,
                    decoration: const InputDecoration(
                      labelText: 'Note / référence',
                      hintText: 'Reçu, n° transaction…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
                        final t =
                            double.tryParse(
                              amountCtrl.text.trim().replaceAll(',', '.'),
                            ) ??
                            0;
                        if (t <= creditAmountEps) return;
                        final remNow = _legacyRemaining(row);
                        final cash = payMode == 'cash';
                        final appl = cash ? math.min(t, remNow) : t;
                        if (!cash && t > remNow + creditAmountEps) return;
                        if (appl <= creditAmountEps || remNow <= creditAmountEps) {
                          return;
                        }
                        final note = refCtrl.text.trim();
                        String? ml;
                        if (payMode == 'orange_money') {
                          ml = 'Orange money';
                        } else if (payMode == 'moov_money') {
                          ml = 'Moov money';
                        } else if (payMode == 'wave') {
                          ml = 'Wave';
                        }
                        final refValue = ml != null
                            ? [ml, note]
                                .where((s) => s.trim().isNotEmpty)
                                .join(' — ')
                            : (note.isEmpty ? null : note);
                        final change = cash
                            ? math.max(0.0, t - appl)
                            : 0.0;
                        late final String bm;
                        if (payMode == 'orange_money' ||
                            payMode == 'moov_money' ||
                            payMode == 'wave') {
                          bm = 'mobile_money';
                        } else if (payMode == 'card') {
                          bm = 'card';
                        } else if (payMode == 'transfer') {
                          bm = 'transfer';
                        } else {
                          bm = 'cash';
                        }
                        setState(() => _legacyBusy = true);
                        try {
                          AppendPaymentResult? serverPay;
                          LegacyCreditPayment? pendingLocal;
                          if (ConnectivityService.instance.isOnline) {
                            serverPay = await _legacyRepo.appendPayment(
                              creditId: row.id,
                              method: bm,
                              amount: appl,
                              reference: (refValue == null || refValue.isEmpty)
                                  ? null
                                  : refValue,
                            );
                          } else {
                            await ref
                                .read(appDatabaseProvider)
                                .enqueuePendingAction(
                                  'legacy_credit_append_payment',
                              jsonEncode({
                                'credit_id': row.id,
                                'method': bm,
                                'amount': appl,
                                'reference': refValue,
                              }),
                            );
                            final createdAt = DateTime.now()
                                .toUtc()
                                .toIso8601String();
                            final payment = LegacyCreditPayment(
                              id:
                                  'pending_pay_${DateTime.now().millisecondsSinceEpoch}',
                              method: bm,
                              amount: appl,
                              reference: refValue,
                              createdAt: createdAt,
                            );
                            pendingLocal = payment;
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
                          if (mounted) {
                            final issuedAt = serverPay?.createdAt ??
                                (pendingLocal != null
                                    ? (DateTime.tryParse(pendingLocal.createdAt)
                                            ?.toUtc() ??
                                        DateTime.now().toUtc())
                                    : DateTime.now().toUtc());
                            final payId =
                                serverPay?.paymentId ?? pendingLocal?.id;
                            _receiptData = _buildLegacyReceiptData(
                              row: row,
                              method: bm,
                              amountPaid: appl,
                              reference: refValue,
                              issuedAt: issuedAt,
                              previousBalance: remNow,
                              paymentId: payId,
                              amountTendered: cash ? t : null,
                              changeDue:
                                  cash && change > creditAmountEps ? change : null,
                            );
                            if (ConnectivityService.instance.isOnline) {
                              if (cash && change > creditAmountEps) {
                                AppToast.success(
                                  context,
                                  'Paiement enregistré. Monnaie à rendre : '
                                  '${formatCurrency(change)}.',
                                );
                              } else {
                                AppToast.success(
                                  context,
                                  'Paiement enregistré.',
                                );
                              }
                            } else {
                              AppToast.success(
                                context,
                                'Encaissement enregistré hors ligne. '
                                'Synchronisation à la reconnexion.',
                              );
                            }
                            if (_receiptData != null) {
                              await _showCreditRepaymentReceiptActions(
                                _receiptData!,
                              );
                              _receiptData = null;
                            }
                          }
                        } finally {
                          if (mounted) setState(() => _legacyBusy = false);
                        }
                      },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _legacyPaymentMethodLabel(String method) {
    switch (method.trim().toLowerCase()) {
      case 'cash':
        return 'Espèces';
      case 'mobile_money':
        return 'Mobile money';
      case 'card':
        return 'Carte';
      case 'transfer':
        return 'Virement';
      default:
        return method;
    }
  }

  _CreditRepaymentReceiptData _buildLegacyReceiptData({
    required LegacyCreditRow row,
    required String method,
    required double amountPaid,
    required String? reference,
    required DateTime issuedAt,
    required double previousBalance,
    String? paymentId,
    double? amountTendered,
    double? changeDue,
  }) {
    final company = context.read<CompanyProvider>();
    final store = company.stores.where((s) => s.id == row.storeId).toList();
    final storeInfo = store.isNotEmpty ? store.first : null;
    final newBalance =
        (previousBalance - amountPaid).clamp(0.0, double.infinity).toDouble();
    final pid = paymentId?.trim();
    return _CreditRepaymentReceiptData(
      receiptNumber: pid != null && pid.isNotEmpty
          ? creditRepaymentReceiptNumberFromPaymentId(pid, issuedAt)
          : creditRepaymentReceiptNumberFallback(issuedAt),
      issuedAt: issuedAt,
      companyName: company.currentCompany?.name ?? 'FasoStock',
      storeId: row.storeId,
      store: storeInfo,
      storeName: storeInfo?.name ?? row.storeName ?? 'Boutique',
      storeAddress: storeInfo?.address,
      storePhone: storeInfo?.phone,
      storeLogoUrl: storeInfo?.logoUrl,
      customerName: row.customerName ?? 'Client',
      customerPhone: row.customerPhone,
      creditTitle: row.title,
      paymentMethodLabel: _legacyPaymentMethodLabel(method),
      paymentReference: reference,
      amountPaid: amountPaid,
      amountTendered: amountTendered,
      changeDue: changeDue,
      previousBalance: previousBalance,
      newBalance: newBalance,
      settled: newBalance <= creditAmountEps,
      note: _legacyVendor(row.internalNote),
      embeddedStorePrimaryHex: null,
    );
  }

  _CreditRepaymentReceiptData _buildSaleReceiptData(
    CreditPaymentReceiptPayload p,
  ) {
    final company = context.read<CompanyProvider>();
    final store = company.stores.where((s) => s.id == p.storeId).toList();
    final storeInfo = store.isNotEmpty ? store.first : null;
    return _CreditRepaymentReceiptData(
      receiptNumber: creditRepaymentReceiptNumberFromPaymentId(
        p.paymentId,
        p.issuedAt,
      ),
      issuedAt: p.issuedAt,
      companyName: company.currentCompany?.name ?? 'FasoStock',
      storeId: p.storeId,
      store: storeInfo,
      storeName: p.storeName,
      storeAddress: storeInfo?.address,
      storePhone: storeInfo?.phone,
      storeLogoUrl: storeInfo?.logoUrl,
      customerName: p.customerName,
      customerPhone: p.customerPhone,
      creditTitle: p.creditTitle,
      paymentMethodLabel: p.paymentMethodLabel,
      paymentReference: p.paymentReference,
      amountPaid: p.amountPaid,
      amountTendered: p.amountTendered,
      changeDue: p.changeDue,
      previousBalance: p.previousBalance,
      newBalance: p.newBalance,
      settled: p.settled,
      note: p.saleNumber,
      embeddedStorePrimaryHex: p.storePrimaryColor,
    );
  }

  Future<String?> _resolveReceiptPrimaryHexWithFetch(
    _CreditRepaymentReceiptData data,
  ) async {
    if (!mounted) return null;
    final sid = data.storeId?.trim();

    // Source de vérité en ligne : évite liste CompanyProvider périmère et boutons encore au primary du thème (orange).
    if (sid != null &&
        sid.isNotEmpty &&
        ConnectivityService.instance.isOnline) {
      try {
        final remote = await StoresRepository().getStore(sid);
        final h = remote?.primaryColor?.trim();
        if (h != null && h.isNotEmpty) return h;
      } catch (_) {}
    }

    if (!mounted) return null;

    final mem = _resolvedCreditReceiptPrimaryHex(
      fromEmbeddedSale: data.embeddedStorePrimaryHex,
      receiptStore: data.store,
      currentStore: context.read<CompanyProvider>().currentStore,
    );
    if (mem != null && mem.trim().isNotEmpty) return mem.trim();

    if (sid == null || sid.isEmpty) return null;

    if (!mounted) return null;
    try {
      final db = ref.read(appDatabaseProvider);
      final rows = await (db.select(db.localStores)..where((t) => t.id.equals(sid)))
          .get();
      if (rows.isEmpty) return null;
      final h = rows.first.primaryColor?.trim();
      if (h != null && h.isNotEmpty) return h;
    } catch (_) {}

    return null;
  }

  Future<Uint8List?> _tryLoadLogoBytes(String? storeId, String? url) async {
    Uint8List? cachedBytes;
    final sid = storeId?.trim();
    if (sid != null && sid.isNotEmpty) {
      cachedBytes = await InvoiceA4PdfService.loadCachedLogoBytes(sid);
      if (!ConnectivityService.instance.isOnline &&
          cachedBytes != null &&
          cachedBytes.isNotEmpty) {
        return cachedBytes;
      }
    }
    final u = url?.trim();
    if (u == null || u.isEmpty) return cachedBytes;
    try {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          res.bodyBytes.isNotEmpty) {
        // Sanitise l'image pour le moteur PDF (évite artefacts avec certains formats/logo).
        final decoded = img.decodeImage(res.bodyBytes);
        if (decoded != null) {
          final baked = img.bakeOrientation(decoded);
          final resized = (baked.width > 512 || baked.height > 512)
              ? img.copyResize(
                  baked,
                  width: baked.width >= baked.height ? 512 : null,
                  height: baked.height > baked.width ? 512 : null,
                  interpolation: img.Interpolation.average,
                )
              : baked;
          final flattened = img.Image(
            width: resized.width,
            height: resized.height,
          );
          img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
          img.compositeImage(flattened, resized);
          final safeBytes = Uint8List.fromList(img.encodePng(flattened));
          if (sid != null && sid.isNotEmpty && safeBytes.isNotEmpty) {
            await InvoiceA4PdfService.cacheLogoBytes(sid, safeBytes);
          }
          return safeBytes;
        }
        if (sid != null && sid.isNotEmpty) {
          await InvoiceA4PdfService.cacheLogoBytes(sid, res.bodyBytes);
        }
        return res.bodyBytes;
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: {'phase': 'load_receipt_logo', 'url': u},
      );
    }
    return cachedBytes;
  }

  Future<Uint8List?> _buildQrPngBytes(String value) async {
    try {
      final painter = QrPainter(
        data: value,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
      );
      final data = await painter.toImageData(
        256,
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List();
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_page',
        logContext: const {'phase': 'build_receipt_qr_png'},
      );
      return null;
    }
  }

  Future<Uint8List> _buildCreditRepaymentReceiptPdf(
    _CreditRepaymentReceiptData data, {
    String? preResolvedPrimaryHex,
  }) async {
    final doc = pw.Document();
    final issued = formatOperationDateTime(data.issuedAt);
    final receiptNo = data.receiptNumber.trim().isEmpty ? '—' : data.receiptNumber.trim();
    final store = data.store;
    var primaryHex = preResolvedPrimaryHex?.trim();
    if (primaryHex == null || primaryHex.isEmpty) {
      primaryHex = await _resolveReceiptPrimaryHexWithFetch(data);
    }
    final logoBytes = await _tryLoadLogoBytes(data.storeId, data.storeLogoUrl);
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final qrBytes = await _buildQrPngBytes(
      '${data.receiptNumber}|${data.amountPaid.round()}|${data.customerName}',
    );
    final qrImage = qrBytes != null ? pw.MemoryImage(qrBytes) : null;

    // Harmonisation facture A4 : couleurs pilotées par la boutique concernée (#RRGGBB, #ARGB, #RGB).
    String sanitizeForPdf(String s) {
      if (s.isEmpty) return s;
      return s
          .replaceAll('\uFFFD', '')
          .replaceAll('\u00A0', ' ')
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
          .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
          .replaceAll('\u2014', '-')
          .replaceAll('\u2013', '-');
    }

    final primary = _creditReceiptAccentPdf(primaryHex);
    // formatCurrency ajoute déjà le symbole « FCFA » — ne pas concaténer la devise ISO sinon « … FCFA XOF ».

    pw.Widget kvRow(
      String label,
      String value, {
      bool strong = false,
      double size = 10,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              sanitizeForPdf(label),
              style: pw.TextStyle(
                fontSize: size,
                color: PdfColors.black,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              sanitizeForPdf(value),
              style: pw.TextStyle(
                fontSize: size,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) {
          final boutiqueHeadline = (data.storeName.trim().isEmpty
                  ? 'Boutique'
                  : data.storeName.trim())
              .toUpperCase();
          final storePhone = (store?.phone ?? data.storePhone)?.trim();
          final storeAddress = (store?.address ?? data.storeAddress)?.trim();
          final storeMm = store?.mobileMoney?.trim();
          final enterpriseLine = data.companyName.trim().isEmpty
              ? 'Entreprise'
              : data.companyName.trim();
          final footerText = (store?.footerText ?? '').trim();
          final footerLine = footerText.isNotEmpty
              ? footerText
              : 'Merci pour votre confiance.';

          pw.Widget topHeaderBar() => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: primary, width: 2),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        sanitizeForPdf(enterpriseLine),
                        style: pw.TextStyle(
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                    pw.Text(
                      sanitizeForPdf('Reçu $receiptNo - $issued'),
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              );

          pw.Widget bottomFooterBar() => pw.Container(
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.black)),
                ),
                child: pw.Text(
                  sanitizeForPdf(footerLine),
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              );

          pw.Widget labelPill(String text) => pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  sanitizeForPdf(text),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              );

          pw.Widget borderedBlock(pw.Widget child) => pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.black, width: 0.6),
                ),
                child: child,
              );

          pw.Widget titleLine(String text) => pw.Text(
                sanitizeForPdf(text),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              );

          pw.Widget infoLine(String text) => pw.Text(
                sanitizeForPdf(text),
                style: const pw.TextStyle(fontSize: 10),
              );

          pw.Widget signatureBlock() {
            final title = store?.invoiceSignerTitle?.trim();
            final name = store?.invoiceSignerName?.trim();
            final has = (title != null && title.isNotEmpty) ||
                (name != null && name.isNotEmpty);
            if (!has) return pw.SizedBox(height: 24);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(top: 40),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (title != null && title.isNotEmpty)
                      pw.Text(
                        sanitizeForPdf(title).toUpperCase(),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    if (name != null && name.isNotEmpty) ...[
                      if (title != null && title.isNotEmpty)
                        pw.SizedBox(height: 4),
                      pw.Text(
                        sanitizeForPdf(name).toUpperCase(),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final paymentRef = data.paymentReference?.trim();
          final hasPaymentRef = paymentRef != null && paymentRef.isNotEmpty;

          final settledLabel = data.settled ? 'CRÉDIT SOLDÉ' : 'CRÉDIT EN COURS';
          final statusLine = data.settled
              ? 'Statut : soldé'
              : 'Statut : solde restant ${formatCurrency(data.newBalance)}';

          final bodyColumn = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
            topHeaderBar(),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.black, width: 0.6),
                    ),
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                if (logoImage != null) pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        sanitizeForPdf(boutiqueHeadline),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      if (storeAddress != null && storeAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: infoLine(storeAddress),
                        ),
                      if (storePhone != null && storePhone.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: infoLine('Tél : $storePhone'),
                        ),
                      if (storeMm != null && storeMm.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: infoLine('Mobile money : $storeMm'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                titleLine('Reçu de remboursement crédit'),
                labelPill(settledLabel),
              ],
            ),
            pw.SizedBox(height: 8),
            borderedBlock(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  kvRow('N° reçu', receiptNo, strong: true),
                  kvRow('Date', issued),
                  kvRow('Crédit concerné', data.creditTitle, strong: true),
                  if (data.note != null && data.note!.trim().isNotEmpty)
                    kvRow('Référence vente', data.note!.trim()),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: borderedBlock(
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CLIENT',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        kvRow('Nom', data.customerName, strong: true),
                        if (data.customerPhone != null &&
                            data.customerPhone!.trim().isNotEmpty)
                          kvRow('Tél', data.customerPhone!.trim()),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: borderedBlock(
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PAIEMENT',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        kvRow('Mode', data.paymentMethodLabel, strong: true),
                        if (hasPaymentRef) kvRow('Référence', paymentRef),
                        if (data.amountTendered != null &&
                            data.amountTendered! > creditAmountEps)
                          kvRow(
                            'Montant reçu',
                            formatCurrency(data.amountTendered!),
                          ),
                        if (data.changeDue != null &&
                            data.changeDue! > creditAmountEps)
                          kvRow(
                            'Monnaie à rendre',
                            formatCurrency(data.changeDue!),
                            strong: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            borderedBlock(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  kvRow(
                    'Solde avant paiement',
                    formatCurrency(data.previousBalance),
                    strong: true,
                  ),
                  kvRow(
                    'Montant remboursé (imputé)',
                    formatCurrency(data.amountPaid),
                    strong: true,
                  ),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 6),
                    height: 1,
                    color: PdfColors.black,
                  ),
                  kvRow(
                    'Nouveau solde dû',
                    formatCurrency(data.newBalance),
                    strong: true,
                    size: 12,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    sanitizeForPdf(statusLine),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            if (qrImage != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF4F4F5),
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFFE4E4E7),
                    width: 0.6,
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 88,
                      height: 88,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(
                          color: const PdfColor.fromInt(0xFF71717A),
                          width: 0.6,
                        ),
                      ),
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Image(qrImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Traçabilité',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          infoLine('N° reçu : ${data.receiptNumber}'),
                          infoLine(
                            'Paiement : ${formatCurrency(data.amountPaid)}',
                          ),
                          infoLine(
                            'Solde après : ${formatCurrency(data.newBalance)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            signatureBlock(),
            ],
          );
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: bodyColumn),
              bottomFooterBar(),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  void _showCreditRepaymentPdfPreview(
    _CreditRepaymentReceiptData data, {
    required String? preResolvedPrimaryHex,
  }) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Reçu de remboursement'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) => _buildCreditRepaymentReceiptPdf(
                data,
                preResolvedPrimaryHex: preResolvedPrimaryHex,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreditRepaymentReceiptActions(
    _CreditRepaymentReceiptData data,
  ) async {
    final accentHexResolved = await _resolveReceiptPrimaryHexWithFetch(data);
    if (!mounted) return;
    String? busy;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final disabled = busy != null;
          // Toujours l’orange FasoStock du thème — pas la couleur boutique (sinon bleu, etc.).
          final actionColor = Theme.of(ctx).colorScheme.primary;
          Widget actionBtn({
            required String keyBusy,
            required IconData icon,
            required String label,
            required Future<void> Function() onRun,
          }) {
            final loading = busy == keyBusy;
            return Expanded(
              child: FilledButton.icon(
                onPressed: disabled
                    ? null
                    : () async {
                        setLocal(() => busy = keyBusy);
                        try {
                          await onRun();
                        } finally {
                          if (ctx.mounted) setLocal(() => busy = null);
                        }
                      },
                style: ButtonStyle(
                  elevation: const WidgetStatePropertyAll(0),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  minimumSize:
                      WidgetStateProperty.all(const Size(0, 48)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return actionColor.withValues(alpha: 0.38);
                    }
                    return actionColor;
                  }),
                  foregroundColor:
                      const WidgetStatePropertyAll(Colors.white),
                  iconColor: const WidgetStatePropertyAll(Colors.white),
                ),
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, size: 18),
                label: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Reçu de remboursement',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paiement crédit enregistré. Générez un reçu professionnel pour le client.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          children: [
                            actionBtn(
                              keyBusy: 'view',
                              icon: Icons.picture_as_pdf,
                              label: 'Aperçu PDF',
                              onRun: () async {
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                _showCreditRepaymentPdfPreview(
                                  data,
                                  preResolvedPrimaryHex: accentHexResolved,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            actionBtn(
                              keyBusy: 'print',
                              icon: Icons.print,
                              label: 'Imprimer',
                              onRun: () async {
                                if (!mounted) return;
                                AppToast.info(context, 'Impression du reçu en cours…');
                                await Printing.layoutPdf(
                                  onLayout: (_) => _buildCreditRepaymentReceiptPdf(
                                    data,
                                    preResolvedPrimaryHex: accentHexResolved,
                                  ),
                                  name: data.receiptNumber,
                                );
                                if (mounted) {
                                  AppToast.success(context, 'Reçu envoyé à l\'imprimante.');
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            actionBtn(
                              keyBusy: 'download',
                              icon: Icons.download,
                              label: 'Enregistrer',
                              onRun: () async {
                                final bytes = await _buildCreditRepaymentReceiptPdf(
                                  data,
                                  preResolvedPrimaryHex: accentHexResolved,
                                );
                                final safe = data.receiptNumber.replaceAll(
                                  RegExp(r'[^\w.\-]'),
                                  '_',
                                );
                                final ok = await saveBytesFile(
                                  dialogTitle: 'Enregistrer le reçu PDF',
                                  filename:
                                      'recu_remboursement_credit_$safe.pdf',
                                  bytes: bytes,
                                  allowedExtensions: const ['pdf'],
                                );
                                if (ok && mounted) {
                                  AppToast.success(context, 'Reçu téléchargé.');
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: actionColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Fermer',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLegacyHistory(LegacyCreditRow row) async {
    final ordered = [...row.payments]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final principal = row.principalAmount;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Historique des paiements',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Builder(
          builder: (ctx) {
            final maxDialogW = (MediaQuery.sizeOf(ctx).width - 32)
                .clamp(280.0, 520.0);
            return SizedBox(
              width: maxDialogW,
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
                    final paidBefore = ordered
                        .take(i)
                        .fold<double>(0, (s, x) => s + x.amount);
                    final previousBalance =
                        (principal - paidBefore).clamp(0.0, double.infinity);
                    final methodLabel = switch (p.method.trim().toLowerCase()) {
                      'cash' => 'Espèces',
                      'mobile_money' => 'Mobile money',
                      'card' => 'Carte',
                      'transfer' => 'Virement',
                      _ => p.method,
                    };
                    final stamp = formatOperationDateTime(p.createdAt);
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  formatCurrency(p.amount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final data = _buildLegacyReceiptData(
                                    row: row,
                                    method: p.method,
                                    amountPaid: p.amount,
                                    reference: p.reference,
                                    issuedAt:
                                        DateTime.tryParse(p.createdAt)
                                            ?.toUtc() ??
                                        DateTime.now().toUtc(),
                                    previousBalance: previousBalance,
                                    paymentId: p.id,
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.of(ctx).pop();
                                  await _showCreditRepaymentReceiptActions(
                                    data,
                                  );
                                },
                                child: const Text('Reçu'),
                              ),
                            ],
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
                                  style: theme.textTheme.labelSmall?.copyWith(
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
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stamp,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    );
                  },
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
    _legacyFuture ??= _legacyRepo
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
              'phase': 'initial_legacy_load',
              'company_id': companyId,
              'store_id': _storeFilter.isEmpty ? null : _storeFilter,
            },
          );
          if (mounted) {
            setState(() {
              _legacyLoadWarning = ConnectivityService.instance.isOnline
                  ? 'Impossible de charger le crédit libre pour le moment.'
                  : 'Mode hors ligne: affichage du dernier état local du crédit libre.';
            });
          }
          return _legacyCache;
        });
    final creditAsync = ref.watch(
      creditSalesFilteredStreamProvider(_creditStreamKey(companyId)),
    );
    final dispatchAsync = ref.watch(
      warehouseDispatchInvoicesStreamProvider(companyId),
    );
    final creditRows = creditAsync.valueOrNull ?? const <Sale>[];
    final dispatchRowsAll =
        dispatchAsync.valueOrNull ?? const <WarehouseDispatchInvoiceSummary>[];
    final dispatchRows =
        _dispatchInvoicesInPeriod(dispatchRowsAll, _fromYmd, _toYmd);
    final members =
        ref.watch(companyMembersStreamProvider(companyId)).valueOrNull ??
        const [];
    final memberNameByUserId = <String, String>{};
    for (final m in members) {
      final name = m.profile?.fullName?.trim();
      if (name != null && name.isNotEmpty) {
        memberNameByUserId[m.userId] = name;
      } else {
        final mail = m.email?.trim();
        memberNameByUserId[m.userId] =
            mail != null && mail.isNotEmpty ? mail : m.userId;
      }
    }
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

    const legacyEps = 0.005;
    final nowKpi = DateTime.now();
    for (final l in _legacyCache) {
      final paidL = _legacyPaid(l);
      totalPaidAll += paidL;
      final remL = _legacyRemaining(l);
      if (remL <= legacyEps) continue;
      totalRem += remL;
      totalSaleTotal += l.principalAmount;
      debtors.add(l.customerId);
      if (l.dueAt != null && l.dueAt!.isNotEmpty) {
        final due = DateTime.tryParse(l.dueAt!);
        if (due != null) {
          final dueDay = DateTime(due.year, due.month, due.day);
          final today = DateTime(nowKpi.year, nowKpi.month, nowKpi.day);
          if (today.isAfter(dueDay)) {
            overdue += remL;
          } else if (today == dueDay) {
            dueToday += remL;
          } else {
            final monday = today.subtract(
              Duration(days: today.weekday - DateTime.monday),
            );
            final monday0 = DateTime(monday.year, monday.month, monday.day);
            final sunday0 = monday0.add(const Duration(days: 6));
            final dd = DateTime(dueDay.year, dueDay.month, dueDay.day);
            if (!dd.isBefore(monday0) && !dd.isAfter(sunday0)) {
              dueWeek += remL;
            }
          }
        }
      }
    }

    final portfolioTotal = totalRem + totalPaidAll;
    final recoveryRate = portfolioTotal > creditAmountEps
        ? (totalPaidAll / portfolioTotal) * 100
        : 100.0;
    final avgOpenTicket = open.isEmpty ? 0.0 : totalRem / open.length;

    var cancelledCreditCount = 0;
    var cancelledCreditAmount = 0.0;
    for (final s in creditRows) {
      if (s.status == SaleStatus.cancelled || s.status == SaleStatus.refunded) {
        cancelledCreditCount += 1;
        cancelledCreditAmount +=
            (s.total - paidRealized(s)).clamp(0.0, double.infinity);
      }
    }

    final topRelanceRows = _computeTopRelance(open, _legacyCache);

    final filtered = _filteredSales(creditRows);
    final qDispatch = _appliedMainSearchText.trim().toLowerCase();
    double dispatchRemaining(WarehouseDispatchInvoiceSummary d) {
      final total = _dispatchTotalsByInvoiceId[d.id];
      if (total == null) return double.nan;
      final paid = _dispatchPaidAmountFromNotes(d.notes, total);
      return (total - paid).clamp(0, double.infinity);
    }

    final filteredDispatchCredits = dispatchRows.where((d) {
      final total = _dispatchTotalsByInvoiceId[d.id];
      if (total == null) {
        if (_chip == _QuickChip.soldes) return false;
        return true;
      }
      final info = _parseDispatchPaymentInfo(d.notes, total);
      final paid = info.paidAmount.clamp(0, total);
      final remaining = (total - paid).clamp(0, double.infinity);

      if (_chip == _QuickChip.soldes) {
        if (remaining > creditAmountEps || info.mode != 'credit') return false;
      } else {
        if (remaining <= creditAmountEps) return false;
      }

      if (_sellerId.isNotEmpty && (d.createdBy ?? '') != _sellerId) {
        return false;
      }

      if (_chip != _QuickChip.soldes) {
        final hasBalance = remaining > creditAmountEps;
        final hasEncaisse = paid > creditAmountEps;
        switch (_chip) {
          case _QuickChip.all:
            break;
          case _QuickChip.nonPaye:
            if (!(hasBalance && !hasEncaisse)) return false;
            break;
          case _QuickChip.partiel:
            if (!(hasBalance && hasEncaisse)) return false;
            break;
          case _QuickChip.enRetard:
          case _QuickChip.dueToday:
          case _QuickChip.dueWeek:
          case _QuickChip.soldes:
            return false;
        }
      }

      if (qDispatch.isEmpty) return true;
      final doc = d.documentNumber.toLowerCase();
      final customer = (d.customerName ?? '').toLowerCase();
      final created = d.createdAt.toLowerCase();
      return doc.contains(qDispatch) ||
          customer.contains(qDispatch) ||
          created.contains(qDispatch) ||
          '$total'.contains(qDispatch) ||
          'bon depot'.contains(qDispatch) ||
          'depot'.contains(qDispatch);
    }).toList()
      ..sort((a, b) {
        if (qDispatch.isNotEmpty) {
          final ta = _dispatchTotalsByInvoiceId[a.id];
          final tb = _dispatchTotalsByInvoiceId[b.id];
          final sa = _dispatchSearchRelevance(a, qDispatch, ta);
          final sb = _dispatchSearchRelevance(b, qDispatch, tb);
          if (sb != sa) return sb.compareTo(sa);
        }
        final ra = dispatchRemaining(a);
        final rb = dispatchRemaining(b);
        final va = ra.isNaN ? 0.0 : ra;
        final vb = rb.isNaN ? 0.0 : rb;
        return vb.compareTo(va);
      });
    var customerRows = buildCustomerAggregates(filtered);
    final customerSearchQ = _appliedMainSearchText.trim().toLowerCase();
    if (customerSearchQ.isNotEmpty) {
      final numOnlyCust = customerSearchQ.replaceAll(RegExp(r'\s'), '');
      customerRows = [...customerRows]..sort((a, b) {
          final sab = _customerAggSearchRelevance(b, customerSearchQ, numOnlyCust);
          final saa = _customerAggSearchRelevance(a, customerSearchQ, numOnlyCust);
          if (sab != saa) return sab.compareTo(saa);
          return b.totalDue.compareTo(a.totalDue);
        });
    }
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
        (_appliedMainSearchText.trim().isNotEmpty ? 1 : 0) +
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
          FsMobilePageHeader(
            title: 'Crédit client',
            subtitle:
                'Encours, échéances, paiements partiels — aligné sur vos ventes complétées avec client',
          ),
          SizedBox(
            height: FsMobilePageHeader.isMobileLayout(context) ? 12 : 20,
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /* Mobile : dates en Row+Expanded (ellipsis) ; presets 7j/30j/90j en Wrap ;
                     boutique pleine largeur. */
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 12),
                  /* Dates : Row + Expanded + ellipsis — un Wrap avec plusieurs
                     OutlinedButton peut encore dépasser si chaque bouton impose
                     une largeur intrinsèque > 1/2 écran (texte agrandi, paddings M3). */
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _fromYmd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '—',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickToDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _toYmd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(7),
                        child: const Text('7j'),
                      ),
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(30),
                        child: const Text('30j'),
                      ),
                      OutlinedButton(
                        onPressed: () => _applyQuickRange(90),
                        child: const Text('90j'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      OutlinedButton(
                        onPressed: _resetCreditFilters,
                        child: const Text('Réinitialiser'),
                      ),
                      if (canExport) ...[
                        OutlinedButton.icon(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => _exportCsv(filtered),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => _exportCreditExcel(filtered),
                          icon: const Icon(Icons.table_chart, size: 18),
                          label: const Text('Excel'),
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
                  (wide ? 132.0 : 168.0) * textScale.clamp(1.0, 1.35);
              final recoveryPct =
                  recoveryRate.round().clamp(0, 100);
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
                  kpi(
                    'Taux de recouvrement',
                    '$recoveryPct%',
                    subtitle: 'Portefeuille: ${formatCurrency(portfolioTotal)}',
                    icon: Icons.trending_up,
                    iconBg: Colors.indigo.withValues(alpha: 0.12),
                    iconFg: Colors.indigo.shade700,
                  ),
                  kpi(
                    'Ticket moyen (dossiers ouverts)',
                    formatCurrency(avgOpenTicket),
                    subtitle: 'Reste moyen par dossier',
                    icon: Icons.insights,
                    iconBg: Colors.purple.withValues(alpha: 0.12),
                    iconFg: Colors.purple.shade700,
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
                  Text(
                    'Priorité recouvrement',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (ctx, bc) {
                      final row = bc.maxWidth >= 720;
                      final children = [
                        _miniAmountCard(
                          theme,
                          'En retard',
                          formatCurrency(overdue),
                          borderColor: const Color(0xFFFCA5A5),
                          backgroundColor: const Color(0xFFFEF2F2),
                          valueColor: const Color(0xFFB91C1C),
                        ),
                        _miniAmountCard(
                          theme,
                          'À relancer aujourd\'hui',
                          formatCurrency(dueToday),
                          borderColor: const Color(0xFFFCD34D),
                          backgroundColor: const Color(0xFFFFFBEB),
                          valueColor: const Color(0xFFB45309),
                        ),
                        _miniAmountCard(
                          theme,
                          'Échéance semaine',
                          formatCurrency(dueWeek),
                          borderColor: const Color(0xFF5EEAD4),
                          backgroundColor: const Color(0xFFF0FDFA),
                          valueColor: const Color(0xFF0F766E),
                        ),
                      ];
                      if (row) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < children.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: children[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            children[i],
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Top 5 clients à relancer',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Tri: retard puis montant',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (topRelanceRows.isEmpty)
                    Text(
                      'Aucun client à relancer pour la période sélectionnée.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    FsHorizontalScrollShell(
                      builder: (context, c) => SingleChildScrollView(
                        controller: c,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Contact')),
                          DataColumn(
                            label: Text('Dossiers'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Total dû'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('En retard'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Retard max'),
                            numeric: true,
                          ),
                        ],
                        rows: topRelanceRows.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 200,
                                  ),
                                  child: Text(
                                    r.customerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                r.phone != null && r.phone!.isNotEmpty
                                    ? Text(
                                        r.phone!,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : const Text('—'),
                              ),
                              DataCell(Text('${r.openCount}')),
                              DataCell(
                                Text(
                                  formatCurrency(r.totalDue),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  formatCurrency(r.overdueDue),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.maxDelayDays > 0
                                      ? '${r.maxDelayDays} j'
                                      : r.dueTodayDue > 0
                                      ? 'Aujourd\'hui'
                                      : 'À venir',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    ),
                ],
              ),
            ),
          ),
          if (cancelledCreditCount > 0) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: const Text('Créances neutralisées'),
                      backgroundColor: Colors.blueGrey.shade200,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '$cancelledCreditCount vente(s) annulée(s)/remboursée(s) '
                      'retirée(s) automatiquement des crédits',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '(${formatCurrency(cancelledCreditAmount)})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sellerFieldWidth = (constraints.maxWidth * 0.42)
                          .clamp(120.0, 200.0);
                      final filterBar = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: sellerFieldWidth,
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
                              onChanged: (v) =>
                                  setState(() => _sellerId = v ?? ''),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.dividerColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _viewToggle(
                                    theme,
                                    'Par vente',
                                    _CreditView.sale,
                                  ),
                                  _viewToggle(
                                    theme,
                                    'Par client',
                                    _CreditView.customer,
                                  ),
                                ],
                              ),
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
                      );
                      final searchField = TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Client, téléphone, référence, montant, vendeur…',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                      if (constraints.maxWidth >= 560) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: filterBar),
                            const SizedBox(width: 12),
                            Expanded(child: searchField),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          filterBar,
                          const SizedBox(height: 10),
                          searchField,
                        ],
                      );
                    },
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
                      _chipBtn(theme, _QuickChip.soldes, 'Soldés'),
                    ],
                  ),
                  if (_chip == _QuickChip.soldes) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Ventes passées à crédit (ligne POS « à crédit ») et bons dépôt '
                      'à crédit entièrement soldés sur la période — ouvrez « Voir » pour '
                      'l\'historique des paiements.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                  TextField(
                    controller: _legacySearchCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Rechercher dans le crédit libre (client, téléphone, libellé…)…',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
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
                      final allLegacy = snap.data ?? const <LegacyCreditRow>[];
                      final rows = allLegacy
                          .where((r) => _legacyRemaining(r) > creditAmountEps)
                          .where((r) => _legacyRowMatchesSearch(r))
                          .toList();
                      final settledLegacy = allLegacy
                          .where((r) => _legacyRemaining(r) <= creditAmountEps)
                          .where((r) => _legacyRowMatchesSearch(r))
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      final settledLegacyFiltered = settledLegacy
                          .where(
                            (r) => _legacyRowMatchesSingleQuery(
                              r,
                              _appliedLegacyHistoryText,
                            ),
                          )
                          .toList();
                      final settledVenteMainOnly =
                          _settledSalesMatchingMainOnly(creditRows);
                      final settledVenteForHistory =
                          _settledSalesMatchingMainAndHistory(creditRows);
                      final settledHistoryBadgeTotal =
                          settledLegacy.length + settledVenteMainOnly.length;
                      final settledCombined = <_SettledHistoryRow>[
                        ...settledLegacyFiltered.map(
                          _SettledHistoryRow.creditLibre,
                        ),
                        ...settledVenteForHistory.map(
                          _SettledHistoryRow.venteNormale,
                        ),
                      ];
                      _sortSettledHistoryRows(settledCombined);
                      _sortLegacyOpenRows(rows);
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
                            if (settledHistoryBadgeTotal > 0) ...[
                              const SizedBox(height: 16),
                              _legacySettledSection(
                                theme: theme,
                                settledTotalCount: settledHistoryBadgeTotal,
                                settledRowsFiltered: settledCombined,
                                companyId: companyId,
                                perm: perm,
                              ),
                            ],
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
                          FsHorizontalScrollShell(
                            builder: (context, c) => SingleChildScrollView(
                              controller: c,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Client')),
                                DataColumn(label: Text('Libellé')),
                                DataColumn(label: Text('Vendeur')),
                                DataColumn(label: Text('Entreprise')),
                                DataColumn(label: Text('Date de création')),
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
                                      Text(formatOperationDateTime(r.createdAt)),
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
                                            : formatOperationDateTime(r.dueAt!),
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
                          if (settledHistoryBadgeTotal > 0) ...[
                            const SizedBox(height: 16),
                            _legacySettledSection(
                              theme: theme,
                              settledTotalCount: settledHistoryBadgeTotal,
                              settledRowsFiltered: settledCombined,
                              companyId: companyId,
                              perm: perm,
                            ),
                          ],
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
    final blocked =
        _chip == _QuickChip.soldes && v == _CreditView.customer;
    return Material(
      color: sel ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: blocked
            ? null
            : () => setState(() => _view = v),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: blocked
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                  : sel
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
      onSelected: (_) => setState(() {
        _chip = c;
        if (c == _QuickChip.soldes) {
          _view = _CreditView.sale;
        }
      }),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: sel ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _miniAmountCard(
    ThemeData theme,
    String label,
    String value, {
    Color? borderColor,
    Color? backgroundColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor ??
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outlineVariant,
        ),
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
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legacySettledSection({
    required ThemeData theme,
    required int settledTotalCount,
    required List<_SettledHistoryRow> settledRowsFiltered,
    required String companyId,
    required PermissionsProvider perm,
  }) {
    final settledListRows = settledRowsFiltered.length;
    final settledTotalPages = settledListRows == 0
        ? 1
        : ((settledListRows - 1) ~/ _tablePageSize) + 1;
    final settledPage = _legacySettledPage.clamp(0, settledTotalPages - 1);
    final settledStart = settledPage * _tablePageSize;
    final settledEnd = (settledStart + _tablePageSize).clamp(0, settledListRows);
    final pagedSettledRows = settledListRows == 0
        ? const <_SettledHistoryRow>[]
        : settledRowsFiltered.sublist(settledStart, settledEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.dividerColor),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Historique — crédits soldés ($settledTotalCount)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: Icon(
            _legacyShowSettled ? Icons.expand_less : Icons.expand_more,
            color: theme.colorScheme.primary,
          ),
          onTap: () => setState(() => _legacyShowSettled = !_legacyShowSettled),
        ),
        if (_legacyShowSettled) ...[
          Text(
            'Crédit libre et ventes à crédit entièrement recouvrées — « Paiements » (libre) '
            'ou « Voir » (vente) pour le détail.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _legacyHistorySearchCtrl,
            decoration: InputDecoration(
              hintText:
                  'Filtrer l’historique (client, tel., réf. vente, libellé crédit libre…)…',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (settledRowsFiltered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                settledTotalCount > 0
                    ? 'Aucun dossier ne correspond à cette recherche.'
                    : '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            FsHorizontalScrollShell(
              builder: (context, c) => SingleChildScrollView(
                controller: c,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                ),
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Libellé')),
                  DataColumn(label: Text('Vendeur')),
                  DataColumn(label: Text('Montant'), numeric: true),
                  DataColumn(label: Text('Encaissé'), numeric: true),
                  DataColumn(label: Text('Date de création')),
                  DataColumn(label: Text('Statut')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: pagedSettledRows.map((row) {
                  if (row.kind == _SettledHistoryKind.creditLibre) {
                    final r = row.legacy!;
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Crédit libre',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepPurple.shade800,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(r.customerName ?? '—')),
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              r.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(_legacyVendor(r.internalNote))),
                        DataCell(Text(formatCurrency(r.principalAmount))),
                        DataCell(
                          Text(
                            formatCurrency(_legacyPaid(r)),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text(formatOperationDateTime(r.createdAt))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Soldé',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => _openLegacyHistory(r),
                                child: const Text('Paiements'),
                              ),
                              if (perm.isOwner) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: _legacyBusy
                                      ? null
                                      : () => _deleteLegacy(companyId, r),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  final s = row.sale!;
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Vente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.indigo.shade800,
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
                          s.saleNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
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
                      DataCell(Text(formatCurrency(s.total))),
                      DataCell(
                        Text(
                          formatCurrency(paidRealized(s)),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text(formatOperationDateTime(s.createdAt))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Soldé',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        OutlinedButton(
                          onPressed: () => _openDetail(s.id, companyId),
                          child: const Text('Voir'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            ),
            _tablePager(
              page: settledPage,
              totalPages: settledTotalPages,
              start: settledStart,
              end: settledEnd,
              totalItems: settledListRows,
              onPrev: settledPage > 0
                  ? () => setState(
                      () => _legacySettledPage = settledPage - 1,
                    )
                  : null,
              onNext: settledPage < settledTotalPages - 1
                  ? () => setState(
                      () => _legacySettledPage = settledPage + 1,
                    )
                  : null,
            ),
          ],
        ],
      ],
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
    return FsHorizontalScrollShell(
      builder: (context, c) => SingleChildScrollView(
        controller: c,
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
                DataCell(Text(formatOperationDateTime(s.createdAt))),
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
                          text: formatOperationDateTime(effectiveDueAt(s)),
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
            final paidRaw = _dispatchPaidAmountFromNotes(
              d.notes,
              total ?? 0,
            );
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
                DataCell(Text(formatOperationDateTime(d.createdAt))),
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
                        onPressed: () => _openDispatchDetailRt(
                          d.id,
                          companyId: companyId,
                          canPay: canPay,
                          summary: d,
                        ),
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
    return FsHorizontalScrollShell(
      builder: (context, c) => SingleChildScrollView(
        controller: c,
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
              DataCell(
                c.phone != null && c.phone!.trim().isNotEmpty
                    ? InkWell(
                        onTap: () async {
                          final u = Uri.parse('tel:${c.phone!.trim()}');
                          if (await canLaunchUrl(u)) {
                            await launchUrl(u);
                          }
                        },
                        child: Text(
                          c.phone!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : const Text('—'),
              ),
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
                      ? formatOperationDateTime(c.lastPaymentAt!)
                      : '—',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DataCell(
                Text(
                  c.nextDueAt != null
                      ? formatOperationDateTime(c.nextDueAt!)
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
