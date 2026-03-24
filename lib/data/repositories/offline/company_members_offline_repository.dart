import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/company_member.dart';

/// Offline-first membres entreprise : UI lit depuis Drift ; sync remplit depuis Supabase.
class CompanyMembersOfflineRepository {
  CompanyMembersOfflineRepository(this._db);

  final AppDatabase _db;

  Stream<List<CompanyMember>> watchMembers(String companyId) {
    return _db.watchLocalCompanyMembers(companyId).map((rows) => rows.map(_toMember).toList());
  }

  static CompanyMember _toMember(LocalCompanyMember row) {
    return CompanyMember(
      id: row.id,
      userId: row.userId,
      roleId: row.roleId,
      isActive: row.isActive,
      createdAt: row.createdAt,
      role: RoleRef(name: row.roleName, slug: row.roleSlug),
      profile: row.profileFullName != null ? ProfileRef(fullName: row.profileFullName) : null,
      email: row.email,
    );
  }

  /// Remplace les membres en local par la liste fournie (sync ou refresh API).
  Future<void> replaceMembers(String companyId, List<CompanyMember> members) async {
    final companions = members.map((m) => LocalCompanyMembersCompanion.insert(
      id: m.id,
      companyId: companyId,
      userId: m.userId,
      roleId: m.roleId,
      isActive: Value(m.isActive),
      createdAt: m.createdAt,
      roleName: m.role.name,
      roleSlug: m.role.slug,
      profileFullName: Value(m.profile?.fullName),
      email: Value(m.email),
    )).toList();
    await _db.upsertLocalCompanyMembers(companions);
    await _db.deleteLocalCompanyMembersNotIn(companyId, members.map((m) => m.id).toSet());
  }

  /// Upsert un ou plusieurs membres sans supprimer les autres (mise à jour immédiate après création).
  Future<void> upsertMembers(String companyId, List<CompanyMember> members) async {
    if (members.isEmpty) return;
    await _db.upsertLocalCompanyMembers(members.map((m) => LocalCompanyMembersCompanion.insert(
      id: m.id,
      companyId: companyId,
      userId: m.userId,
      roleId: m.roleId,
      isActive: Value(m.isActive),
      createdAt: m.createdAt,
      roleName: m.role.name,
      roleSlug: m.role.slug,
      profileFullName: Value(m.profile?.fullName),
      email: Value(m.email),
    )));
  }

  /// Supprime un membre du cache local (après retrait côté serveur).
  Future<void> deleteMember(String id) async {
    await _db.deleteLocalCompanyMember(id);
  }

  /// Met à jour is_active en local (après activation/désactivation côté serveur).
  Future<void> updateMemberIsActive(String id, bool isActive) async {
    await _db.updateLocalCompanyMemberIsActive(id, isActive);
  }
}
