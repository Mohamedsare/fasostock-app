import 'package:flutter/material.dart';

import '../../core/errors/app_error_handler.dart';

/// Design system léger pour l’écran Magasin (dépôt) — cohérent, sans surcharger le thème global.
abstract final class WarehouseUi {
  static const double radiusLg = 16;
  static const double radiusMd = 12;
  static const double radiusSm = 10;

  /// Couleurs sémantiques (hors Material defaults) — usage restreint à ce module.
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentEmerald = Color(0xFF059669);
  static const Color accentRose = Color(0xFFDB2777);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentViolet = Color(0xFF7C3AED);

  static EdgeInsets pagePaddingOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = 20.0;
    final v = w < 400 ? 12.0 : 16.0;
    return EdgeInsets.fromLTRB(h, v, h, v);
  }

  /// Journalisation structurée — préfixe `Warehouse.<op>` pour filtrer les logs.
  static void logOp(String operation, Object error, [StackTrace? stackTrace]) {
    final userMessage = ErrorMapper.toMessage(error);
    final technical = error is UserFriendlyError ? error.message : error.toString();
    AppErrorHandler.log(
      'Warehouse.$operation: $userMessage | technical=$technical | type=${error.runtimeType}',
      stackTrace,
    );
  }
}

/// Bandeau d’en-tête entreprise — texte contraint, pas de débordement.
class WarehouseCompanyHeader extends StatelessWidget {
  const WarehouseCompanyHeader({super.key, required this.companyName});

  final String companyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.home_work_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dépôt central',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companyName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État d’erreur — message clair + retry ; erreur déjà loguée côté appelant.
class WarehouseErrorPanel extends StatelessWidget {
  const WarehouseErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Impossible de charger le dépôt',
  });

  final String message;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error.withValues(alpha: 0.85)),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Erreur dans un onglet (liste) — message utilisateur + réessai ; détails techniques via [AppErrorHandler.log] côté appelant.
class WarehouseInlineErrorCard extends StatelessWidget {
  const WarehouseInlineErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Impossible de charger',
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Semantics(
            container: true,
            label: '$title. $message',
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 44, color: scheme.error.withValues(alpha: 0.85)),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste vide — illustration sobre.
class WarehouseEmptyState extends StatelessWidget {
  const WarehouseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.paddingTop = 80,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: paddingTop),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Icon(icon, size: 48, color: scheme.outline.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Miniature produit (liste stock dépôt) — 1re image ou icône inventaire.
class WarehouseProductThumbnail extends StatelessWidget {
  const WarehouseProductThumbnail({super.key, this.imageUrl, this.size = 48});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WarehouseUi.radiusSm),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.inventory_2_outlined, color: scheme.outline, size: size * 0.45),
                ),
              )
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.inventory_2_outlined, color: scheme.outline, size: size * 0.45),
              ),
      ),
    );
  }
}
