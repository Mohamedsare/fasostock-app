import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/store.dart';

/// Offline-first stores: UI reads from Drift; sync writes from Supabase.
class StoresOfflineRepository {
  StoresOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Store>> watchStores(String companyId) {
    return _db.watchLocalStores(companyId).map((rows) => rows.map(_toStore).toList());
  }

  /// Upsert une boutique en local pour mise à jour immédiate de l'UI après create/update.
  Future<void> upsertStore(Store s) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.upsertLocalStores([
      LocalStoresCompanion.insert(
        id: s.id,
        companyId: s.companyId,
        name: s.name,
        code: Value(s.code),
        address: Value(s.address),
        logoUrl: Value(s.logoUrl),
        phone: Value(s.phone),
        email: Value(s.email),
        description: Value(s.description),
        isActive: Value(s.isActive),
        isPrimary: Value(s.isPrimary),
        posDiscountEnabled: Value(s.posDiscountEnabled),
        updatedAt: s.createdAt ?? now,
        currency: Value(s.currency),
        primaryColor: Value(s.primaryColor),
        secondaryColor: Value(s.secondaryColor),
        invoicePrefix: Value(s.invoicePrefix),
        footerText: Value(s.footerText),
        legalInfo: Value(s.legalInfo),
        signatureUrl: Value(s.signatureUrl),
        stampUrl: Value(s.stampUrl),
        paymentTerms: Value(s.paymentTerms),
        taxLabel: Value(s.taxLabel),
        taxNumber: Value(s.taxNumber),
        city: Value(s.city),
        country: Value(s.country),
        commercialName: Value(s.commercialName),
        slogan: Value(s.slogan),
        activity: Value(s.activity),
        mobileMoney: Value(s.mobileMoney),
        invoiceShortTitle: Value(s.invoiceShortTitle),
        invoiceSignerTitle: Value(s.invoiceSignerTitle),
        invoiceSignerName: Value(s.invoiceSignerName),
        invoiceTemplate: Value(s.invoiceTemplate),
      ),
    ]);
  }

  static Store _toStore(LocalStore row) {
    return Store(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      code: row.code,
      address: row.address,
      logoUrl: row.logoUrl,
      phone: row.phone,
      email: row.email,
      description: row.description,
      isActive: row.isActive,
      isPrimary: row.isPrimary,
      posDiscountEnabled: row.posDiscountEnabled,
      createdAt: row.updatedAt,
      currency: row.currency,
      primaryColor: row.primaryColor,
      secondaryColor: row.secondaryColor,
      invoicePrefix: row.invoicePrefix,
      footerText: row.footerText,
      legalInfo: row.legalInfo,
      signatureUrl: row.signatureUrl,
      stampUrl: row.stampUrl,
      paymentTerms: row.paymentTerms,
      taxLabel: row.taxLabel,
      taxNumber: row.taxNumber,
      city: row.city,
      country: row.country,
      commercialName: row.commercialName,
      slogan: row.slogan,
      activity: row.activity,
      mobileMoney: row.mobileMoney,
      invoiceShortTitle: row.invoiceShortTitle,
      invoiceSignerTitle: row.invoiceSignerTitle,
      invoiceSignerName: row.invoiceSignerName,
      invoiceTemplate: row.invoiceTemplate,
    );
  }
}
