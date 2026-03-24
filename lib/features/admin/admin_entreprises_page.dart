import 'package:flutter/material.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Gestion entreprises + boutiques (équivalent AdminEntreprisesPage web).
class AdminEntreprisesPage extends StatefulWidget {
  const AdminEntreprisesPage({super.key});

  @override
  State<AdminEntreprisesPage> createState() => _AdminEntreprisesPageState();
}

class _AdminEntreprisesPageState extends State<AdminEntreprisesPage> {
  final AdminRepository _repo = AdminRepository();
  String? _expandedCompanyId;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return Container(
      color: AdminPalette.surfaceAlt,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
            title: 'Entreprises',
            description: 'Gestion des entreprises et de leurs boutiques',
          ),
          const SizedBox(height: 24),
          FutureBuilder(
            future: Future.wait([_repo.listCompanies(), _repo.listStores()]),
            builder: (context, snap) {
              if (!snap.hasData) {
                return AdminCard(
                  padding: const EdgeInsets.all(24),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final companies = snap.data![0] as List<AdminCompany>;
              final stores = snap.data![1] as List<AdminStore>;
              final storesByCompany = <String, List<AdminStore>>{};
              for (final s in stores) {
                storesByCompany.putIfAbsent(s.companyId, () => []).add(s);
              }
              return AdminCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('')),
                          DataColumn(label: Text('Nom', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Slug', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Statut', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Préd. IA', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Quota', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Actions', style: AdminPalette.dataTableHeader)),
                        ],
                        rows: companies.map((c) {
                          final isExpanded = _expandedCompanyId == c.id;
                          final companyStores = storesByCompany[c.id] ?? [];
                          return DataRow(
                            cells: [
                              DataCell(InkWell(
                                onTap: companyStores.isEmpty ? null : () => setState(() => _expandedCompanyId = isExpanded ? null : c.id),
                                child: Icon(companyStores.isEmpty ? null : (isExpanded ? Icons.expand_more : Icons.chevron_right), size: 24, color: AdminPalette.title),
                              )),
                              DataCell(Text(c.name, style: AdminPalette.dataTableCell)),
                              DataCell(Text(c.slug ?? '—', style: AdminPalette.dataTableCell)),
                              DataCell(Text(c.isActive ? 'Actif' : 'Inactif', style: TextStyle(color: c.isActive ? Colors.green : AdminPalette.subtitle, fontWeight: FontWeight.w500))),
                              DataCell(Text(c.aiPredictionsEnabled ? 'Oui' : 'Non', style: TextStyle(color: c.aiPredictionsEnabled ? Colors.green : AdminPalette.subtitle, fontWeight: FontWeight.w500))),
                              DataCell(Text('${c.storeQuota}', style: AdminPalette.dataTableCell)),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(c.isActive ? Icons.power_off : Icons.power_settings_new, size: 20, color: AdminPalette.title),
                                    tooltip: c.isActive ? 'Désactiver' : 'Activer',
                                    onPressed: () => _updateCompany(c.id, isActive: !c.isActive),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, size: 20, color: AdminPalette.title),
                                    tooltip: c.aiPredictionsEnabled ? 'Désactiver IA' : 'Activer IA',
                                    onPressed: () => _updateCompany(c.id, aiPredictionsEnabled: !c.aiPredictionsEnabled),
                                  ),
                                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Supprimer', onPressed: () => _confirmDelete(type: 'company', id: c.id, name: c.name)),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    if (_expandedCompanyId != null)
                      ...companies.where((c) => c.id == _expandedCompanyId).map((c) {
                        final companyStores = storesByCompany[c.id] ?? [];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AdminPalette.surfaceAlt),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Boutiques (${companyStores.length})', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminPalette.title, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              ...companyStores.map((s) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: AdminPalette.surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AdminPalette.border),
                                    ),
                                    child: ListTile(
                                      title: Text(s.name, style: AdminPalette.dataTableCell),
                                      subtitle: Text(s.isPrimary ? 'Principale' : '', style: const TextStyle(color: AdminPalette.subtitle, fontSize: 13)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(s.isActive ? 'Actif' : 'Inactif', style: TextStyle(color: s.isActive ? Colors.green : AdminPalette.subtitle, fontSize: 12)),
                                          IconButton(icon: Icon(s.isActive ? Icons.power_off : Icons.power_settings_new, size: 18, color: AdminPalette.title), onPressed: () => _updateStore(s.id, !s.isActive)),
                                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDelete(type: 'store', id: s.id, name: s.name)),
                                        ],
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCompany(String id, {bool? isActive, bool? aiPredictionsEnabled}) async {
    try {
      await _repo.updateCompany(id, isActive: isActive, aiPredictionsEnabled: aiPredictionsEnabled);
      if (mounted) {
        setState(() {});
        AppToast.success(context, 'Entreprise mise à jour');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _updateStore(String id, bool isActive) async {
    try {
      await _repo.updateStore(id, isActive: isActive);
      if (mounted) {
        setState(() {});
        AppToast.success(context, 'Boutique mise à jour');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _doDelete({
    required String type,
    required String id,
  }) async {
    try {
      if (type == 'company') {
        await _repo.deleteCompany(id);
      } else {
        await _repo.deleteStore(id);
      }
      if (mounted) {
        AppToast.success(context, 'Supprimé définitivement');
        setState(() {});
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmDelete({
    required String type,
    required String id,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Text(
          type == 'company'
              ? "L'entreprise « $name » et toutes ses données seront supprimées. Irréversible."
              : "La boutique « $name » sera supprimée définitivement. Irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _doDelete(type: type, id: id);
    }
  }
}
