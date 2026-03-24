import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/permissions_provider.dart';

/// Page Journal d'audit — liste des actions (produits, ventes, paramètres, etc.) pour l'entreprise.
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final AuditRepository _repo = AuditRepository();
  final List<AuditLogEntry> _entries = [];
  bool _loading = true;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  String? _filterAction;
  String? _filterEntityType;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool reset = true}) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) {
      setState(() {
        _loading = false;
        _error = 'Aucune entreprise sélectionnée';
      });
      return;
    }
    if (reset) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _entries.clear();
    });
    try {
      final from = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final to = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      final list = await _repo.list(
        companyId,
        action: _filterAction,
        entityType: _filterEntityType,
        fromDate: from,
        toDate: to,
        limit: _pageSize,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _entries.addAll(list);
          _offset += list.length;
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

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canView = permissions.hasPermission(Permissions.auditView) || permissions.isOwner;
    if (!permissions.hasLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journal d\'audit')),
        body: const Center(
          child: Text('Vous n\'avez pas accès au journal d\'audit.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filtres',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(reset: true),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fromDate != null || _toDate != null || _filterAction != null || _filterEntityType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_fromDate != null)
                    Chip(
                      label: Text('Du ${DateFormat('dd/MM/yyyy').format(_fromDate!)}'),
                      onDeleted: () => setState(() => _fromDate = null),
                    ),
                  if (_toDate != null)
                    Chip(
                      label: Text('Au ${DateFormat('dd/MM/yyyy').format(_toDate!)}'),
                      onDeleted: () => setState(() => _toDate = null),
                    ),
                  if (_filterAction != null && _filterAction!.isNotEmpty)
                    Chip(
                      label: Text('Action: $_filterAction'),
                      onDeleted: () => setState(() => _filterAction = null),
                    ),
                  if (_filterEntityType != null && _filterEntityType!.isNotEmpty)
                    Chip(
                      label: Text('Type: $_filterEntityType'),
                      onDeleted: () => setState(() => _filterEntityType = null),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _load(reset: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _loading && _entries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? Center(
                            child: Text(
                              'Aucune entrée dans le journal.',
                              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _entries.length + (_loading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _entries.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final e = _entries[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Icon(_iconFor(e.entityType), color: theme.colorScheme.onPrimaryContainer, size: 20),
                                    ),
                                    title: Text(
                                      _labelForAction(e.action),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${e.entityType} • ${dateFormat.format(e.createdAt)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    isThreeLine: true,
                                    onTap: () => _showDetail(context, e),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String entityType) {
    switch (entityType) {
      case 'product':
        return Icons.inventory_2_rounded;
      case 'sale':
        return Icons.shopping_cart_rounded;
      case 'customer':
        return Icons.person_rounded;
      case 'store':
        return Icons.store_rounded;
      case 'user':
        return Icons.people_rounded;
      case 'company':
        return Icons.business_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _labelForAction(String action) {
    if (action.contains('.')) {
      final parts = action.split('.');
      final verb = parts.length > 1 ? parts[0] : 'action';
      final entity = parts.length > 1 ? parts[1] : action;
      final v = verb == 'create' ? 'Création' : verb == 'update' ? 'Modification' : verb == 'delete' ? 'Suppression' : verb == 'login' ? 'Connexion' : verb;
      return '$v • $entity';
    }
    return action;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AuditFilterSheet(
        initialAction: _filterAction,
        initialEntityType: _filterEntityType,
        initialFrom: _fromDate,
        initialTo: _toDate,
        onApply: (action, entityType, from, to) {
          setState(() {
            _filterAction = action;
            _filterEntityType = entityType;
            _fromDate = from;
            _toDate = to;
          });
          _load(reset: true);
        },
      ),
    );
  }

  void _showDetail(BuildContext context, AuditLogEntry e) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Détail', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailRow('Action', e.action),
              _DetailRow('Type', e.entityType),
              _DetailRow('Date', dateFormat.format(e.createdAt)),
              if (e.entityId != null) _DetailRow('ID entité', e.entityId!),
              if (e.oldData != null && e.oldData!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Anciennes valeurs', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(e.oldData.toString(), style: Theme.of(ctx).textTheme.bodySmall),
              ],
              if (e.newData != null && e.newData!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Nouvelles valeurs', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(e.newData.toString(), style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditFilterSheet extends StatefulWidget {
  const _AuditFilterSheet({
    this.initialAction,
    this.initialEntityType,
    this.initialFrom,
    this.initialTo,
    required this.onApply,
  });

  final String? initialAction;
  final String? initialEntityType;
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final void Function(String? action, String? entityType, DateTime? from, DateTime? to) onApply;

  @override
  State<_AuditFilterSheet> createState() => _AuditFilterSheetState();
}

class _AuditFilterSheetState extends State<_AuditFilterSheet> {
  late final TextEditingController _actionController;
  late final TextEditingController _entityController;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _actionController = TextEditingController(text: widget.initialAction ?? '');
    _entityController = TextEditingController(text: widget.initialEntityType ?? '');
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  @override
  void dispose() {
    _actionController.dispose();
    _entityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _actionController,
                decoration: const InputDecoration(labelText: 'Action (ex: product.create)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _entityController,
                decoration: const InputDecoration(labelText: 'Type (ex: product, sale)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_from != null ? 'Du ${DateFormat('dd/MM/yyyy').format(_from!)}' : 'Date de début'),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setState(() => _from = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_to != null ? 'Au ${DateFormat('dd/MM/yyyy').format(_to!)}' : 'Date de fin'),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: _from ?? DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setState(() => _to = d);
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _actionController.clear();
                        _entityController.clear();
                        setState(() => _from = _to = null);
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final action = _actionController.text.trim().isEmpty ? null : _actionController.text.trim();
                        final entityType = _entityController.text.trim().isEmpty ? null : _entityController.text.trim();
                        Navigator.pop(context);
                        widget.onApply(action, entityType, _from, _to);
                      },
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
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
          SizedBox(width: 120, child: Text('$label :', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
