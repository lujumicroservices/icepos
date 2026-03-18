import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ice_pos/src/core/services/category_image_service.dart';
import 'package:ice_pos/src/features/pos/data/pos_repository.dart';
import 'package:ice_pos/src/features/pos/domain/category.dart' as domain_cat;
import 'package:ice_pos/src/features/pos/presentation/pos_categories_refresh.dart';
import 'package:ice_pos/src/features/admin/presentation/product_editor_screen.dart';
import 'package:image_picker/image_picker.dart';

final _categoriesProvider = FutureProvider<List<domain_cat.Category>>((ref) {
  ref.watch(posCategoriesRefreshProvider);
  return ref.read(posRepositoryProvider).getAllCategories();
});

/// Category management: list, add, edit, delete categories; add product to category.
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Category Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 20),
        ),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading categories', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(err.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14)),
              ],
            ),
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet. Tap + to add.',
                    style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          final roots = categories.where((c) => c.parentId == null).toList();
          final byParent = <int?, List<domain_cat.Category>>{};
          for (final c in categories) {
            if (c.parentId != null) {
              byParent.putIfAbsent(c.parentId, () => []).add(c);
            }
          }
          for (final list in byParent.values) {
            list.sort((a, b) => a.name.compareTo(b.name));
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final root in roots) ...[
                _CategoryTile(
                  category: root,
                  productCount: ref.watch(_productCountProvider(root.id)),
                  onTap: () => _openCategoryEditor(context, ref, root, categories),
                  onAddProduct: () => _openProductEditor(context, ref, categoryId: root.id),
                ),
                ...(byParent[root.id] ?? []).map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: _CategoryTile(
                      category: child,
                      productCount: ref.watch(_productCountProvider(child.id)),
                      onTap: () => _openCategoryEditor(context, ref, child, categories),
                      onAddProduct: () => _openProductEditor(context, ref, categoryId: child.id),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final categories = await ref.read(posRepositoryProvider).getAllCategories();
          if (!context.mounted) return;
          _openCategoryEditor(context, ref, null, categories);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openCategoryEditor(
    BuildContext context,
    WidgetRef ref,
    domain_cat.Category? category,
    List<domain_cat.Category> categories,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CategoryEditorDialog(
        category: category,
        categories: categories,
        repository: ref.read(posRepositoryProvider),
      ),
    );
    if (result == true && context.mounted) {
      ref.invalidate(_categoriesProvider);
      ref.read(posCategoriesRefreshProvider.notifier).update((v) => v + 1);
    }
  }

  void _openProductEditor(BuildContext context, WidgetRef ref, {required int categoryId}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProductEditorScreen(initialCategoryId: categoryId),
      ),
    ).then((_) {
      ref.invalidate(_categoriesProvider);
      ref.invalidate(_productCountProvider(categoryId));
    });
  }
}

final _productCountProvider = FutureProvider.family<int, int>((ref, categoryId) {
  return ref.read(posRepositoryProvider).countProductsInCategory(categoryId);
});

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.productCount,
    required this.onTap,
    required this.onAddProduct,
  });

  final domain_cat.Category category;
  final AsyncValue<int> productCount;
  final VoidCallback onTap;
  final VoidCallback onAddProduct;

  static int _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF9E9E9E;
    final c = hex.replaceFirst('#', '');
    if (c.length == 6) return 0xFF000000 + int.parse(c, radix: 16);
    return 0xFF9E9E9E;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = category.color != null ? Color(_parseColor(category.color)) : Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: () {
                final url = category.imageUrl?.trim();
                if (url != null && url.isNotEmpty) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _categoryImagePlaceholder(context),
                  );
                }
                return _categoryImagePlaceholder(context);
              }(),
            ),
          ),
        ],
      ),
      title: Text(
        category.name,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: productCount.when(
        data: (n) => Text('$n product(s)', style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        loading: () => const Text('…'),
        error: (_, __) => const SizedBox.shrink(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add product to this category',
            onPressed: onAddProduct,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit category',
            onPressed: onTap,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    this.category,
    required this.categories,
    required this.repository,
  });

  final domain_cat.Category? category;
  final List<domain_cat.Category> categories;
  final PosRepository repository;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _colorController;
  late TextEditingController _imageUrlController;
  Uint8List? _pickedImageBytes;
  String? _pickedImageMime;
  int? _parentId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _colorController = TextEditingController(text: widget.category?.color ?? '#87CEEB');
    _imageUrlController = TextEditingController(text: widget.category?.imageUrl ?? '');
    _parentId = widget.category?.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageMime = _mimeFromPath(file.path);
        _imageUrlController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener la imagen: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageMime = null;
      _imageUrlController.clear();
    });
  }

  List<domain_cat.Category> get _parentCandidates {
    if (widget.category == null) return widget.categories;
    return widget.categories.where((c) => c.id != widget.category!.id).toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      final hadPickedFile = _pickedImageBytes != null;
      final trimmedUrl = _imageUrlController.text.trim();
      final imageUrl =
          hadPickedFile ? null : (trimmedUrl.isEmpty ? null : trimmedUrl);
      if (widget.category == null) {
        await widget.repository.insertCategory(
          name: name,
          parentId: _parentId,
          color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
          imageUrl: imageUrl,
          newImageBytes: _pickedImageBytes?.toList(),
          newImageMimeType: _pickedImageMime,
        );
      } else {
        await widget.repository.updateCategory(
          widget.category!.id,
          name: name,
          parentId: _parentId,
          color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
          imageUrl: imageUrl,
          newImageBytes: _pickedImageBytes?.toList(),
          newImageMimeType: _pickedImageMime,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _delete() async {
    if (widget.category == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete "${widget.category!.name}"? Products in this category must be moved first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.deleteCategory(widget.category!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            _CategoryImageEditor(
              pickedImageBytes: _pickedImageBytes,
              imageUrlController: _imageUrlController,
              onPickGallery: _isSaving ? null : () => _pickImage(ImageSource.gallery),
              onPickCamera: _isSaving || kIsWeb ? null : () => _pickImage(ImageSource.camera),
              onClear: _isSaving ? null : _clearImage,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Parent category',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _parentId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('None (root category)')),
                    ..._parentCandidates.map(
                      (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: _isSaving ? null : (v) => setState(() => _parentId = v),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Color (hex, e.g. #87CEEB)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.category != null)
          TextButton(
            onPressed: _isSaving ? null : _delete,
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _CategoryImageEditor extends StatelessWidget {
  const _CategoryImageEditor({
    required this.pickedImageBytes,
    required this.imageUrlController,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
  });

  final Uint8List? pickedImageBytes;
  final TextEditingController imageUrlController;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrlController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Imagen (opcional)',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              height: 140,
              color: scheme.surfaceContainerHighest,
              child: pickedImageBytes != null
                  ? Image.memory(pickedImageBytes!, fit: BoxFit.cover)
                  : (url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _categoryImagePlaceholder(context),
                        )
                      : _categoryImagePlaceholder(context)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: onPickGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('Galería'),
            ),
            if (onPickCamera != null)
              FilledButton.tonalIcon(
                onPressed: onPickCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('Cámara'),
              ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Quitar'),
            ),
          ],
        ),
        if (!CategoryImageService.canUpload) ...[
          const SizedBox(height: 8),
          Text(
            'Sin Supabase: solo puedes usar una URL pública de imagen.',
            style: GoogleFonts.inter(fontSize: 12, color: scheme.tertiary),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: imageUrlController,
          decoration: const InputDecoration(
            labelText: 'URL de imagen (opcional)',
            hintText: 'https://...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
      ],
    );
  }
}

Widget _categoryImagePlaceholder(BuildContext context) {
  return Center(
    child: Icon(
      Icons.folder_outlined,
      size: 56,
      color:
          Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
    ),
  );
}
