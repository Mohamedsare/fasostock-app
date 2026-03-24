import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/stock_transfer.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/transfers_repository.dart';
import '../../../providers/auth_provider.dart';

/// Dialog détail d’un transfert : infos + actions Expédier / Réceptionner / Annuler.
class TransferDetailDialog extends StatefulWidget {
  const TransferDetailDialog({
    super.key,
    required this.transferId,
    required this.stores,
    required this.storeName,
    required this.onActionDone,
    this.initialTransfer,
    this.onRemovePendingLocal,
  });

  final String transferId;
  final List<Store> stores;
  final String Function(String? storeId) storeName;
  final VoidCallback onActionDone;

  /// Données déjà en mémoire (liste) : affichage immédiat sans chargement.
  final StockTransfer? initialTransfer;

  /// Brouillon non synchronisé (`pending:…`) : suppression locale + retrait de la file de sync.
  final Future<void> Function(String pendingTransferId)? onRemovePendingLocal;

  @override
  State<TransferDetailDialog> createState() => _TransferDetailDialogState();
}

class _TransferDetailDialogState extends State<TransferDetailDialog> {
  final TransfersRepository _repo = TransfersRepository();

  StockTransfer? _transfer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransfer != null) {
      _transfer = widget.initialTransfer;
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await _repo.get(widget.transferId);
      if (mounted) {
        setState(() {
          _transfer = t;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(d);
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  Future<void> _ship() async {
    final t = _transfer;
    if (t == null) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      AppToast.info(context, 'Session expirée. Reconnectez-vous.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expédier ce transfert ?'),
        content: const Text(
          'Le stock de la boutique d\'origine sera décrémenté. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Expédier'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.ship(t.id, userId);
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'Transfert expédié');
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onActionDone(),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _receive() async {
    final t = _transfer;
    if (t == null) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      AppToast.info(context, 'Session expirée. Reconnectez-vous.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réceptionner ce transfert ?'),
        content: const Text(
          'Le stock de la boutique de destination sera incrémenté.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Réceptionner'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.receive(t.id, userId);
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'Transfert réceptionné');
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onActionDone(),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _cancel() async {
    final t = _transfer;
    if (t == null) return;
    final isPendingLocal = t.id.startsWith('pending:');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPendingLocal
              ? 'Supprimer ce brouillon ?'
              : 'Annuler ce transfert ?',
        ),
        content: Text(
          isPendingLocal
              ? 'Ce transfert n\'a pas encore été envoyé au serveur. Il sera définitivement supprimé.'
              : 'Le transfert sera marqué comme annulé. Aucun stock ne sera modifié.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(isPendingLocal ? 'Supprimer' : 'Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      if (isPendingLocal) {
        if (widget.onRemovePendingLocal == null) {
          if (mounted)
            AppToast.error(context, 'Suppression impossible depuis cet écran.');
          return;
        }
        await widget.onRemovePendingLocal!(t.id);
        if (mounted) {
          Navigator.of(context).pop();
          AppToast.success(context, 'Brouillon supprimé');
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onActionDone(),
          );
        }
        return;
      }
      await _repo.cancel(t.id);
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'Transfert annulé');
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onActionDone(),
        );
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  static const Map<TransferStatus, String> _statusLabels = {
    TransferStatus.draft: 'Brouillon',
    TransferStatus.pending: 'En attente',
    TransferStatus.approved: 'Approuvé',
    TransferStatus.shipped: 'Expédié',
    TransferStatus.received: 'Réceptionné',
    TransferStatus.rejected: 'Rejeté',
    TransferStatus.cancelled: 'Annulé',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _transfer;

    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = screenSize.height * 0.7;
    final contentWidth = screenSize.width < 400
        ? null
        : (screenSize.width >= 600 ? 500.0 : 400.0);

    final Widget body = _loading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Réessayer'),
              ),
            ],
          )
        : t == null
        ? const Text('Transfert introuvable.')
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      _statusLabels[t.status] ?? t.status.value,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                  Text(
                    '${widget.storeName(t.fromStoreId)} → ${widget.storeName(t.toStoreId)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Créé le ${_formatDate(t.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (t.shippedAt != null)
                Text(
                  'Expédié le ${_formatDate(t.shippedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (t.receivedAt != null)
                Text(
                  'Réceptionné le ${_formatDate(t.receivedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (t.items != null && t.items!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Lignes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...t.items!.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName ?? item.productId,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${item.quantityRequested} demandé',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (item.quantityShipped > 0)
                          Text(
                            ' · ${item.quantityShipped} expédié',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (item.quantityReceived > 0)
                          Text(
                            ' · ${item.quantityReceived} reçu',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (t.status == TransferStatus.draft ||
                      t.status == TransferStatus.approved)
                    FilledButton.icon(
                      onPressed: _ship,
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: const Text('Expédier'),
                    ),
                  if (t.status == TransferStatus.shipped)
                    FilledButton.icon(
                      onPressed: _receive,
                      icon: const Icon(Icons.inventory_2_rounded, size: 18),
                      label: const Text('Réceptionner'),
                    ),
                  if (t.status == TransferStatus.draft ||
                      t.status == TransferStatus.pending)
                    OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        t.id.startsWith('pending:')
                            ? 'Supprimer le brouillon'
                            : 'Annuler le transfert',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ],
          );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded),
          SizedBox(width: 10),
          Text('Détail transfert'),
        ],
      ),
      content: SizedBox(
        width: contentWidth ?? screenSize.width,
        height: maxHeight,
        child: SingleChildScrollView(child: body),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
