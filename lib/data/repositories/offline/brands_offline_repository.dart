import '../../local/drift/app_database.dart';
import '../../models/brand.dart';

/// Offline-first brands: UI reads from Drift; sync writes from Supabase.
class BrandsOfflineRepository {
  BrandsOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Brand>> watchBrands(String companyId) {
    return _db.watchLocalBrands(companyId).map((rows) => rows.map(_toBrand).toList());
  }

  /// Upsert une marque en local pour mise à jour immédiate de l'UI après create/update.
  Future<void> upsertBrand(Brand b) async {
    await _db.upsertLocalBrands([
      LocalBrandsCompanion.insert(
        id: b.id,
        companyId: b.companyId,
        name: b.name,
      ),
    ]);
  }

  static Brand _toBrand(LocalBrand row) {
    return Brand(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
    );
  }
}
