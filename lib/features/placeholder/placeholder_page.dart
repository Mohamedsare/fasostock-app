import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/routes.dart';

/// Page placeholder pour les écrans pas encore migrés.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('$title — à venir', style: Theme.of(context).textTheme.titleLarge),
            Text(path, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
