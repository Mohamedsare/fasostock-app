import 'package:flutter/material.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/products_repository.dart';

/// Callbacks optionnels pour mise à jour immédiate du cache Drift (UI instantanée).
typedef OnCategoryCreated = void Function(Category created);
typedef OnCategoryUpdated = void Function(Category updated);
typedef OnCategoryDeleted = void Function(String id);

/// Section Catégories — liste, création, édition, suppression (aligné CategoriesSection web).
/// Si readOnly (ex. caissier), affichage lecture seule sans créer/modifier/supprimer.
class CategoriesSection extends StatefulWidget {
  const CategoriesSection({
    super.key,
    required this.companyId,
    required this.categories,
    required this.onChanged,
    this.readOnly = false,
    this.onCategoryCreated,
    this.onCategoryUpdated,
    this.onCategoryDeleted,
  });

  final String companyId;
  final List<Category> categories;
  final VoidCallback onChanged;
  final bool readOnly;
  final OnCategoryCreated? onCategoryCreated;
  final OnCategoryUpdated? onCategoryUpdated;
  final OnCategoryDeleted? onCategoryDeleted;

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
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
      final created = await _repo.createCategory(widget.companyId, name);
      _newNameController.clear();
      if (widget.onCategoryCreated != null) {
        widget.onCategoryCreated!(created);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Catégorie créée');
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

  void _startEdit(Category c) {
    setState(() {
      _editingId = c.id;
      _editNameController.text = c.name;
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
      final updated = await _repo.updateCategory(_editingId!, name);
      setState(() => _editingId = null);
      _editNameController.clear();
      if (widget.onCategoryUpdated != null) {
        widget.onCategoryUpdated!(updated);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Catégorie mise à jour');
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

  Future<void> _delete(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette catégorie ?'),
        content: Text('« ${c.name} » sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _repo.deleteCategory(c.id);
      if (widget.onCategoryDeleted != null) {
        widget.onCategoryDeleted!(c.id);
      } else {
        widget.onChanged();
      }
      if (mounted) {
        setState(() => _loading = false);
        AppToast.success(context, 'Catégorie supprimée');
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Catégories', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!widget.readOnly)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nouvelle catégorie',
                        hintText: 'Nom',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _loading ? null : _create,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            if (!widget.readOnly && _error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (widget.categories.isEmpty)
              Text('Aucune catégorie.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              ...widget.categories.map((c) {
                final isEditing = !widget.readOnly && _editingId == c.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                        IconButton(icon: const Icon(Icons.check), onPressed: _saveEdit),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editingId = null)),
                      ] else ...[
                        Expanded(child: Text(c.name, style: Theme.of(context).textTheme.bodyLarge)),
                        if (!widget.readOnly) ...[
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _startEdit(c), tooltip: 'Modifier'),
                          IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), onPressed: () => _delete(c), tooltip: 'Supprimer'),
                        ],
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
