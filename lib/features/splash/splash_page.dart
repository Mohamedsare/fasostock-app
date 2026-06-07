import 'package:flutter/material.dart';

import '../../shared/widgets/faso_stock_wordmark.dart';

/// Écran de démarrage (route `/_splash`) — identité FasoStock + chargement auth.
/// Couleurs alignées sur le thème ([ColorScheme.primary] orange, texte [0xFF1C1B1F]).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;

  static const Color _footerDark = Color(0xFF1C1917);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _SplashLogoMark(primary: primary),
                    const SizedBox(height: 20),
                    FasoStockWordmark(
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontSize: 32,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _StarDivider(color: primary),
                    const SizedBox(height: 10),
                    Text(
                      'GESTION INTELLIGENTE DE STOCK',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF1C1B1F),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SplashHeroIllustration(primary: primary),
                    const SizedBox(height: 28),
                    Text(
                      'Chargement de votre espace…',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1C1B1F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Préparation de vos données et vérification de la connexion',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(
                          _progressCtrl.value,
                        );
                        final v = 0.12 + t * 0.78;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: v.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: primary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          _SplashFooter(
            primary: primary,
            bottomInset: bottomInset,
            footerDark: _footerDark,
          ),
        ],
      ),
    );
  }
}

class _SplashLogoMark extends StatelessWidget {
  const _SplashLogoMark({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.18),
            primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 44,
            color: primary,
          ),
          Positioned(
            right: 14,
            bottom: 16,
            child: Icon(
              Icons.bar_chart_rounded,
              size: 22,
              color: primary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDivider extends StatelessWidget {
  const _StarDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: color.withValues(alpha: 0.35), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.star_rounded, size: 16, color: color),
        ),
        Expanded(
          child: Divider(color: color.withValues(alpha: 0.35), thickness: 1),
        ),
      ],
    );
  }
}

class _SplashHeroIllustration extends StatelessWidget {
  const _SplashHeroIllustration({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.warehouse_rounded,
            size: 40,
            color: primary.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.25),
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tableau de bord',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                    ),
                    const SizedBox(height: 6),
                    _miniLine(context, 'Ventes du jour', '125 500 F', primary),
                    const SizedBox(height: 4),
                    _miniLine(context, 'Produits en stock', '1 243', muted),
                    const SizedBox(height: 4),
                    _miniLine(context, 'Alertes stock faible', '8', Colors.orange),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 38,
            color: primary.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  static Widget _miniLine(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter({
    required this.primary,
    required this.bottomInset,
    required this.footerDark,
  });

  final Color primary;
  final double bottomInset;
  final Color footerDark;

  @override
  Widget build(BuildContext context) {
    final featureStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.92),
          height: 1.25,
          fontWeight: FontWeight.w600,
        );

    Widget feature(IconData icon, String label) {
      return SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: footerDark, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: featureStyle,
            ),
          ],
        ),
      );
    }

    final features = [
      feature(Icons.cloud_sync_rounded, 'Disponible hors ligne'),
      feature(Icons.shield_rounded, 'Données sécurisées'),
      feature(Icons.sync_rounded, 'Synchronisation auto'),
      feature(Icons.show_chart_rounded, 'Suivi en temps réel'),
    ];

    return Material(
      color: footerDark,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 22, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 360) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: features,
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: features,
                );
              },
            ),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const TextSpan(text: 'Votre business, '),
                  TextSpan(
                    text: 'notre priorité',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 15,
                        color: primary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
