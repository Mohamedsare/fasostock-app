import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/audit_repository.dart';
import 'shared/admin_ui.dart';

/// Journal d'audit plateforme — super admin (propriétaire du SaaS).
class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  final AuditRepository _auditRepo = AuditRepository();
  final AdminRepository _adminRepo = AdminRepository();
  List<AuditLogEntry> _entries = [];
  List<AdminCompany> _companies = [];
  String? _selectedCompanyId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _load();
  }

  Future<void> _loadCompanies() async {
    try {
      final list = await _adminRepo.listCompanies();
      if (mounted) setState(() => _companies = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _auditRepo.listForAdmin(
        _selectedCompanyId,
        limit: 100,
      );
      if (mounted) {
        setState(() {
        _entries = list;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _loading = false;
        _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de charger le journal.');
      });
      }
    }
  }

  String _companyName(String? id) {
    if (id == null) return '—';
    return _companies.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

    return Container(
      color: AdminPalette.surfaceAlt,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
            title: 'Journal d\'audit',
            description: 'Activité de toutes les entreprises (vue plateforme)',
          ),
          const SizedBox(height: 24),
          AdminCard(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth > 400;
                final dropdown = SizedBox(
                  width: useRow ? 320 : double.infinity,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCompanyId,
                    decoration: adminInputDecoration(labelText: 'Entreprise'),
                    dropdownColor: AdminPalette.surface,
                    style: const TextStyle(color: AdminPalette.title, fontSize: 15),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les entreprises', style: TextStyle(color: AdminPalette.title))),
                      ..._companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: AdminPalette.title)))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedCompanyId = v;
                        _load();
                      });
                    },
                  ),
                );
                final button = FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminPalette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Actualiser'),
                );
                if (useRow) {
                  return Row(
                    children: [dropdown, const SizedBox(width: 16), button],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [dropdown, const SizedBox(height: 12), button],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            AdminCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const AdminCard(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            AdminCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aucune entrée dans le journal.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AdminPalette.subtitle),
                ),
              ),
            )
          else
            AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (isWide)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Date', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Entreprise', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Action', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Type', style: AdminPalette.dataTableHeader)),
                          DataColumn(label: Text('Détail', style: AdminPalette.dataTableHeader)),
                        ],
                      rows: _entries.map((e) {
                        return DataRow(
                          cells: [
                            DataCell(Text(dateFormat.format(e.createdAt), style: AdminPalette.dataTableCell)),
                            DataCell(Text(_companyName(e.companyId), style: AdminPalette.dataTableCell)),
                            DataCell(Text(e.action, style: AdminPalette.dataTableCell)),
                            DataCell(Text(e.entityType, style: AdminPalette.dataTableCell)),
                            DataCell(IconButton(
                              icon: const Icon(Icons.info_outline_rounded, size: 20, color: AdminPalette.title),
                              onPressed: () => _showDetail(context, e, dateFormat),
                            )),
                          ],
                        );
                      }).toList(),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = _entries[index];
                        return ListTile(
                          title: Text(e.action, style: TextStyle(fontWeight: FontWeight.w600, color: AdminPalette.title)),
                          subtitle: Text('${_companyName(e.companyId)} • ${e.entityType} • ${dateFormat.format(e.createdAt)}', style: TextStyle(color: AdminPalette.subtitle, fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline_rounded, color: AdminPalette.title),
                            onPressed: () => _showDetail(context, e, dateFormat),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AuditLogEntry e, DateFormat dateFormat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Détail', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AdminPalette.title)),
              const SizedBox(height: 16),
              _DetailRow('Entreprise', _companyName(e.companyId)),
              _DetailRow('Action', e.action),
              _DetailRow('Type', e.entityType),
              _DetailRow('Date', dateFormat.format(e.createdAt)),
              if (e.entityId != null) _DetailRow('ID entité', e.entityId!),
              if (e.oldData != null && e.oldData!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Anciennes valeurs', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(color: AdminPalette.title, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.oldData.toString(), style: const TextStyle(color: AdminPalette.subtitle, fontSize: 13)),
              ],
              if (e.newData != null && e.newData!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nouvelles valeurs', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(color: AdminPalette.title, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.newData.toString(), style: const TextStyle(color: AdminPalette.subtitle, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label :', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AdminPalette.title))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminPalette.subtitle))),
        ],
      ),
    );
  }
}
