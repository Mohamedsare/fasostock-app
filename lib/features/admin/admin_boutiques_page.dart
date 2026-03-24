import 'package:flutter/material.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Toutes les boutiques plateforme (équivalent AdminBoutiquesPage web).
class AdminBoutiquesPage extends StatefulWidget {
  const AdminBoutiquesPage({super.key});

  @override
  State<AdminBoutiquesPage> createState() => _AdminBoutiquesPageState();
}

class _AdminBoutiquesPageState extends State<AdminBoutiquesPage> {
  final AdminRepository _repo = AdminRepository();
  String _companyFilter = '';

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
            AdminPageHeader(title: 'Boutiques', description: 'Toutes les boutiques de la plateforme'),
          const SizedBox(height: 24),
          FutureBuilder(
            future: Future.wait([_repo.listCompanies(), _repo.listStores()]),
            builder: (context, snap) {
              if (!snap.hasData) return AdminCard(padding: const EdgeInsets.all(24), child: const Center(child: CircularProgressIndicator()));
              final companies = snap.data![0] as List<AdminCompany>;
              var stores = snap.data![1] as List<AdminStore>;
              if (_companyFilter.isNotEmpty) stores = stores.where((s) => s.companyId == _companyFilter).toList();
              final companyById = {for (final c in companies) c.id: c.name};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (companies.isNotEmpty)
                    Row(
                      children: [
                        Text('Filtrer par entreprise :', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminPalette.title, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _companyFilter.isEmpty ? null : _companyFilter,
                          hint: Text('Toutes', style: TextStyle(color: AdminPalette.subtitle)),
                          items: [
                            DropdownMenuItem(value: '', child: Text('Toutes', style: TextStyle(color: AdminPalette.title))),
                            ...companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(color: AdminPalette.title)))),
                          ],
                          onChanged: (v) => setState(() => _companyFilter = v ?? ''),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  AdminCard(
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Entreprise', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Boutique', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Code', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Statut', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Principale', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Actions', style: AdminPalette.dataTableHeader)),
                        ],
                        rows: stores.map((s) => DataRow(
                          cells: [
                            DataCell(Text(companyById[s.companyId] ?? s.companyId, style: AdminPalette.dataTableCell)),
                            DataCell(Text(s.name, style: AdminPalette.dataTableCell)),
                            DataCell(Text(s.code ?? '—', style: AdminPalette.dataTableCell)),
                            DataCell(Text(s.isActive ? 'Actif' : 'Inactif', style: TextStyle(color: s.isActive ? Colors.green : AdminPalette.subtitle, fontWeight: FontWeight.w500))),
                            DataCell(Text(s.isPrimary ? 'Oui' : '—', style: AdminPalette.dataTableCell)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(s.isActive ? Icons.power_off : Icons.power_settings_new, size: 20, color: AdminPalette.title), tooltip: s.isActive ? 'Désactiver' : 'Activer', onPressed: () => _updateStore(s.id, !s.isActive)),
                                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Supprimer', onPressed: () => _confirmDelete(s)),
                              ],
                            )),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                  if (stores.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Aucune boutique.', style: TextStyle(color: AdminPalette.subtitle)))),
                ],
              );
            },
          ),
          ],
        ),
      ),
    );
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

  Future<void> _doDelete(AdminStore target) async {
    try {
      await _repo.deleteStore(target.id);
      if (mounted) {
        AppToast.success(context, 'Boutique supprimée définitivement');
        setState(() {});
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmDelete(AdminStore target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la boutique ?'),
        content: Text(
          "La boutique « ${target.name} » sera supprimée définitivement. Irréversible.",
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
      await _doDelete(target);
    }
  }
}
