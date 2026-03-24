import 'package:flutter/material.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/constants/role_labels.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../data/models/company_member.dart';
import '../../../../data/models/store.dart';
import '../../../../data/repositories/users_repository.dart';

/// Dialog de création d'utilisateur — aligné web (email, mot de passe, nom, rôle, boutiques).
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({
    super.key,
    required this.companyId,
    required this.stores,
    required this.onSuccess,
    required this.onCancel,
  });

  final String companyId;
  final List<Store> stores;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final UsersRepository _repo = UsersRepository();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  List<RoleOption> _roles = [];
  bool _loadingRoles = true;
  bool _submitting = false;
  String? _error;
  String _roleSlug = '';
  final List<String> _storeIds = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final list = await _repo.listRoles();
      if (mounted) {
        setState(() {
          _roles = list.where((r) => r.slug != 'super_admin').toList();
          if (_roles.isNotEmpty && _roleSlug.isEmpty) _roleSlug = _roles.first.slug;
          _loadingRoles = false;
        });
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loadingRoles = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6 || _roleSlug.isEmpty) return;
    if (_storeIds.isEmpty && widget.stores.isNotEmpty) {
      setState(() => _error = 'Choisissez au moins une boutique pour cet utilisateur.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.createCompanyUser(
        companyId: widget.companyId,
        email: email,
        password: password,
        fullName: _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim(),
        roleSlug: _roleSlug.trim().toLowerCase(),
        storeIds: _storeIds.isEmpty ? null : List.from(_storeIds),
      );
      if (mounted && context.mounted) {
        AppToast.success(context, 'Utilisateur créé. Le type (rôle) est enregistré et s\'appliquera à la connexion.');
        widget.onSuccess();
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = AppErrorHandler.toUserMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < Breakpoints.tablet;
    final maxContentWidth = isNarrow ? screenWidth - 32 : 400.0;
    final insetPadding = isNarrow ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);

    return AlertDialog(
      insetPadding: insetPadding,
      title: Row(
        children: [
          Icon(Icons.person_add_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Nouvel utilisateur', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'L\'utilisateur pourra se connecter avec l\'email et le mot de passe ci-dessous. Communiquez-les-lui de façon sécurisée.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'utilisateur@exemple.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe *',
                    hintText: '••••••••',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom affiché',
                    hintText: 'Jean Dupont',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                if (_loadingRoles)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _roleSlug.isEmpty && _roles.isNotEmpty ? _roles.first.slug : _roleSlug,
                    decoration: const InputDecoration(
                      labelText: 'Rôle *',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r.slug, child: Text(RoleLabels.labelFr(r.slug, r.name))))
                        .toList(),
                    onChanged: (v) => setState(() => _roleSlug = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty) ? 'Rôle requis' : null,
                  ),
                if (widget.stores.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Boutiques * — le propriétaire doit choisir au moins une boutique pour cet utilisateur',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: widget.stores.map((s) {
                      final selected = _storeIds.contains(s.id);
                      final label = s.code != null && s.code!.isNotEmpty ? '${s.name} (${s.code})' : s.name;
                      return FilterChip(
                        label: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) _storeIds.add(s.id); else _storeIds.remove(s.id);
                          });
                        },
                        selectedColor: theme.colorScheme.primaryContainer,
                        checkmarkColor: theme.colorScheme.onPrimaryContainer,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        side: BorderSide(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.5),
                          width: selected ? 2 : 1,
                        ),
                        elevation: 1,
                        pressElevation: 2,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : widget.onCancel,
          style: TextButton.styleFrom(minimumSize: const Size(Breakpoints.minTouchTarget, Breakpoints.minTouchTarget)),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submitting || _loadingRoles ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget)),
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer et donner les identifiants'),
        ),
      ],
    );
  }
}
