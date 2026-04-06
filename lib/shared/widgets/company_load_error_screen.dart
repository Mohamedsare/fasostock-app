import 'package:flutter/material.dart';

/// Écran affiché quand le chargement des entreprises a échoué (réseau, permission, etc.).
/// Utilisé par le tableau de bord, ventes, produits, boutiques, etc.
class CompanyLoadErrorScreen extends StatelessWidget {
  const CompanyLoadErrorScreen({
    super.key,
    required this.message,
    required this.title,
  });

  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final appBar = isWide ? AppBar(title: Text(title)) : null;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: appBar,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (appBar == null) ...[
                Text(title, textAlign: TextAlign.center, style: titleStyle),
                const SizedBox(height: 16),
              ],
              Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
