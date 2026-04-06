import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/local/drift/app_database.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customers_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import 'utils/customers_csv.dart';
import '../../../shared/utils/share_csv.dart';
import 'widgets/create_customer_dialog.dart';
import 'widgets/edit_customer_dialog.dart';

const int _customersPageSize = 20;

/// Labels type client.
const Map<CustomerType, String> _typeLabels = {
  CustomerType.individual: 'Particulier',
  CustomerType.company: 'Entreprise',
};

/// Page Clients — lecture depuis Drift (offline-first), sync en arrière-plan.
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final CustomersRepository _repo = CustomersRepository();
  final TextEditingController _searchController = TextEditingController();
  bool _syncTriggeredForEmpty = false;
  int _currentCustomersPage = 0;
  String _lastCustomersFilterKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    if (userId != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: userId, companyId: companyId, storeId: storeId);
      } catch (_) {}
    }
  }

  void _runSyncInBackground() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid == null) return;
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    Future.microtask(() async {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: uid, companyId: companyId, storeId: storeId);
      } catch (_) {}
    });
  }

  void _exportCsv(List<Customer> list) {
    if (list.isEmpty) return;
    final csv = customersToCsv(list);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final filename = 'clients-$date.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    saveCsvFile(filename: filename, bytes: bytes).then((saved) {
      if (!mounted) return;
      if (saved) AppToast.success(context, 'CSV enregistré');
    });
  }

  List<Customer> _filtered(List<Customer> customers) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.phone?.contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.address?.toLowerCase().contains(q) ?? false) ||
          (c.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _applyCustomerCreated(Customer c) async {
    await ref.read(customersOfflineRepositoryProvider).upsertCustomer(c);
    if (!mounted) return;
    ref.invalidate(customersStreamProvider(c.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyCustomerUpdated(Customer c) async {
    await ref.read(customersOfflineRepositoryProvider).upsertCustomer(c);
    if (!mounted) return;
    ref.invalidate(customersStreamProvider(c.companyId));
    _runSyncInBackground();
  }

  void _openCreateDialog(String companyId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateCustomerDialog(
        companyId: companyId,
        onSuccess: (Customer? created) {
          Navigator.of(ctx).pop();
          if (created != null) _applyCustomerCreated(created);
          _runSyncInBackground();
          if (mounted) AppToast.success(context, 'Client créé');
        },
        onCancel: () => Navigator.of(ctx).pop(),
        onOfflineSuccess: () {
          Navigator.of(ctx).pop();
          _runSyncInBackground();
        },
        onOfflineCreate: (input) async {
          final localId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
          final now = DateTime.now().toUtc().toIso8601String();
          final db = ref.read(appDatabaseProvider);
          await db.enqueuePendingAction(
            'customer',
            jsonEncode({
              'local_id': localId,
              'company_id': input.companyId,
              'name': input.name,
              'type': input.type.value,
              'phone': input.phone,
              'email': input.email,
              'address': input.address,
              'notes': input.notes,
            }),
          );
          await db.upsertLocalCustomers([
            LocalCustomersCompanion.insert(
              id: 'pending:$localId',
              companyId: input.companyId,
              name: input.name,
              type: Value(input.type.value),
              phone: Value(input.phone),
              email: Value(input.email),
              address: Value(input.address),
              notes: Value(input.notes),
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        },
      ),
    );
  }

  void _openEditDialog(Customer customer) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditCustomerDialog(
        customer: customer,
        onSuccess: (Customer? updated) {
          Navigator.of(ctx).pop();
          if (updated != null) _applyCustomerUpdated(updated);
          _runSyncInBackground();
          if (mounted) AppToast.success(context, 'Client mis à jour');
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _confirmDelete(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text(
          'Cette action est irréversible. Les ventes liées à ce client ne seront pas supprimées (le client sera simplement retiré).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final companyId = customer.companyId;
    try {
      await _repo.delete(customer.id);
      if (!mounted) return;
      await ref.read(appDatabaseProvider).deleteLocalCustomer(customer.id);
      if (!mounted) return;
      ref.invalidate(customersStreamProvider(companyId));
      _runSyncInBackground();
      if (mounted) AppToast.success(context, 'Client supprimé');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>();
    final permissions = context.watch<PermissionsProvider>();
    final companyId = company.currentCompanyId;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final asyncCustomers = ref.watch(customersStreamProvider(companyId ?? ''));
    final customers = asyncCustomers.valueOrNull ?? [];
    final loading = asyncCustomers.isLoading;
    final error = asyncCustomers.hasError && asyncCustomers.error != null
        ? AppErrorHandler.toUserMessage(asyncCustomers.error)
        : null;

    if (!permissions.hasLoaded) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Clients')) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final canAccessCustomers = permissions.hasPermission(Permissions.customersView) ||
        permissions.hasPermission(Permissions.customersManage);
    if (!canAccessCustomers) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Clients')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Clients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
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
        ),
      );
    }

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Clients')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Clients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
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
        appBar: isWide ? AppBar(title: const Text('Clients')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Clients',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Aucune entreprise. Contactez l\'administrateur.'),
              ],
            ),
          ),
        ),
      );
    }

    if (customers.isEmpty && !loading && error == null && !_syncTriggeredForEmpty) {
      _syncTriggeredForEmpty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSyncInBackground();
      });
    }
    if (customers.isNotEmpty) _syncTriggeredForEmpty = false;

    final canCreate = permissions.hasPermission(Permissions.customersManage);
    final canDeleteCustomer = permissions.hasPermission(Permissions.customersManage);
    const description = 'Gérer vos clients (particuliers et entreprises)';
    final filtered = _filtered(customers);
    final totalCount = filtered.length;
    final pageCount = totalCount == 0 ? 0 : ((totalCount - 1) ~/ _customersPageSize) + 1;
    final filterKey = _searchController.text;
    if (filterKey != _lastCustomersFilterKey) {
      _lastCustomersFilterKey = filterKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentCustomersPage = 0);
      });
    }
    final effectivePage = pageCount > 0 && _currentCustomersPage >= pageCount ? pageCount - 1 : _currentCustomersPage;
    if (effectivePage != _currentCustomersPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentCustomersPage = effectivePage);
      });
    }
    final paginatedList = filtered.skip(effectivePage * _customersPageSize).take(_customersPageSize).toList();

    return Scaffold(
      appBar: null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 20,
            vertical: isWide ? 28 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isWide, description, canCreate, companyId, filtered),
              const SizedBox(height: 24),
              if (error != null) ...[
                _buildErrorCard(context, error),
                const SizedBox(height: 24),
              ],
              _buildSearch(context),
              const SizedBox(height: 24),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                _buildEmptyState(context, canCreate, companyId)
              else ...[
                if (isWide)
                  _buildTable(context, paginatedList, canDeleteCustomer)
                else
                  _buildGrid(context, paginatedList, canDeleteCustomer),
                if (pageCount > 1) ...[
                  const SizedBox(height: 16),
                  _buildCustomersPagination(context, totalCount, pageCount, effectivePage),
                ],
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate && customers.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openCreateDialog(companyId),
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              elevation: 4,
              highlightElevation: 8,
              tooltip: 'Nouveau client',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isWide,
    String description,
    bool canCreate,
    String companyId,
    List<Customer> filtered,
  ) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Clients',
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
              if (canCreate || filtered.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filtered.isNotEmpty)
                      IconButton.filled(
                        onPressed: () => _exportCsv(filtered),
                        icon: const Icon(Icons.download_rounded, size: 24),
                        tooltip: 'Enregistrer CSV',
                      ),
                    if (filtered.isNotEmpty && canCreate) const SizedBox(width: 8),
                    if (canCreate)
                      IconButton.filled(
                        onPressed: () => _openCreateDialog(companyId),
                        icon: const Icon(Icons.add_rounded, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Nouveau client',
                      ),
                  ],
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
                      'Clients',
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
              if (filtered.isNotEmpty)
                IconButton.filled(
                  onPressed: () => _exportCsv(filtered),
                  icon: const Icon(Icons.download_rounded, size: 24),
                  tooltip: 'Enregistrer CSV',
                ),
              if (filtered.isNotEmpty && canCreate) const SizedBox(width: 8),
              if (canCreate)
                IconButton.filled(
                  onPressed: () => _openCreateDialog(companyId),
                  icon: const Icon(Icons.add_rounded, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Nouveau client',
                ),
            ],
          );
  }

  Widget _buildErrorCard(BuildContext context, String? error) {
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
                error ?? '',
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

  Widget _buildSearch(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Rechercher par nom, téléphone, email...',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool canCreate, String companyId) {
    final theme = Theme.of(context);
    final hasSearch = _searchController.text.trim().isNotEmpty;
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
                Icons.person_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasSearch ? 'Aucun résultat' : 'Aucun client',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Aucun client ne correspond à la recherche.'
                  : 'Aucun client. Créez-en un pour commencer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (canCreate && !hasSearch) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(companyId),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un client'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<Customer> filtered, bool canDeleteCustomer) {
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
          columns: const [
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Tél.')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Adresse')),
            DataColumn(label: Text('Notes')),
            DataColumn(label: Text('Actions')),
          ],
          rows: filtered.map((c) {
            return DataRow(
              cells: [
                DataCell(Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(_typeLabels[c.type] ?? c.type.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(c.phone ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(c.email ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(c.address ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis))),
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(c.notes ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _openEditDialog(c), tooltip: 'Modifier'),
                    if (canDeleteCustomer)
                      IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error), onPressed: () => _confirmDelete(c), tooltip: 'Supprimer'),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Customer> filtered, bool canDeleteCustomer) {
    final crossCount = MediaQuery.sizeOf(context).width > 600 ? 2 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = crossCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 16 * (crossCount - 1)) / crossCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: filtered.map((c) {
            return SizedBox(
              width: cardWidth,
              child: _CustomerCard(
                customer: c,
                typeLabel: _typeLabels[c.type] ?? c.type.name,
                onEdit: () => _openEditDialog(c),
                onDelete: canDeleteCustomer ? () => _confirmDelete(c) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCustomersPagination(BuildContext context, int totalCount, int pageCount, int currentPageIndex) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _customersPageSize + 1;
    final end = (currentPageIndex + 1) * _customersPageSize;
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
              onPressed: currentPageIndex > 0 ? () => setState(() => _currentCustomersPage--) : null,
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
              onPressed: currentPageIndex < pageCount - 1 ? () => setState(() => _currentCustomersPage++) : null,
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.typeLabel,
    required this.onEdit,
    this.onDelete,
  });

  final Customer customer;
  final String typeLabel;
  final VoidCallback onEdit;
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        customer.type == CustomerType.company
                            ? Icons.business_rounded
                            : Icons.person_rounded,
                        size: 24,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.phone!,
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
                if (customer.email != null && customer.email!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.email!,
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
                if (customer.address != null && customer.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer.address!,
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
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Modifier',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                Container(width: 1, color: theme.dividerColor),
                Expanded(
                  child: InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
