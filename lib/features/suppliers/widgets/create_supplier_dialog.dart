import 'package:flutter/material.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/suppliers_repository.dart';

/// Dialog de création de fournisseur — aligné web SuppliersPage.
class CreateSupplierDialog extends StatefulWidget {
  const CreateSupplierDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.onCancel,
  });

  final String companyId;
  /// Appelé avec le fournisseur créé (pour mise à jour immédiate du cache Drift).
  final void Function(Supplier? supplier)? onSuccess;
  final VoidCallback onCancel;

  @override
  State<CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Nom requis (2 caractères minimum)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = SuppliersRepository();
      final created = await repo.create(widget.companyId,
        name: name,
        contact: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) widget.onSuccess?.call(created);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Nouveau fournisseur'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Contact', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : widget.onCancel, child: const Text('Annuler')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer'),
        ),
      ],
    );
  }
}
