import 'package:flutter/material.dart';

/// Écran affiché quand le chargement des entreprises a échoué (réseau, permission, etc.).
/// Utilisé par le tableau de bord, ventes, produits, boutiques, etc.
class CompanyLoadErrorScreen extends StatelessWidget {
  const CompanyLoadErrorScreen({
    super.key,
    required this.message,
    required this.title,
    this.appBar,
  });

  final String message;
  final String title;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ?? AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
