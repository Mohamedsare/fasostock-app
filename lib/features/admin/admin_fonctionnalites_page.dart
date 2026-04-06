import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Fonctionnalités par entreprise — aligné `admin-features-screen.tsx` (web).
class AdminFonctionnalitesPage extends StatefulWidget {
  const AdminFonctionnalitesPage({super.key});

  @override
  State<AdminFonctionnalitesPage> createState() => _AdminFonctionnalitesPageState();
}

class _AdminFonctionnalitesPageState extends State<AdminFonctionnalitesPage> {
  final AdminRepository _repo = AdminRepository();
  late Future<List<AdminCompany>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.listCompanies();
  }

  void _reload() {
    setState(() {
      _future = _repo.listCompanies();
    });
  }

  Future<void> _updateCompany(
    String id, {
    bool? isActive,
    bool? aiPredictionsEnabled,
    bool? warehouseFeatureEnabled,
    bool? storeQuotaIncreaseEnabled,
    int? storeQuota,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.updateCompany(
        id,
        isActive: isActive,
        aiPredictionsEnabled: aiPredictionsEnabled,
        warehouseFeatureEnabled: warehouseFeatureEnabled,
        storeQuotaIncreaseEnabled: storeQuotaIncreaseEnabled,
        storeQuota: storeQuota,
      );
      if (!mounted) return;
      AppToast.success(context, 'Enregistré');
      _reload();
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commitQuota(AdminCompany c, String raw) async {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1) {
      AppToast.error(context, 'Quota invalide (entier ≥ 1).');
      return;
    }
    if (n > c.storeQuota && !c.storeQuotaIncreaseEnabled) {
      AppToast.error(
        context,
        "L'augmentation du quota est désactivée pour cette entreprise. Activez d'abord « Augmenter quota ».",
      );
      return;
    }
    if (n == c.storeQuota) return;
    await _updateCompany(c.id, storeQuota: n);
  }

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AdminPageHeader(
                    title: 'Fonctionnalités',
                    description:
                        'Activez ou désactivez des modules pour chaque entreprise (Magasin, prédictions IA, possibilité d’augmenter le quota de boutiques).',
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _busy ? null : _reload,
                  icon: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Rafraîchir',
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<AdminCompany>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return AdminCard(
                    padding: const EdgeInsets.all(24),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return AdminCard(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppErrorHandler.toUserMessage(snap.error, fallback: 'Erreur de chargement.'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final companies = snap.data ?? [];
                if (companies.isEmpty) {
                  return AdminCard(
                    padding: const EdgeInsets.all(24),
                    child: Text('Aucune entreprise.', style: AdminPalette.dataTableCell),
                  );
                }
                return AdminCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 920),
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 72,
                        columns: [
                          DataColumn(label: Text('Entreprise', style: AdminPalette.dataTableHeader)),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.home_work_rounded, size: 18, color: AdminPalette.subtitle),
                                const SizedBox(width: 6),
                                Text('Magasin', style: AdminPalette.dataTableHeader),
                              ],
                            ),
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.toggle_on_rounded, size: 18, color: AdminPalette.subtitle),
                                const SizedBox(width: 6),
                                Text('IA', style: AdminPalette.dataTableHeader),
                              ],
                            ),
                          ),
                          DataColumn(
                            label: Row(
                              children: [
                                Icon(Icons.storefront_rounded, size: 18, color: AdminPalette.subtitle),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Augmenter quota',
                                    style: AdminPalette.dataTableHeader,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataColumn(label: Text('Quota boutiques', style: AdminPalette.dataTableHeader)),
                        ],
                        rows: companies.map((c) {
                          return DataRow(
                            cells: [
                              DataCell(Text(c.name, style: AdminPalette.dataTableCell)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: c.warehouseFeatureEnabled,
                                      onChanged: _busy
                                          ? null
                                          : (v) => _updateCompany(c.id, warehouseFeatureEnabled: v),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.warehouseFeatureEnabled ? 'Activé' : 'Désactivé',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AdminPalette.subtitle,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: c.aiPredictionsEnabled,
                                      onChanged: _busy
                                          ? null
                                          : (v) => _updateCompany(c.id, aiPredictionsEnabled: v),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.aiPredictionsEnabled ? 'Activé' : 'Désactivé',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AdminPalette.subtitle,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: c.storeQuotaIncreaseEnabled,
                                      onChanged: _busy
                                          ? null
                                          : (v) => _updateCompany(c.id, storeQuotaIncreaseEnabled: v),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.storeQuotaIncreaseEnabled ? 'Autorisé' : 'Bloqué',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AdminPalette.subtitle,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 140,
                                  child: TextFormField(
                                    key: ValueKey('quota_${c.id}_${c.storeQuota}'),
                                    initialValue: '${c.storeQuota}',
                                    enabled: !_busy,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      suffixText: 'max.',
                                      suffixStyle: const TextStyle(fontSize: 11, color: AdminPalette.muted),
                                    ),
                                    onFieldSubmitted: (v) => _commitQuota(c, v),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
