import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/suppliers_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import 'widgets/create_supplier_dialog.dart';
import 'widgets/edit_supplier_dialog.dart';

const int _suppliersPageSize = 20;

/// Page Fournisseurs — lecture 100 % Drift, sync v2 en arrière-plan.
class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  bool _syncTriggeredOnce = false;
  int _currentSuppliersPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _refreshSync() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(
          userId: uid,
          companyId: company.currentCompanyId,
          storeId: null,
        );
      } catch (_) {}
    }
  }

  Future<void> _applySupplierUpdated(Supplier s) async {
    await ref.read(suppliersOfflineRepositoryProvider).upsertSupplier(s);
    if (!mounted) return;
    ref.invalidate(suppliersStreamProvider(s.companyId));
    Future.microtask(() => _refreshSync());
  }

  void _openEditDialog(Supplier supplier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditSupplierDialog(
        supplier: supplier,
        onSuccess: (Supplier? updated) {
          Navigator.of(ctx).pop();
          if (updated != null) _applySupplierUpdated(updated);
          if (mounted) AppToast.success(context, 'Fournisseur mis à jour');
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fournisseur'),
        content: Text(
          'Supprimer « ${supplier.name} » ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final repo = SuppliersRepository();
      await repo.delete(supplier.id);
      if (!mounted) return;
      await ref.read(suppliersOfflineRepositoryProvider).deleteSupplier(supplier.id);
      ref.invalidate(suppliersStreamProvider(supplier.companyId));
      if (mounted) AppToast.success(context, 'Fournisseur supprimé');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canAccessSuppliers = permissions.hasPermission(Permissions.suppliersView) ||
        permissions.hasPermission(Permissions.suppliersManage);
    if (permissions.hasLoaded && !canAccessSuppliers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fournisseurs')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                "Vous n'avez pas accès à cette page.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final suppliersAsync = ref.watch(suppliersStreamProvider(companyId ?? ''));
    final suppliers = suppliersAsync.value ?? [];
    final loading = suppliersAsync.isLoading;
    final error = suppliersAsync.hasError ? AppErrorHandler.toUserMessage(suppliersAsync.error!) : null;
    final totalCount = suppliers.length;
    final pageCount = totalCount == 0 ? 0 : ((totalCount - 1) ~/ _suppliersPageSize) + 1;
    final effectivePage = pageCount > 0 && _currentSuppliersPage >= pageCount ? pageCount - 1 : _currentSuppliersPage;
    if (effectivePage != _currentSuppliersPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentSuppliersPage = effectivePage);
      });
    }
    final paginatedSuppliers = suppliers.skip(effectivePage * _suppliersPageSize).take(_suppliersPageSize).toList();

    if (!_syncTriggeredOnce && companyId != null && suppliers.isEmpty && !suppliersAsync.isLoading) {
      _syncTriggeredOnce = true;
      Future.microtask(() => _refreshSync());
    }

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Fournisseurs')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(company.loadError!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      );
    }
    if (companyId == null) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Fournisseurs')),
        body: const Center(child: Text('Aucune entreprise. Contactez l\'administrateur.')),
      );
    }

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Fournisseurs')),
      body: RefreshIndicator(
        onRefresh: _refreshSync,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 20,
            vertical: isWide ? 28 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isWide),
              const SizedBox(height: 24),
              if (error != null) ...[
                _buildErrorCard(context, error),
                const SizedBox(height: 24),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (suppliers.isEmpty)
                _buildEmptyState(context)
              else ...[
                if (isWide)
                  _buildTable(context, paginatedSuppliers, context.watch<PermissionsProvider>().hasPermission(Permissions.suppliersManage))
                else
                  _buildGrid(context, paginatedSuppliers, context.watch<PermissionsProvider>().hasPermission(Permissions.suppliersManage)),
                if (pageCount > 1) ...[
                  const SizedBox(height: 16),
                  _buildSuppliersPagination(context, totalCount, pageCount, effectivePage),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applySupplierCreated(Supplier s) async {
    await ref.read(suppliersOfflineRepositoryProvider).upsertSupplier(s);
    if (!mounted) return;
    ref.invalidate(suppliersStreamProvider(s.companyId));
    Future.microtask(() => _refreshSync());
  }

  void _openCreateDialog(String companyId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateSupplierDialog(
        companyId: companyId,
        onSuccess: (Supplier? created) {
          Navigator.of(ctx).pop();
          if (created != null) _applySupplierCreated(created);
          if (mounted) AppToast.success(context, 'Fournisseur créé');
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final permissions = context.watch<PermissionsProvider>();
    final companyId = context.watch<CompanyProvider>().currentCompanyId;
    final narrow = MediaQuery.sizeOf(context).width < 560;
    const description = 'Gérer vos fournisseurs';
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fournisseurs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (companyId != null && permissions.hasPermission(Permissions.suppliersManage)) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(companyId),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouveau fournisseur'),
                ),
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fournisseurs',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (companyId != null && permissions.hasPermission(Permissions.suppliersManage))
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(companyId),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouveau fournisseur'),
                ),
            ],
          );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide — aligné web : "Aucun fournisseur."
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_center_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun fournisseur.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<Supplier> suppliers, bool canManage) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          columns: [
            const DataColumn(label: Text('Nom')),
            const DataColumn(label: Text('Contact')),
            const DataColumn(label: Text('Téléphone')),
            const DataColumn(label: Text('Email')),
            if (canManage) const DataColumn(label: Text('Actions')),
          ],
          rows: suppliers.map((s) => DataRow(
            cells: [
              DataCell(Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              DataCell(Text(s.contact ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DataCell(Text(s.phone ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DataCell(Text(s.email ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (canManage)
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openEditDialog(s),
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                      onPressed: () => _deleteSupplier(s),
                      tooltip: 'Supprimer',
                    ),
                  ],
                )),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Supplier> suppliers, bool canManage) {
    final crossCount = MediaQuery.sizeOf(context).width > 600 ? 2 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = crossCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 16 * (crossCount - 1)) / crossCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: suppliers.map((s) {
            return SizedBox(
              width: cardWidth,
              child: _SupplierCard(
                supplier: s,
                canManage: canManage,
                onEdit: () => _openEditDialog(s),
                onDelete: () => _deleteSupplier(s),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSuppliersPagination(BuildContext context, int totalCount, int pageCount, int currentPageIndex) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _suppliersPageSize + 1;
    final end = (currentPageIndex + 1) * _suppliersPageSize;
    final endClamped = end > totalCount ? totalCount : end;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isNarrow)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$start – $endClamped sur $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            IconButton.filled(
              onPressed: currentPageIndex > 0 ? () => setState(() => _currentSuppliersPage--) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex > 0 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex > 0 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page ${currentPageIndex + 1} / $pageCount',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: currentPageIndex < pageCount - 1 ? () => setState(() => _currentSuppliersPage++) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            if (isNarrow) ...[
              const SizedBox(width: 12),
              Text(
                '$start – $endClamped / $totalCount',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  final Supplier supplier;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business_center_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    supplier.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (supplier.contact != null && supplier.contact!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      supplier.contact!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      supplier.phone!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (supplier.email != null && supplier.email!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      supplier.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (supplier.address != null && supplier.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      supplier.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (canManage && (onEdit != null || onDelete != null)) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                      label: Text('Supprimer', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
