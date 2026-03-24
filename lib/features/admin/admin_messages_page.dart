import 'package:flutter/material.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/admin_models.dart';
import '../../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Super admin : envoyer des messages (notifications) aux utilisateurs / owners.
/// Les messages s'affichent dans la partie Notifications de chaque destinataire.
class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  final AdminRepository _repo = AdminRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  List<AdminUser> _users = [];
  String? _selectedUserId;
  bool _sendToAllOwners = false;
  bool _loading = false;
  bool _usersLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final list = await _repo.listUsers();
      if (mounted) setState(() {
        _users = list;
        _usersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppToast.error(context, 'Le titre est obligatoire.');
      return;
    }
    if (!_sendToAllOwners && (_selectedUserId == null || _selectedUserId!.isEmpty)) {
      AppToast.error(context, 'Choisissez un destinataire ou cochez "Tous les owners".');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_sendToAllOwners) {
        final count = await _repo.sendNotificationToAllOwners(title, body: _bodyController.text.trim().isEmpty ? null : _bodyController.text.trim());
        if (mounted) {
          AppToast.success(context, 'Message envoyé à $count owner(s).');
          _titleController.clear();
          _bodyController.clear();
        }
      } else {
        await _repo.sendNotificationToUser(
          _selectedUserId!,
          title,
          body: _bodyController.text.trim().isEmpty ? null : _bodyController.text.trim(),
        );
        if (mounted) {
          AppToast.success(context, 'Message envoyé. Le destinataire le verra dans Notifications.');
          _titleController.clear();
          _bodyController.clear();
        }
      }
    } catch (e) {
      if (mounted) AppToast.error(context, AppErrorHandler.toUserMessage(e, fallback: 'Envoi impossible.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Envoyer un message',
            description: 'Les messages envoyés s\'affichent dans la partie Notifications des destinataires (owners ou utilisateur choisi).',
          ),
          const SizedBox(height: 24),
          AdminCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_usersLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else ...[
                  CheckboxListTile(
                    value: _sendToAllOwners,
                    onChanged: (v) => setState(() => _sendToAllOwners = v ?? false),
                    title: Text(
                      'Envoyer à tous les owners',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AdminPalette.title),
                    ),
                    subtitle: Text(
                      'Tous les propriétaires d\'entreprise recevront ce message dans leurs Notifications.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminPalette.subtitle),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_sendToAllOwners) ...[
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String?>(
                      value: _selectedUserId,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'Destinataire'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Choisir un destinataire —')),
                        ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.fullName ?? u.email ?? u.id}${u.email != null ? ' (${u.email})' : ''}'))),
                      ],
                      onChanged: (v) => setState(() => _selectedUserId = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    decoration: adminInputDecoration(labelText: 'Titre *', hintText: 'Objet du message'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    decoration: adminInputDecoration(labelText: 'Message (optionnel)').copyWith(alignLabelWithHint: true),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminPalette.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 20),
                    label: Text(_loading ? 'Envoi...' : 'Envoyer'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
