import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/routes.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../services/auth/auth_service.dart';

/// Page Inscription — créer une entreprise + compte owner + première boutique (aligné RegisterPage + RegisterCompanyForm web).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companySlugController = TextEditingController();
  final _ownerFullNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _firstStoreNameController = TextEditingController();
  final _firstStorePhoneController = TextEditingController();

  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _companyNameController.addListener(_syncSlug);
  }

  @override
  void dispose() {
    _companyNameController.removeListener(_syncSlug);
    _companyNameController.dispose();
    _companySlugController.dispose();
    _ownerFullNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _firstStoreNameController.dispose();
    _firstStorePhoneController.dispose();
    super.dispose();
  }

  void _syncSlug() {
    final name = _companyNameController.text.trim();
    if (name.isEmpty) return;
    final slug = _slugFromName(name);
    if (_companySlugController.text != slug) {
      _companySlugController.text = slug;
    }
  }

  static String _slugFromName(String name) {
    if (name.trim().isEmpty) return '';
    final n = name.toLowerCase().trim();
    final withoutAccents = n
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
    return withoutAccents
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final authService = AuthService(Supabase.instance.client);
      await authService.registerCompany(RegisterCompanyInput(
        companyName: _companyNameController.text.trim(),
        companySlug: _companySlugController.text.trim().isEmpty
            ? _slugFromName(_companyNameController.text.trim())
            : _companySlugController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        ownerPassword: _ownerPasswordController.text,
        ownerFullName: _ownerFullNameController.text.trim(),
        firstStoreName: _firstStoreNameController.text.trim(),
        firstStorePhone: _firstStorePhoneController.text.trim(),
      ));
      if (mounted) {
        context.go(AppRoutes.login);
        AppToast.success(context, 'Compte créé. Connectez-vous.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go(AppRoutes.login),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Créer une entreprise',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inscription : entreprise, compte owner et première boutique.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: "Nom de l'entreprise *",
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis (2 car. min.)' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companySlugController,
                      decoration: const InputDecoration(
                        labelText: 'Slug (rempli automatiquement)',
                        hintText: 'mon-entreprise',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _firstStorePhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone *',
                        hintText: '70 00 00 00 ou +226 70 00 00 00',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 8) ? 'Téléphone requis (ex. 70 00 00 00)' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ownerFullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Votre nom complet *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ownerEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        hintText: 'vous@exemple.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email requis';
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ownerPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe *',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 caractères' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _firstStoreNameController,
                      decoration: const InputDecoration(
                        labelText: 'Première boutique — nom *',
                        hintText: 'Ma boutique',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Nom de la boutique requis' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Créer mon entreprise'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Déjà un compte ? Se connecter'),
                      ),
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
