import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error_handler.dart';
import '../../providers/offline_providers.dart';

Future<void> _runSyncSafely(Future<void> Function() runSync) async {
  try {
    await runSync();
  } catch (e, st) {
    AppErrorHandler.log(e, st);
  }
}

/// Erreurs RPC PostgreSQL typiques quand le cache Drift (stock boutique / dépôt) peut être désynchronisé.
bool shouldRecoverInventoryCachesFromRpcError(Object error) {
  final m = error.toString().toLowerCase();
  return m.contains('stock insuffisant') ||
      m.contains('stock magasin insuffisant') ||
      m.contains('produit réservé au dépôt magasin') ||
      m.contains('pas à la vente en boutique') ||
      m.contains('sortie dépôt impossible') ||
      m.contains("pas d'ajustement au dépôt") ||
      m.contains('réservé aux boutiques : pas');
}

/// Après refus serveur sur une vente POS : réaligner le stock boutique local.
void recoverStoreInventoryCacheAfterRpcError(
  WidgetRef ref,
  String storeId,
  Future<void> Function() runSync,
) {
  ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
  unawaited(_runSyncSafely(runSync));
}

/// Après refus sur une opération dépôt : réaligner le stock magasin local.
void recoverWarehouseInventoryCacheAfterRpcError(
  WidgetRef ref,
  String companyId,
  Future<void> Function() runSync,
) {
  ref.invalidate(warehouseInventoryStreamProvider(companyId));
  unawaited(_runSyncSafely(runSync));
}

/// Transfert (origine boutique + destination + éventuellement dépôt) : invalider les flux concernés.
void recoverStoresAndWarehouseInventoryCachesAfterRpcError(
  WidgetRef ref, {
  required String companyId,
  String? storeId,
  String? secondStoreId,
  required Future<void> Function() runSync,
}) {
  if (storeId != null && storeId.isNotEmpty) {
    ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
  }
  if (secondStoreId != null &&
      secondStoreId.isNotEmpty &&
      secondStoreId != storeId) {
    ref.invalidate(inventoryQuantitiesStreamProvider(secondStoreId));
  }
  ref.invalidate(warehouseInventoryStreamProvider(companyId));
  unawaited(_runSyncSafely(runSync));
}
