import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/breakpoints.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/stores_repository.dart';

/// Dialog de création de boutique — formulaire + logo optionnel (aligné CreateStoreForm web).
class CreateStoreDialog extends StatefulWidget {
  const CreateStoreDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.onCancel,
  });

  final String companyId;
  /// Appelé avec la boutique créée (pour mise à jour immédiate du cache Drift).
  final void Function(Store? store)? onSuccess;
  final VoidCallback onCancel;

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPrimary = false;
  bool _loading = false;
  String? _error;
  List<int>? _logoBytes;
  String _logoFileName = '';
  String _logoContentType = 'image/jpeg';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) return;
      if (!mounted) return;
      setState(() {
        _logoBytes = file.bytes;
        _logoFileName = file.name;
        _logoContentType = file.extension != null ? 'image/${file.extension}' : 'image/jpeg';
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de sélectionner l\'image.'));
      }
    }
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
      final repo = StoresRepository();
      final input = CreateStoreInput(
        companyId: widget.companyId,
        name: name,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        isPrimary: _isPrimary,
      );
      Store store = await repo.createStore(input);
      if (_logoBytes != null && _logoBytes!.isNotEmpty) {
        final url = await repo.uploadStoreLogo(
          store.id,
          _logoBytes!,
          _logoFileName.isEmpty ? 'logo.jpg' : _logoFileName,
          _logoContentType,
        );
        store = await repo.updateStore(store.id, {'logo_url': url});
      }
      if (mounted) {
        widget.onSuccess?.call(store);
      }
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
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < Breakpoints.tablet;
    final padding = isNarrow ? 16.0 : 24.0;
    final maxW = isNarrow ? screenSize.width - 32 : 480.0;
    final maxH = isNarrow ? screenSize.height * 0.88 : 600.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouvelle boutique', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLogoPicker(context),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis (2 car. min.)' : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 8),
                        Text('Le code (B1, B2…) est généré automatiquement.', style: Theme.of(context).textTheme.bodySmall),
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
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Email invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse',
                            hintText: 'Rue, quartier, ville, pays',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _isPrimary,
                          onChanged: (v) => setState(() => _isPrimary = v ?? false),
                          title: const Text('Boutique principale'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : widget.onCancel,
                    style: TextButton.styleFrom(minimumSize: const Size(Breakpoints.minTouchTarget, Breakpoints.minTouchTarget)),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget)),
                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    final boxSize = isNarrow ? 72.0 : 80.0;
    return Row(
      children: [
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            ),
            child: _logoBytes != null && _logoBytes!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(Uint8List.fromList(_logoBytes!), fit: BoxFit.cover, width: boxSize, height: boxSize),
                  )
                : Icon(Icons.add_photo_alternate, size: 36, color: Theme.of(context).colorScheme.outline),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logo (optionnel)', style: Theme.of(context).textTheme.titleSmall),
              Text('Cliquez pour sélectionner', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
