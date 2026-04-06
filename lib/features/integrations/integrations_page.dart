import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/permissions_provider.dart';

/// Page Intégrations — clés API et webhooks (owner uniquement).
class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  final IntegrationsRepository _repo = IntegrationsRepository();
  List<ApiKeyInfo> _keys = [];
  List<WebhookEndpointInfo> _webhooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    setState(() => _loading = true);
    try {
      final keys = await _repo.listApiKeys(companyId);
      final webhooks = await _repo.listWebhooks(companyId);
      if (mounted) {
        setState(() {
        _keys = keys;
        _webhooks = webhooks;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) AppToast.error(context, AppErrorHandler.toUserMessage(e));
    }
  }

  Future<void> _createKey() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Nouvelle clé API'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Nom (ex: Mon intégration)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, c.text.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Créer')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      final result = await _repo.createApiKey(companyId, name);
      if (!mounted) return;
      final keyRaw = result['key_raw'] as String?;
      if (keyRaw != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clé créée'),
            content: SelectableText(
              'Copiez cette clé maintenant. Elle ne sera plus affichée.\n\n$keyRaw',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('J\'ai copié'),
              ),
            ],
          ),
        );
      }
      _load();
      if (mounted) AppToast.success(context, 'Clé API créée');
    } catch (e) {
      if (mounted) AppToast.error(context, AppErrorHandler.toUserMessage(e));
    }
  }

  Future<void> _revokeKey(ApiKeyInfo key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Révoquer la clé ?'),
        content: Text('La clé "${key.name}" (${key.keyPrefix}...) ne fonctionnera plus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('Révoquer')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteApiKey(key.id);
      if (mounted) {
        AppToast.success(context, 'Clé révoquée');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, AppErrorHandler.toUserMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    context.watch<CompanyProvider>();
    if (!permissions.isOwner) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Intégrations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text('Réservé au propriétaire de l\'entreprise.'),
              ],
            ),
          ),
        ),
      );
    }
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Intégrations',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Clés API, webhooks et connexions externes.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              'Clés API',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Utilisez une clé API pour connecter des applications externes (ex. logiciel de caisse, site web).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _createKey,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Créer une clé API'),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_keys.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucune clé. Créez-en une pour accéder à l\'API.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ..._keys.map((k) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(k.name),
                      subtitle: Text('${k.keyPrefix}... • Créée le ${k.createdAt.day.toString().padLeft(2, '0')}/${k.createdAt.month.toString().padLeft(2, '0')}/${k.createdAt.year}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _revokeKey(k),
                        tooltip: 'Révoquer',
                      ),
                    ),
                  )),
            const SizedBox(height: 32),
            Text(
              'Webhooks',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Configurez des URLs pour recevoir les événements (ventes, stock…).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_webhooks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucun webhook. L\'ajout d\'URLs sera disponible dans une prochaine version.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ..._webhooks.map((w) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(w.isActive ? Icons.link_rounded : Icons.link_off_rounded, color: theme.colorScheme.onSurfaceVariant),
                      title: Text(w.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        w.events.isEmpty ? 'Aucun événement' : w.events.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
