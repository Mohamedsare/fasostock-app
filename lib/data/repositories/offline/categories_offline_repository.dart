import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/category.dart';

/// Offline-first categories: UI reads from Drift; sync writes from Supabase.
class CategoriesOfflineRepository {
  CategoriesOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchCategories(String companyId) {
    return _db.watchLocalCategories(companyId).map((rows) => rows.map(_toCategory).toList());
  }

  /// Upsert une catégorie en local pour mise à jour immédiate de l'UI après create/update.
  Future<void> upsertCategory(Category c) async {
    await _db.upsertLocalCategories([
      LocalCategoriesCompanion.insert(
        id: c.id,
        companyId: c.companyId,
        name: c.name,
        parentId: Value(c.parentId),
      ),
    ]);
  }

  static Category _toCategory(LocalCategory row) {
    return Category(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      parentId: row.parentId,
    );
  }
}
