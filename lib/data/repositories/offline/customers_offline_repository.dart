import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/customer.dart';

/// Offline-first customers: UI reads from Drift; sync writes from Supabase.
class CustomersOfflineRepository {
  CustomersOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Customer>> watchCustomers(String companyId) {
    return _db.watchLocalCustomers(companyId).map((rows) => rows.map(_toCustomer).toList());
  }

  /// Upsert un client en local pour mise à jour immédiate de l'UI après create/update.
  Future<void> upsertCustomer(Customer c) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.upsertLocalCustomers([
      LocalCustomersCompanion.insert(
        id: c.id,
        companyId: c.companyId,
        name: c.name,
        type: Value(c.type.value),
        phone: Value(c.phone),
        email: Value(c.email),
        address: Value(c.address),
        notes: Value(c.notes),
        createdAt: c.createdAt ?? now,
        updatedAt: c.updatedAt ?? now,
      ),
    ]);
  }

  static Customer _toCustomer(LocalCustomer row) {
    return Customer(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      type: row.type == 'company' ? CustomerType.company : CustomerType.individual,
      phone: row.phone,
      email: row.email,
      address: row.address,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
