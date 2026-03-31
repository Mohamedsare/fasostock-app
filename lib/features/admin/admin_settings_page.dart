import 'package:flutter/material.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Paramètres plateforme (équivalent AdminSettingsPage web).
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final AdminRepository _repo = AdminRepository();
  Map<String, String> _form = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.getPlatformSettings();
      if (mounted) setState(() => _form = Map.from(s));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _set(String key, String value) => setState(() => _form[key] = value);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.setPlatformSettings(_form);
      if (mounted) AppToast.success(context, 'Paramètres enregistrés');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    String get(String k) => _form[k] ?? '';
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(title: 'Paramètres', description: 'Configuration de la plateforme (nom, contact, options)'),
          const SizedBox(height: 24),
          AdminCard(
            padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations plateforme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey('pname_${get('platform_name')}'),
                    initialValue: get('platform_name'),
                    decoration: const InputDecoration(labelText: 'Nom de la plateforme', hintText: 'FasoStock'),
                    onChanged: (v) => _set('platform_name', v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('email_${get('contact_email')}'),
                    initialValue: get('contact_email'),
                    decoration: const InputDecoration(labelText: 'Email de contact', hintText: 'contact@example.com'),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) => _set('contact_email', v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(key: ValueKey('phone_${get('contact_phone')}'), initialValue: get('contact_phone'), decoration: const InputDecoration(labelText: 'Téléphone'), onChanged: (v) => _set('contact_phone', v)),
                  const SizedBox(height: 12),
                  TextFormField(key: ValueKey('wa_${get('contact_whatsapp')}'), initialValue: get('contact_whatsapp'), decoration: const InputDecoration(labelText: 'WhatsApp (landing)'), onChanged: (v) => _set('contact_whatsapp', v)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AdminCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fonctionnalités', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  CheckboxListTile(title: const Text('Inscriptions publiques autorisées'), value: get('registration_enabled') == 'true', onChanged: (v) => _set('registration_enabled', v == true ? 'true' : 'false')),
                CheckboxListTile(title: const Text('Chatbot landing activé'), value: get('landing_chat_enabled') == 'true', onChanged: (v) => _set('landing_chat_enabled', v == true ? 'true' : 'false')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer les paramètres'),
          ),
        ],
      ),
    );
  }
}
