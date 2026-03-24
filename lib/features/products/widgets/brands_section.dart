import 'package:flutter/material.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/brand.dart';
import '../../../data/repositories/products_repository.dart';

/// Callbacks optionnels pour mise à jour immédiate du cache Drift (UI instantanée).
typedef OnBrandCreated = void Function(Brand created);
typedef OnBrandUpdated = void Function(Brand updated);
typedef OnBrandDeleted = void Function(String id);

/// Section Marques — liste, création, édition, suppression (aligné BrandsSection web).
/// Si readOnly (ex. caissier), affichage lecture seule sans créer/modifier/supprimer.
class BrandsSection extends StatefulWidget {
  const BrandsSection({
    super.key,
    required this.companyId,
    required this.brands,
    required this.onChanged,
    this.readOnly = false,
    this.onBrandCreated,
    this.onBrandUpdated,
    this.onBrandDeleted,
  });

  final String companyId;
  final List<Brand> brands;
  final VoidCallback onChanged;
  final bool readOnly;
  final OnBrandCreated? onBrandCreated;
  final OnBrandUpdated? onBrandUpdated;
  final OnBrandDeleted? onBrandDeleted;

  @override
  State<BrandsSection> createState() => _BrandsSectionState();
}

class _BrandsSectionState extends State<BrandsSection> {
  final _newNameController = TextEditingController();
  final _repo = ProductsRepository();
  String? _editingId;
  final _editNameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newNameController.dispose();
    _editNameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final created = await _repo.createBrand(widget.companyId, name);
      _newNameController.clear();
      if (widget.onBrandCreated != null) {
        widget.onBrandCreated!(created);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Marque créée');
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

  void _startEdit(Brand b) {
    setState(() {
      _editingId = b.id;
      _editNameController.text = b.name;
    });
  }

  Future<void> _saveEdit() async {
    if (_editingId == null) return;
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updated = await _repo.updateBrand(_editingId!, name);
      setState(() => _editingId = null);
      _editNameController.clear();
      if (widget.onBrandUpdated != null) {
        widget.onBrandUpdated!(updated);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Marque mise à jour');
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

  Future<void> _delete(Brand b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette marque ?'),
        content: Text('« ${b.name} » sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repo.deleteBrand(b.id);
      if (widget.onBrandDeleted != null) {
        widget.onBrandDeleted!(b.id);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Marque supprimée');
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
    final theme = Theme.of(context);
    return Card(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Marques', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              if (!widget.readOnly)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 260;
                    final field = TextField(
                      controller: _newNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle marque',
                        hintText: 'Nom',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _create(),
                    );
                    final button = FilledButton.tonal(
                      onPressed: _loading ? null : _create,
                      child: const Icon(Icons.add),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: 8),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 8),
                        button,
                      ],
                    );
                  },
                ),
              if (!widget.readOnly && _error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              if (widget.brands.isEmpty)
                Text('Aucune marque.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              else
                ...widget.brands.map((b) {
                  final isEditing = !widget.readOnly && _editingId == b.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            child: TextField(
                              controller: _editNameController,
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.check), onPressed: _saveEdit, style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40))),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editingId = null), style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40))),
                        ] else ...[
                          Expanded(
                            child: Text(
                              b.name,
                              style: theme.textTheme.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!widget.readOnly) ...[
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 22), onPressed: () => _startEdit(b), tooltip: 'Modifier', style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40))),
                            IconButton(icon: Icon(Icons.delete_outline, size: 22, color: theme.colorScheme.error), onPressed: () => _delete(b), tooltip: 'Supprimer', style: IconButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(40, 40))),
                          ],
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
