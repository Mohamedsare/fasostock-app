import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../local/drift/app_database.dart';
import '../models/sale.dart';
import 'credit_repository.dart';
import 'offline/sales_offline_repository.dart';
import 'sales_repository.dart';

/// Crédit : **offline-first** (Drift + file d’attente) avec RPC / REST en ligne et repli local.
class CreditSyncFacade {
  CreditSyncFacade(
    this._db,
    this._offlineSales, {
    CreditRepository? remote,
    SalesRepository? salesRepo,
    ConnectivityService? connectivity,
  })  : _remote = remote ?? CreditRepository(),
        _salesRepo = salesRepo ?? SalesRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance;

  final AppDatabase _db;
  final SalesOfflineRepository _offlineSales;
  final CreditRepository _remote;
  final SalesRepository _salesRepo;
  final ConnectivityService _connectivity;

  Future<Sale?> fetchCreditSaleDetail(String saleId, String companyId) async {
    if (saleId.startsWith('pending:')) {
      return _offlineSales.getCreditSaleDetailOffline(saleId, companyId);
    }
    if (_connectivity.isOnline) {
      try {
        return await _remote.fetchCreditSaleDetail(saleId);
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'credit_sync_facade',
          logContext: {'op': 'fetchCreditSaleDetail', 'sale_id': saleId, 'fallback': 'local'},
        );
      }
    }
    try {
      return await _offlineSales.getCreditSaleDetailOffline(saleId, companyId);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_sync_facade',
        logContext: {'op': 'getCreditSaleDetailOffline', 'sale_id': saleId},
      );
      rethrow;
    }
  }

  Future<void> appendSalePayment({
    required String saleId,
    required PaymentMethod method,
    required double amount,
    String? reference,
  }) async {
    if (saleId.startsWith('pending:')) {
      throw StateError('Paiement crédit impossible pour une vente locale non synchronisée.');
    }
    if (amount <= 0) {
      throw ArgumentError('Montant invalide.');
    }
    if (_connectivity.isOnline) {
      try {
        await _remote.appendSalePayment(
          saleId: saleId,
          method: method,
          amount: amount,
          reference: reference,
        );
        final now = DateTime.now().toUtc().toIso8601String();
        try {
          final pays = await _salesRepo.getPayments(saleId);
          await _db.replaceLocalSalePaymentsFromModels(saleId, pays, now);
        } catch (e, st) {
          AppErrorHandler.logWithContext(
            e,
            stackTrace: st,
            logSource: 'credit_sync_facade',
            logContext: {'op': 'refreshPaymentsAfterRpc', 'sale_id': saleId},
          );
        }
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'credit_sync_facade',
          logContext: {'op': 'appendSalePayment_online', 'sale_id': saleId},
        );
        rethrow;
      }
      return;
    }

    final localPayId =
        'pending:pay_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(0x7fffffff)}';
    final createdAt = DateTime.now().toUtc().toIso8601String();
    try {
      await _db.upsertLocalSalePayments([
        LocalSalePaymentsCompanion.insert(
          id: localPayId,
          saleId: saleId,
          method: method.value,
          amount: amount,
          reference: Value(reference),
          createdAt: Value(createdAt),
        ),
      ]);
      await _db.enqueuePendingAction(
        'credit_append_payment',
        jsonEncode({
          'sale_id': saleId,
          'method': method.value,
          'amount': amount,
          'reference': reference,
          'local_payment_id': localPayId,
        }),
      );
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_sync_facade',
        logContext: {'op': 'appendSalePayment_offline', 'sale_id': saleId},
      );
      rethrow;
    }
  }

  Future<void> updateSaleCreditMeta({
    required String saleId,
    String? creditDueAtIso,
    String? creditInternalNote,
  }) async {
    if (saleId.startsWith('pending:')) {
      throw StateError('Mise à jour crédit impossible pour une vente locale non synchronisée.');
    }
    final trimmed = creditInternalNote == null
        ? null
        : (creditInternalNote.trim().isEmpty ? null : creditInternalNote.trim());
    if (_connectivity.isOnline) {
      try {
        await _remote.updateSaleCreditMeta(
          saleId: saleId,
          creditDueAtIso: creditDueAtIso,
          creditInternalNote: creditInternalNote,
        );
        await _db.updateLocalSaleCreditMeta(saleId, creditDueAtIso, trimmed);
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'credit_sync_facade',
          logContext: {'op': 'updateSaleCreditMeta_online', 'sale_id': saleId},
        );
        rethrow;
      }
      return;
    }

    try {
      await _db.updateLocalSaleCreditMeta(saleId, creditDueAtIso, trimmed);
      await _db.enqueuePendingAction(
        'credit_update_meta',
        jsonEncode({
          'sale_id': saleId,
          'credit_due_at': creditDueAtIso,
          'credit_internal_note': trimmed,
        }),
      );
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'credit_sync_facade',
        logContext: {'op': 'updateSaleCreditMeta_offline', 'sale_id': saleId},
      );
      rethrow;
    }
  }
}
