import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../local/drift/app_database.dart';
import '../models/sale.dart';
import '../repositories/sales_repository.dart';
import 'sync_service_v2.dart';

/// Pousse les changements `sales` Supabase (Realtime + RLS) vers Drift.
/// Complète le sync périodique (offline-first intact : hors ligne, pas d’événements ; la sync refera le pull).
class SalesRealtimeSync {
  SalesRealtimeSync(this._db, {SyncServiceV2? syncService}) : _syncService = syncService;

  final AppDatabase _db;
  final SyncServiceV2? _syncService;
  RealtimeChannel? _channel;

  static const RealtimeChannelConfig _channelConfig = RealtimeChannelConfig(
    private: true,
  );

  Future<void> start() async {
    if (_channel != null) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      await client.realtime.setAuth(token);
    } catch (e, st) {
      AppErrorHandler.log('SalesRealtime.setAuth: $e', st);
      return;
    }

    if (_channel != null) return;

    _channel = client.channel(
      'fasostock-sales-$uid',
      opts: _channelConfig,
    );
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales',
          callback: _onPayload,
        )
        .subscribe((status, [error]) {
          if (kDebugMode) {
            debugPrint('[SalesRealtime] $status ${error ?? ''}');
          }
          if (error != null) {
            AppErrorHandler.logWithContext(
              error,
              logSource: 'sales_realtime',
              logContext: {'channel_status': status.toString()},
            );
          }
        });
  }

  Future<void> _onPayload(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          await _applySaleRow(payload.newRecord);
          break;
        case PostgresChangeEvent.delete:
          await _applyDelete(payload.oldRecord);
          break;
        default:
          break;
      }
    } catch (e, st) {
      AppErrorHandler.log('SalesRealtime: $e', st);
    }
  }

  static String? _uuid(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static String _asIsoString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is DateTime) return v.toUtc().toIso8601String();
    return v.toString();
  }

  /// Normalise le payload Realtime pour [Sale.fromJson] (types / manques).
  static Map<String, dynamic> _rowForSaleJson(Map<String, dynamic> raw) {
    return {
      'id': _asIsoString(raw['id']),
      'company_id': _asIsoString(raw['company_id']),
      'store_id': _asIsoString(raw['store_id']),
      'customer_id': raw['customer_id'] == null ? null : _asIsoString(raw['customer_id']),
      'sale_number': _asIsoString(raw['sale_number']),
      'status': raw['status'] == null ? 'draft' : _asIsoString(raw['status']),
      'subtotal': raw['subtotal'],
      'discount': raw['discount'],
      'tax': raw['tax'],
      'total': raw['total'],
      'created_by': _asIsoString(raw['created_by']),
      'created_at': _asIsoString(raw['created_at']),
      'updated_at': _asIsoString(raw['updated_at']),
      'sale_mode': raw['sale_mode'] == null ? null : _asIsoString(raw['sale_mode']),
      'document_type': raw['document_type'] == null ? null : _asIsoString(raw['document_type']),
    };
  }

  Future<void> _applySaleRow(Map<String, dynamic> raw) async {
    if (raw.isEmpty) return;
    final id = _uuid(raw['id']);
    if (id == null || id.isEmpty) return;
    if (id.startsWith('pending:')) return;

    final Sale sale;
    try {
      sale = Sale.fromJson(_rowForSaleJson(Map<String, dynamic>.from(raw)));
    } catch (e, st) {
      AppErrorHandler.log('SalesRealtime.parse: $e', st);
      return;
    }

    await _db.upsertLocalSale(
      LocalSalesCompanion.insert(
        id: sale.id,
        companyId: sale.companyId,
        storeId: sale.storeId,
        customerId: Value(sale.customerId),
        saleNumber: sale.saleNumber,
        status: sale.status.value,
        subtotal: Value(sale.subtotal),
        discount: Value(sale.discount),
        tax: Value(sale.tax),
        total: sale.total,
        createdBy: sale.createdBy,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
        saleMode: Value(sale.saleMode?.value),
        documentType: Value(sale.documentType?.value),
      ),
    );

    try {
      final repo = SalesRepository();
      final items = await repo.getItems(sale.id);
      await _db.deleteLocalSaleItemsBySaleId(sale.id);
      if (items.isNotEmpty) {
        final now = DateTime.now().toUtc().toIso8601String();
        await _db.upsertLocalSaleItems(
          items.map(
            (i) => LocalSaleItemsCompanion.insert(
              id: i.id,
              saleId: i.saleId,
              productId: i.productId,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              total: i.total,
              createdAt: now,
            ),
          ),
        );
      }
    } catch (e, st) {
      AppErrorHandler.log('SalesRealtime.fetchItems id=${sale.id}: $e', st);
    }

    // Même réactivité que l’annulation locale (pull + Drift) : tous les caissiers voient
    // le stock rétabli sans attendre uniquement les événements `store_inventory` ou le poll 2 s.
    final statusRaw = raw['status'];
    final statusStr = statusRaw == null ? '' : statusRaw.toString().toLowerCase();
    if (statusStr == 'cancelled') {
      final sid = _uuid(raw['store_id']);
      if (sid != null && sid.isNotEmpty) {
        final sync = _syncService;
        if (sync != null) {
          unawaited(sync.pullInventoryQuantitiesForStores([sid]));
        }
      }
    }
  }

  Future<void> _applyDelete(Map<String, dynamic> raw) async {
    if (raw.isEmpty) return;
    final id = _uuid(raw['id']);
    if (id == null || id.isEmpty || id.startsWith('pending:')) return;
    await _db.deleteLocalSale(id);
  }

  Future<void> stop() async {
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        await Supabase.instance.client.removeChannel(c);
      } catch (e, st) {
        AppErrorHandler.log('SalesRealtime.stop: $e', st);
      }
    }
  }
}
