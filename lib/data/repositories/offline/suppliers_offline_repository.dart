import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/supplier.dart';

/// Offline-first suppliers: UI reads from Drift; sync writes from Supabase.
class SuppliersOfflineRepository {
  SuppliersOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Supplier>> watchSuppliers(String companyId) {
    return _db.watchLocalSuppliers(companyId).map((rows) => rows.map(_toSupplier).toList());
  }

  /// Supprime un fournisseur du cache local (après suppression côté serveur).
  Future<void> deleteSupplier(String id) async {
    await _db.deleteLocalSupplier(id);
  }

  /// Upsert un fournisseur en local pour mise à jour immédiate de l'UI après create/update.
  Future<void> upsertSupplier(Supplier s) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.upsertLocalSuppliers([
      LocalSuppliersCompanion.insert(
        id: s.id,
        companyId: s.companyId,
        name: s.name,
        contact: Value(s.contact),
        phone: Value(s.phone),
        email: Value(s.email),
        address: Value(s.address),
        notes: Value(s.notes),
        updatedAt: now,
      ),
    ]);
  }

  static Supplier _toSupplier(LocalSupplier row) {
    return Supplier(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      contact: row.contact,
      phone: row.phone,
      email: row.email,
      address: row.address,
      notes: row.notes,
    );
  }
}
