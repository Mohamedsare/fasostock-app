import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/widgets/company_load_error_screen.dart';
import 'widgets/create_store_dialog.dart';
import 'widgets/edit_store_dialog.dart';

/// Page Boutiques — lecture depuis Drift (offline-first), sync en arrière-plan.
class StoresPage extends ConsumerStatefulWidget {
  const StoresPage({super.key});

  @override
  ConsumerState<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends ConsumerState<StoresPage> {
  bool _syncTriggeredForEmpty = false;
  bool _invoiceTablePosEnabled = false;
  String? _invoiceTableLoadedForCompanyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cid = context.read<CompanyProvider>().currentCompanyId;
    if (cid == null) {
      if (_invoiceTableLoadedForCompanyId != null) {
        setState(() {
          _invoiceTableLoadedForCompanyId = null;
          _invoiceTablePosEnabled = false;
        });
      }
      return;
    }
    if (cid == _invoiceTableLoadedForCompanyId) return;
    _invoiceTableLoadedForCompanyId = cid;
    final cached = SettingsRepository.peekInvoiceTablePosEnabled(cid);
    if (cached != null) {
      final showTable = cached;
      setState(() => _invoiceTablePosEnabled = showTable);
    }
    SettingsRepository().getInvoiceTablePosEnabled(cid).then((v) {
      if (!mounted) return;
      if (context.read<CompanyProvider>().currentCompanyId != cid) return;
      setState(() => _invoiceTablePosEnabled = v);
    });
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    if (auth.user != null && company.companies.isEmpty && !company.loading) {
      final userId = auth.user?.id;
      if (userId != null) company.loadCompanies(userId);
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: userId, companyId: company.currentCompanyId, storeId: company.currentStoreId);
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'stores_page',
          logContext: const {'op': 'pull_refresh'},
        );
      }
    }
    if (mounted) await company.refreshStores();
  }

  void _runSyncInBackground() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid == null) return;
    Future.microtask(() async {
      try {
        await ref.read(syncServiceV2Provider).sync(userId: uid, companyId: company.currentCompanyId, storeId: company.currentStoreId);
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'stores_page',
          logContext: const {'op': 'background_sync'},
        );
      }
      if (mounted) context.read<CompanyProvider>().refreshStores();
    });
  }

  Future<void> _applyStoreCreated(Store s) async {
    await ref.read(storesOfflineRepositoryProvider).upsertStore(s);
    if (!mounted) return;
    ref.invalidate(storesStreamProvider(s.companyId));
    _runSyncInBackground();
  }

  Future<void> _applyStoreUpdated(Store s) async {
    await ref.read(storesOfflineRepositoryProvider).upsertStore(s);
    if (!mounted) return;
    ref.invalidate(storesStreamProvider(s.companyId));
    _runSyncInBackground();
  }

  Future<void> _onCreated(Store? store) async {
    if (store != null) _applyStoreCreated(store);
    final company = context.read<CompanyProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    _runSyncInBackground();
    if (!mounted) return;
    if (userId != null) await company.refreshCompanies(userId);
    if (mounted) AppToast.success(context, 'Boutique créée');
  }

  Future<void> _onUpdated(Store? store) async {
    if (store != null) _applyStoreUpdated(store);
    _runSyncInBackground();
    if (mounted) AppToast.success(context, 'Boutique mise à jour');
  }

  void _openCreateDialog(String companyId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateStoreDialog(
        companyId: companyId,
        onSuccess: (Store? s) {
          Navigator.of(ctx).pop();
          _onCreated(s);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _openEditDialog(Store store) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditStoreDialog(
        store: store,
        onSuccess: (Store? s) {
          Navigator.of(ctx).pop();
          _onUpdated(s);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canAccessStores = permissions.hasPermission(Permissions.storesView) ||
        permissions.hasPermission(Permissions.storesCreate);
    if (permissions.hasLoaded && !canAccessStores) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boutiques')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text("Vous n'avez pas accès à cette page.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final currentCompany = company.currentCompany;
    final asyncStores = ref.watch(storesStreamProvider(companyId ?? ''));
    final stores = asyncStores.valueOrNull ?? [];
    final loading = asyncStores.isLoading;
    final error = asyncStores.hasError
        ? AppErrorHandler.toUserMessage(asyncStores.error)
        : null;
    final quota = currentCompany?.storeQuota ?? 1;
    final quotaIncreaseOk = currentCompany?.storeQuotaIncreaseEnabled ?? true;
    final atQuota = stores.length >= quota && quota > 0;
    final quotaIncreaseBlocked =
        atQuota && !quotaIncreaseOk && permissions.hasPermission(Permissions.storesCreate);
    final canCreate = companyId != null &&
        permissions.hasPermission(Permissions.storesCreate) &&
        (stores.isEmpty || stores.length < quota);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return CompanyLoadErrorScreen(
        message: company.loadError!,
        title: 'Boutiques',
      );
    }
    if (companyId == null) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Boutiques')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Boutiques',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Aucune entreprise. Contactez l’administrateur.'),
              ],
            ),
          ),
        ),
      );
    }

    if (stores.isEmpty && !loading && error == null && !_syncTriggeredForEmpty) {
      _syncTriggeredForEmpty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _refresh(); });
    }
    if (stores.isNotEmpty) _syncTriggeredForEmpty = false;

    final description = currentCompany != null
        ? '${currentCompany.name} — Quota : $quota boutique(s) · ${stores.length} créée(s)'
        : 'Sélectionnez une entreprise';

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
              _buildHeader(context, description, canCreate, companyId),
              const SizedBox(height: 24),
              if (quotaIncreaseBlocked) ...[
                _buildQuotaBlockedBanner(context, quota),
                const SizedBox(height: 16),
              ],
              if (error != null) ...[
                _buildErrorCard(context, error),
                const SizedBox(height: 24),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (stores.isEmpty)
                _buildEmptyState(context, canCreate, companyId)
              else
                _buildStoresGrid(context, isWide, stores, permissions),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate && stores.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openCreateDialog(companyId),
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildQuotaBlockedBanner(BuildContext context, int quota) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quota de boutiques atteint ($quota). L’augmentation du nombre de boutiques autorisées '
                'n’est pas disponible pour votre offre. Contactez l’administrateur de la plateforme.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF78350F),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String description,
    bool canCreate,
    String companyId,
  ) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Boutiques',
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
              if (canCreate) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(companyId),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouvelle boutique'),
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
                      'Boutiques',
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
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(companyId),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouvelle boutique'),
                ),
            ],
          );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool canCreate, String companyId) {
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
                Icons.store_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune boutique',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              canCreate
                  ? 'Créez votre première boutique pour gérer le stock et les ventes (POS).'
                  : 'Quota atteint. Contactez l’administrateur pour augmenter le nombre de boutiques.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (canCreate) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(companyId),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer une boutique'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoresGrid(BuildContext context, bool isWide, List<Store> stores, PermissionsProvider permissions) {
    final canPosQuick = permissions.hasPermission(Permissions.salesCreate);
    final canPosInvoice = permissions.hasPermission(Permissions.salesInvoiceA4) ||
        permissions.hasPermission(Permissions.salesCreate);
    final canFactureTable = _invoiceTablePosEnabled &&
        permissions.hasPermission(Permissions.salesInvoiceA4Table) &&
        canPosInvoice;
    final crossCount = isWide ? 3 : (MediaQuery.sizeOf(context).width > 600 ? 2 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = crossCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 16 * (crossCount - 1)) / crossCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: stores.map((store) {
            return SizedBox(
              width: cardWidth,
              child: _StoreCard(
                store: store,
                onEdit: () => _openEditDialog(store),
                onPosQuick: canPosQuick ? () => context.go(AppRoutes.posQuick(store.id)) : null,
                onPosInvoice: canPosInvoice ? () => context.go(AppRoutes.pos(store.id)) : null,
                onPosInvoiceTable:
                    canFactureTable ? () => context.go(AppRoutes.factureTab(store.id)) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.store,
    required this.onEdit,
    this.onPosQuick,
    this.onPosInvoice,
    this.onPosInvoiceTable,
  });

  final Store store;
  final VoidCallback onEdit;
  final VoidCallback? onPosQuick;
  final VoidCallback? onPosInvoice;
  final VoidCallback? onPosInvoiceTable;

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: store.logoUrl != null && store.logoUrl!.isNotEmpty
                    ? Image.network(store.logoUrl!, fit: BoxFit.cover)
                    : Icon(Icons.store_rounded, size: 28, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (store.isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Principale',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (store.code != null && store.code!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        store.code!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (store.address != null && store.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              store.address!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (store.phone != null && store.phone!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              store.phone!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (store.email != null && store.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              store.email!,
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
                    if (store.description != null && store.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        store.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight < double.infinity;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (hasBoundedHeight)
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildContent(context, theme),
                  ),
                )
              else
                _buildContent(context, theme),
              const Divider(height: 1),
              IntrinsicHeight(
                child: Row(
                  children: [
                    if (onPosQuick != null) ...[
                      Expanded(
                        child: InkWell(
                          onTap: onPosQuick,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(height: 4),
                                Text(
                                  'Caisse rapide',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: theme.dividerColor),
                    ],
                    if (onPosInvoice != null) ...[
                      Expanded(
                        child: InkWell(
                          onTap: onPosInvoice,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_rounded, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(height: 4),
                                Text(
                                  'Facture A4',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: theme.dividerColor),
                    ],
                    if (onPosInvoiceTable != null) ...[
                      Expanded(
                        child: InkWell(
                          onTap: onPosInvoiceTable,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.table_rows_rounded, size: 20, color: theme.colorScheme.primary),
                                const SizedBox(height: 4),
                                Text(
                                  'Facture tab.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: theme.dividerColor),
                    ],
                    Expanded(
                      child: InkWell(
                        onTap: onEdit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 4),
                              Text(
                                'Modifier',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
