import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error_handler.dart';
import '../models/warehouse_movement.dart';
import '../models/warehouse_stock_line.dart';
import 'warehouse_dispatch_input.dart';

export 'warehouse_dispatch_input.dart';

String _toSafeMessage(Object? e) => ErrorMapper.toMessage(e);

/// Magasin (dépôt central) — lecture stock / mouvements ; écriture via RPC (owner).
class WarehouseRepository {
  WarehouseRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _invSelect =
      'company_id, product_id, quantity, avg_unit_cost, stock_min_warehouse, updated_at, product:products(id, name, sku, unit, purchase_price, sale_price, stock_min)';

  static const _movSelect =
      'id, company_id, product_id, movement_kind, quantity, unit_cost, packaging_type, packs_quantity, reference_type, reference_id, notes, created_at, product:products(id, name, sku)';

  Future<List<WarehouseStockLine>> listInventory(String companyId) async {
    try {
      final data = await _client
          .from('warehouse_inventory')
          .select(_invSelect)
          .eq('company_id', companyId)
          .order('updated_at', ascending: false);
      final list = data as List;
      return list
          .map((e) => WarehouseStockLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((l) => l.productId.isNotEmpty)
          .toList();
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<List<WarehouseMovement>> listMovements(String companyId, {int limit = 200}) async {
    try {
      final data = await _client
          .from('warehouse_movements')
          .select(_movSelect)
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = data as List;
      return list.map((e) => WarehouseMovement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  /// Agrégats pour le tableau de bord magasin.
  Future<WarehouseDashboardSummary> computeDashboard(
    String companyId, {
    List<WarehouseStockLine>? inventory,
    List<WarehouseMovement>? movements,
  }) async {
    final inv = inventory ?? await listInventory(companyId);
    final mov = movements ?? await listMovements(companyId, limit: 500);
    return _dashboardFromData(inv, mov);
  }

  /// Même logique que [computeDashboard] sans appel réseau (listes déjà en mémoire / Drift).
  WarehouseDashboardSummary computeDashboardFromLists(
    List<WarehouseStockLine> inventory,
    List<WarehouseMovement> movements,
  ) {
    return _dashboardFromData(inventory, movements);
  }

  WarehouseDashboardSummary _dashboardFromData(
    List<WarehouseStockLine> inv,
    List<WarehouseMovement> mov,
  ) {
    double valueCost = 0;
    double valueSale = 0;
    var lowCount = 0;
    for (final l in inv) {
      valueCost += l.valueAtCost;
      valueSale += l.valueAtSale;
      if (l.isLowStock) lowCount++;
    }

    final now = DateTime.now().toUtc();
    final from30 = now.subtract(const Duration(days: 30));
    var entries30 = 0;
    var exits30 = 0;
    final byDay = <String, ({int inQ, int outQ})>{};

    for (final m in mov) {
      if (m.createdAt == null) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(m.createdAt!);
      } catch (_) {
        continue;
      }
      if (dt.isBefore(from30)) continue;
      if (m.isEntry) {
        entries30++;
      } else {
        exits30++;
      }
      final dayKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final cur = byDay[dayKey] ?? (inQ: 0, outQ: 0);
      if (m.isEntry) {
        byDay[dayKey] = (inQ: cur.inQ + m.quantity, outQ: cur.outQ);
      } else {
        byDay[dayKey] = (inQ: cur.inQ, outQ: cur.outQ + m.quantity);
      }
    }

    final sortedDays = byDay.keys.toList()..sort();
    final last7 = sortedDays.length > 7 ? sortedDays.sublist(sortedDays.length - 7) : sortedDays;
    final chartIn = <int>[];
    final chartOut = <int>[];
    final chartLabels = <String>[];
    for (final d in last7) {
      final v = byDay[d]!;
      chartLabels.add(d.substring(8));
      chartIn.add(v.inQ);
      chartOut.add(v.outQ);
    }

    return WarehouseDashboardSummary(
      valueAtPurchasePrice: valueCost,
      valueAtSalePrice: valueSale,
      skuCount: inv.length,
      lowStockCount: lowCount,
      movementsEntries30d: entries30,
      movementsExits30d: exits30,
      chartDayLabels: chartLabels,
      chartEntriesQty: chartIn,
      chartExitsQty: chartOut,
    );
  }

  Future<void> registerManualEntry({
    required String companyId,
    required String productId,
    required int quantity,
    required double unitCost,
    required String packagingType,
    double packsQuantity = 1,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'warehouse_register_manual_entry',
        params: {
          'p_company_id': companyId,
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_unit_cost': unitCost,
          'p_packaging_type': packagingType,
          'p_packs_quantity': packsQuantity,
          'p_notes': notes,
        },
      );
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<void> setStockMinWarehouse({
    required String companyId,
    required String productId,
    required int minValue,
  }) async {
    try {
      await _client.rpc(
        'warehouse_set_stock_min_warehouse',
        params: {
          'p_company_id': companyId,
          'p_product_id': productId,
          'p_min': minValue,
        },
      );
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<void> registerExitForSale({
    required String companyId,
    required String saleId,
  }) async {
    try {
      await _client.rpc(
        'warehouse_register_exit_for_sale',
        params: {
          'p_company_id': companyId,
          'p_sale_id': saleId,
        },
      );
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  /// Bon / facture de sortie depuis le **dépôt** uniquement (pas le stock boutique).
  Future<WarehouseDispatchInvoiceResult> createDispatchInvoice({
    required String companyId,
    String? customerId,
    String? notes,
    required List<WarehouseDispatchLineInput> lines,
  }) async {
    if (lines.isEmpty) {
      throw UserFriendlyError('Ajoutez au moins une ligne produit.');
    }
    try {
      final raw = await _client.rpc(
        'warehouse_create_dispatch_invoice',
        params: {
          'p_company_id': companyId,
          'p_customer_id': customerId,
          'p_notes': notes,
          'p_lines': lines.map((e) => e.toJson()).toList(),
        },
      );
      if (raw is! Map) {
        throw UserFriendlyError('Réponse serveur inattendue.');
      }
      final m = Map<String, dynamic>.from(raw);
      final id = m['id'] as String?;
      final doc = m['document_number'] as String?;
      if (id == null || doc == null) {
        throw UserFriendlyError('Réponse serveur incomplète.');
      }
      return WarehouseDispatchInvoiceResult(id: id, documentNumber: doc);
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  /// Ajustement d'inventaire dépôt (delta > 0 : entrée au coût indiqué ; delta < 0 : sortie).
  Future<void> registerAdjustment({
    required String companyId,
    required String productId,
    required int delta,
    double? unitCost,
    String? reason,
  }) async {
    if (delta == 0) {
      throw UserFriendlyError('La variation doit être différente de zéro.');
    }
    try {
      await _client.rpc(
        'warehouse_register_adjustment',
        params: {
          'p_company_id': companyId,
          'p_product_id': productId,
          'p_delta': delta,
          'p_unit_cost': unitCost,
          'p_reason': reason,
        },
      );
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }
}

class WarehouseDashboardSummary {
  const WarehouseDashboardSummary({
    required this.valueAtPurchasePrice,
    required this.valueAtSalePrice,
    required this.skuCount,
    required this.lowStockCount,
    required this.movementsEntries30d,
    required this.movementsExits30d,
    required this.chartDayLabels,
    required this.chartEntriesQty,
    required this.chartExitsQty,
  });

  final double valueAtPurchasePrice;
  final double valueAtSalePrice;
  final int skuCount;
  final int lowStockCount;
  final int movementsEntries30d;
  final int movementsExits30d;
  final List<String> chartDayLabels;
  final List<int> chartEntriesQty;
  final List<int> chartExitsQty;
}
