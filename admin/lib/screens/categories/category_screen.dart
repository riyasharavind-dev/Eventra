import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/category_node_model.dart';
import '../../repositories/category_repository.dart';
import '../../widgets/admin_add_button.dart';
import '../../widgets/confirmation_dialog.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with LiveDataState<CategoryScreen> {
  @override
  Set<String> get liveDatasets => {'admin:category_nodes'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _loadCategories();
  }

  final CategoryRepository _repository = CategoryRepository();

  List<CategoryNodeModel> _categories = [];

  bool _isLoading = true;
  String? _errorMessage;

  /// null = Categories root
  /// UUID = currently opened category
  String? _currentFolderId;

  /// Stores previously opened folders.
  final List<String?> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        if (!liveRefreshing) _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final categories = await _repository.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // CURRENT FOLDER
  // ============================================================

  CategoryNodeModel? get _currentFolder {
    if (_currentFolderId == null) {
      return null;
    }

    for (final category in _categories) {
      if (category.id == _currentFolderId) {
        return category;
      }
    }

    return null;
  }

  // ============================================================
  // CURRENT ITEMS
  // ============================================================

  List<CategoryNodeModel> get _currentItems {
    final items = _categories
        .where((category) => category.parentId == _currentFolderId)
        .toList();

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return items;
  }

  // ============================================================
  // OPEN FOLDER
  // ============================================================

  void _openFolder(CategoryNodeModel category) {
    setState(() {
      _navigationHistory.add(_currentFolderId);
      _currentFolderId = category.id;
    });
  }

  // ============================================================
  // BACK
  // ============================================================

  void _goBack() {
    if (_navigationHistory.isEmpty) {
      return;
    }

    setState(() {
      _currentFolderId = _navigationHistory.removeLast();
    });
  }

  // ============================================================
  // HOME
  // ============================================================

  void _goHome() {
    setState(() {
      _currentFolderId = null;
      _navigationHistory.clear();
    });
  }

  // ============================================================
  // BREADCRUMB NAVIGATION
  // ============================================================

  void _goToBreadcrumb(CategoryNodeModel category) {
    final index = _navigationHistory.indexOf(category.id);

    if (index == -1) {
      return;
    }

    setState(() {
      _currentFolderId = category.id;

      _navigationHistory.removeRange(index + 1, _navigationHistory.length);
    });
  }

  // ============================================================
  // FIND CATEGORY
  // ============================================================

  CategoryNodeModel? _findCategory(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }

  // ============================================================
  // ADD CATEGORY
  // ============================================================

  Future<void> _showAddCategoryDialog({
    String? parentId,
    String? parentName,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            parentName == null ? 'Create New Folder' : 'Create Subfolder',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parentName != null)
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inside: $parentName',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

              if (parentName != null) const SizedBox(height: 16),

              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  hintText: 'Example: Decoration',
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _addCategory(dialogContext, controller.text, parentId);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                _addCategory(dialogContext, controller.text, parentId);
              },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == true) {
      await _loadCategories();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder created successfully')),
      );
    }
  }

  Future<void> _addCategory(
    BuildContext dialogContext,
    String rawName,
    String? parentId,
  ) async {
    final name = rawName.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );

      return;
    }

    final slug = _createSlug(name);

    try {
      await _repository.addCategory(name: name, slug: slug, parentId: parentId);

      if (!dialogContext.mounted) {
        return;
      }

      Navigator.pop(dialogContext, true);
    } catch (error) {
      if (!dialogContext.mounted) {
        return;
      }

      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('Failed to create folder: $error')),
      );
    }
  }

  // ============================================================
  // RENAME
  // ============================================================

  Future<void> _showEditCategoryDialog(CategoryNodeModel category) async {
    final controller = TextEditingController(text: category.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              prefixIcon: Icon(Icons.drive_file_rename_outline),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              _updateCategory(dialogContext, category, controller.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _updateCategory(dialogContext, category, controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == true) {
      await _loadCategories();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder renamed successfully')),
      );
    }
  }

  Future<void> _updateCategory(
    BuildContext dialogContext,
    CategoryNodeModel category,
    String rawName,
  ) async {
    final name = rawName.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );

      return;
    }

    final slug = _createSlug(name);

    try {
      await _repository.updateCategory(
        id: category.id,
        name: name,
        slug: slug,
        parentId: category.parentId,
      );

      if (!dialogContext.mounted) {
        return;
      }

      Navigator.pop(dialogContext, true);
    } catch (error) {
      if (!dialogContext.mounted) {
        return;
      }

      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('Failed to rename folder: $error')),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteCategory(CategoryNodeModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: 'Delete Folder?',
          message:
              'Are you sure you want to delete '
              '"${category.name}"?\n\n'
              'Any subfolders under this folder '
              'will also be deleted.',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          icon: Icons.delete_outline,
          confirmColor: Colors.red,
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteCategory(category.id);

      await _loadCategories();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${category.name} deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete folder: $error')),
      );
    }
  }

  // ============================================================
  // SLUG
  // ============================================================

  String _createSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AdminAddButton(
        tooltip: _currentFolder == null
            ? 'Create new folder'
            : 'Create new subfolder',
        onPressed: () {
          _showAddCategoryDialog(
            parentId: _currentFolderId,
            parentName: _currentFolder?.name,
          );
        },
      ),
      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildExplorerToolbar(),
        _buildBreadcrumbs(),

        const Divider(height: 1),

        Expanded(child: _buildFolderView()),
      ],
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildExplorerToolbar() {
    final currentFolder = _currentFolder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _navigationHistory.isNotEmpty ? _goBack : null,
            icon: const Icon(Icons.arrow_back),
          ),

          IconButton(
            tooltip: 'Home',
            onPressed: _currentFolderId != null ? _goHome : null,
            icon: const Icon(Icons.home_outlined),
          ),

          const SizedBox(width: 8),

          Container(
            width: 1,
            height: 26,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Text(
              currentFolder == null ? 'Categories' : currentFolder.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Text(
            '${_currentItems.length} '
            '${_currentItems.length == 1 ? 'item' : 'items'}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BREADCRUMBS
  // ============================================================

  Widget _buildBreadcrumbs() {
    final List<Widget> items = [];

    items.add(
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _goHome,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_outlined, size: 18),
              SizedBox(width: 6),
              Text('Categories'),
            ],
          ),
        ),
      ),
    );

    final breadcrumbIds = <String>[..._navigationHistory.whereType<String>()];

    if (_currentFolderId != null) {
      breadcrumbIds.add(_currentFolderId!);
    }

    for (final id in breadcrumbIds) {
      final category = _findCategory(id);

      if (category == null) {
        continue;
      }

      items.add(const Icon(Icons.chevron_right, size: 20, color: Colors.grey));

      final isCurrent = id == _currentFolderId;

      items.add(
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isCurrent
              ? null
              : () {
                  _goToBreadcrumb(category);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder,
                  size: 18,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),

                const SizedBox(width: 6),

                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: items),
      ),
    );
  }

  // ============================================================
  // FOLDER VIEW
  // ============================================================

  Widget _buildFolderView() {
    final items = _currentItems;

    if (items.isEmpty) {
      return _buildEmptyFolder();
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 180,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildFolderCard(items[index]);
        },
      ),
    );
  }

  // ============================================================
  // FOLDER CARD
  // ============================================================

  Widget _buildFolderCard(CategoryNodeModel category) {
    final childCount = _categories
        .where((item) => item.parentId == category.id)
        .length;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _openFolder(category);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.folder,
                        size: 76,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  PopupMenuButton<String>(
                    tooltip: 'Folder options',
                    onSelected: (value) {
                      switch (value) {
                        case 'add':
                          _showAddCategoryDialog(
                            parentId: category.id,
                            parentName: category.name,
                          );
                          break;

                        case 'rename':
                          _showEditCategoryDialog(category);
                          break;

                        case 'delete':
                          _deleteCategory(category);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.create_new_folder_outlined),
                            SizedBox(width: 10),
                            Text('New Subfolder'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.drive_file_rename_outline),
                            SizedBox(width: 10),
                            Text('Rename'),
                          ],
                        ),
                      ),

                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                '$childCount '
                '${childCount == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 3),

              Text(
                category.slug,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY FOLDER
  // ============================================================

  Widget _buildEmptyFolder() {
    final folder = _currentFolder;

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),

          Icon(
            folder == null
                ? Icons.folder_copy_outlined
                : Icons.folder_open_outlined,
            size: 80,
            color: Colors.grey,
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              folder == null ? 'No categories yet' : 'This folder is empty',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                folder == null
                    ? 'Create your first folder to get started.'
                    : 'Create a subfolder inside '
                          '"${folder.name}".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60),

            const SizedBox(height: 16),

            const Text(
              'Unable to load categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            Text(_errorMessage!, textAlign: TextAlign.center),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
