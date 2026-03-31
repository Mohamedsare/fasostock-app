import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/config/routes.dart';
import '../../../core/theme/app_theme.dart';

/// Page publique pour créer un compte super admin (Edge Function create-super-admin).
/// Nécessite le code secret configuré dans Supabase (CREATE_SUPER_ADMIN_SECRET).
class CreateSuperAdminPage extends StatefulWidget {
  const CreateSuperAdminPage({super.key});

  @override
  State<CreateSuperAdminPage> createState() => _CreateSuperAdminPageState();
}

class _CreateSuperAdminPageState extends State<CreateSuperAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  String? _error;
  String? _success;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = 'Code d\'accès requis (défini dans Supabase Edge Function).';
        _success = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Le mot de passe doit contenir au moins 6 caractères.';
        _success = null;
      });
      return;
    }

    if (!Env.hasValidSupabase) {
      setState(() {
        _error = 'Configuration Supabase manquante.';
        _success = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _success = null;
      _loading = true;
    });

    try {
      final url = Uri.parse('${Env.supabaseUrl}/functions/v1/create-super-admin');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.supabaseAnonKey}',
        },
        body: jsonEncode({
          'secret': code,
          'email': email,
          'password': password,
          if (fullName.isNotEmpty) 'full_name': fullName,
        }),
      );

      final data = (jsonDecode(res.body) as Map<String, dynamic>?) ?? <String, dynamic>{};

      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _error = (data['error'] as String?) ?? 'Erreur lors de la création.';
          _success = null;
          _loading = false;
        });
        return;
      }
      setState(() {
        _success =
            'Super admin créé : ${data['email'] ?? email}. Connectez-vous puis allez sur Admin plateforme.';
        _error = null;
        _loading = false;
        _emailController.clear();
        _passwordController.clear();
        _fullNameController.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur réseau. Réessayez.';
          _success = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXl,
              vertical: AppTheme.spaceXxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceXl),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Créer un super admin',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                        'Compte avec accès Admin plateforme. À utiliser une fois puis protéger cette page.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXl),
                      if (!Env.hasValidSupabase)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.spaceLg),
                          child: Text(
                            'Config Supabase manquante (URL et clé anon).',
                            style: TextStyle(color: colorScheme.error, fontSize: 13),
                          ),
                        ),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 22),
                              const SizedBox(width: AppTheme.spaceMd),
                              Expanded(child: Text(_error!, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                      ],
                      if (_success != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 22),
                              const SizedBox(width: AppTheme.spaceMd),
                              Expanded(child: Text(_success!, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),
                      ],
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code d\'accès *',
                          hintText: 'Code défini dans Supabase Edge Function',
                        ),
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty) ? 'Code requis' : null,
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          hintText: 'admin@exemple.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.isEmpty) ? 'Email requis' : null,
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe * (min. 6 caractères)',
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Mot de passe requis';
                          if (v.length < 6) return 'Minimum 6 caractères';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom (optionnel)',
                          hintText: 'Super Admin',
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXl),
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ?? false) _submit();
                              },
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Créer le super admin'),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Retour à la connexion'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
