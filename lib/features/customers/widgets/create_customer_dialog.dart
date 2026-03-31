import 'package:flutter/material.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customers_repository.dart';

/// Callback pour créer un client hors ligne (enqueue pending + insertion locale Drift).
typedef OnOfflineCreateCustomer = Future<void> Function(CreateCustomerInput input);

/// Dialog de création de client — formulaire responsive. Hors ligne : utilise [onOfflineCreate] (Drift).
class CreateCustomerDialog extends StatefulWidget {
  const CreateCustomerDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.onCancel,
    this.onOfflineCreate,
    this.onOfflineSuccess,
  });

  final String companyId;
  /// Appelé après création en ligne avec le client créé (pour mise à jour immédiate du cache).
  final void Function(Customer? created)? onSuccess;
  final VoidCallback onCancel;
  /// Requis pour le mode hors ligne (enqueue + insertion dans local_customers).
  final OnOfflineCreateCustomer? onOfflineCreate;
  /// Appelé après création hors ligne (évite double toast avec onSuccess).
  final VoidCallback? onOfflineSuccess;

  @override
  State<CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  CustomerType _type = CustomerType.individual;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
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
    final input = CreateCustomerInput(
      companyId: widget.companyId,
      name: name,
      type: _type,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    final isOnline = ConnectivityService.instance.isOnline;
    if (!isOnline) {
      final onOffline = widget.onOfflineCreate;
      if (onOffline == null) {
        setState(() {
          _loading = false;
          _error = 'Création hors ligne non disponible. Connectez-vous puis réessayez.';
        });
        return;
      }
      try {
        await onOffline(input);
        if (mounted) {
          AppToast.success(context, 'Client enregistré localement. Il sera créé à la reconnexion.');
          widget.onOfflineSuccess?.call();
          if (widget.onOfflineSuccess == null) widget.onSuccess?.call(null);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible d\'enregistrer le client. Réessayez.');
          });
        }
      }
      return;
    }
    try {
      final repo = CustomersRepository();
      final created = await repo.create(input);
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
      title: const Text('Nouveau client'),
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
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().length < 2 ? '2 caractères minimum' : null,
                ),
                const SizedBox(height: 16),
                SegmentedButton<CustomerType>(
                  segments: const [
                    ButtonSegment(value: CustomerType.individual, label: Text('Particulier')),
                    ButtonSegment(value: CustomerType.company, label: Text('Entreprise')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
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
