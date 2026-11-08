import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

class CategoryExplorer extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? selectedCategory;

  const CategoryExplorer({
    super.key,
    required this.categories,
    this.selectedCategory,
  });

  @override
  State<CategoryExplorer> createState() => _CategoryExplorerState();
}

class _CategoryExplorerState extends State<CategoryExplorer> {
  String? _currentParentId;

  final List<String?> _navigationHistory = [];

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHILDREN
  // ============================================================

  List<Map<String, dynamic>> _getChildren(String? parentId) {
    final children = widget.categories.where((category) {
      final categoryParent = category['parent_id']?.toString();

      return categoryParent == parentId;
    }).toList();

    children.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );

    return children;
  }

  // ============================================================
  // HAS CHILDREN
  // ============================================================

  bool _hasChildren(String categoryId) {
    return widget.categories.any(
      (category) => category['parent_id']?.toString() == categoryId,
    );
  }

  // ============================================================
  // OPEN CATEGORY
  // ============================================================

  void _openCategory(Map<String, dynamic> category) {
    final id = category['id'].toString();

    if (!_hasChildren(id)) {
      _selectCategory(category);
      return;
    }

    setState(() {
      _navigationHistory.add(_currentParentId);

      _currentParentId = id;

      _searchController.clear();
      _searchQuery = '';
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
      _currentParentId = _navigationHistory.removeLast();

      _searchController.clear();
      _searchQuery = '';
    });
  }

  // ============================================================
  // SELECT CATEGORY
  // ============================================================

  void _selectCategory(Map<String, dynamic> category) {
    Navigator.pop(context, category);
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  List<Map<String, dynamic>> _getSearchResults() {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    final results = widget.categories.where((category) {
      final id = category['id'].toString();

      // Only selectable leaf categories appear
      // in search results.
      if (_hasChildren(id)) {
        return false;
      }

      final name = category['name']?.toString().toLowerCase() ?? '';

      final slug = category['slug']?.toString().toLowerCase() ?? '';

      final path = _buildPath(id).toLowerCase();

      return name.contains(query) ||
          slug.contains(query) ||
          path.contains(query);
    }).toList();

    results.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );

    return results;
  }

  // ============================================================
  // BUILD FULL CATEGORY PATH
  // ============================================================

  String _buildPath(String categoryId) {
    final lookup = <String, Map<String, dynamic>>{
      for (final category in widget.categories)
        category['id'].toString(): category,
    };

    final List<String> path = [];

    String? currentId = categoryId;

    final Set<String> visited = {};

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);

      final category = lookup[currentId];

      if (category == null) {
        break;
      }

      path.insert(0, category['name']?.toString() ?? '');

      currentId = category['parent_id']?.toString();
    }

    return path.join(' › ');
  }

  // ============================================================
  // BREADCRUMBS
  // ============================================================

  List<Map<String, dynamic>> _getBreadcrumbs() {
    final List<Map<String, dynamic>> breadcrumbs = [];

    String? currentId = _currentParentId;

    final lookup = <String, Map<String, dynamic>>{
      for (final category in widget.categories)
        category['id'].toString(): category,
    };

    final List<Map<String, dynamic>> reversed = [];

    while (currentId != null) {
      final category = lookup[currentId];

      if (category == null) {
        break;
      }

      reversed.add(category);

      currentId = category['parent_id']?.toString();
    }

    breadcrumbs.add({'id': null, 'name': 'Categories'});

    for (final category in reversed.reversed) {
      breadcrumbs.add(category);
    }

    return breadcrumbs;
  }

  // ============================================================
  // JUMP TO BREADCRUMB
  // ============================================================

  void _jumpToBreadcrumb(Map<String, dynamic> breadcrumb) {
    final id = breadcrumb['id']?.toString();

    setState(() {
      _currentParentId = id;

      _navigationHistory.clear();

      _searchController.clear();
      _searchQuery = '';
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchQuery.trim().isNotEmpty;

    final searchResults = isSearching
        ? _getSearchResults()
        : <Map<String, dynamic>>[];

    final children = _getChildren(_currentParentId);

    final breadcrumbs = _getBreadcrumbs();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ==================================================
            // HANDLE
            // ==================================================

            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // TITLE
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (_currentParentId != null)
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),

                  const Expanded(
                    child: Text(
                      'Select Category',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SEARCH
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // ==================================================
            // BREADCRUMB
            // ==================================================
            if (!isSearching)
              SizedBox(
                height: 44,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (int i = 0; i < breadcrumbs.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppIconColors.standard,
                            ),
                          ),

                        InkWell(
                          onTap: i == breadcrumbs.length - 1
                              ? null
                              : () {
                                  _jumpToBreadcrumb(breadcrumbs[i]);
                                },
                          child: Text(
                            breadcrumbs[i]['name'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == breadcrumbs.length - 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == breadcrumbs.length - 1
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const Divider(height: 1),

            // ==================================================
            // CONTENT
            // ==================================================
            Expanded(
              child: isSearching
                  ? _buildSearchResults(searchResults)
                  : _buildCategoryList(children),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY LIST
  // ============================================================

  Widget _buildCategoryList(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 55,
                color: AppIconColors.standard,
              ),
              SizedBox(height: 12),
              Text(
                'No categories found.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = categories[index];

        return _buildCategoryTile(category);
      },
    );
  }

  // ============================================================
  // CATEGORY TILE
  // ============================================================

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    final String id = category['id'].toString();

    final String name = category['name']?.toString() ?? '';

    final bool hasChildren = _hasChildren(id);

    final int childCount = _getChildren(id).length;

    final bool isSelected = widget.selectedCategory?['id']?.toString() == id;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF8FA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF80152C) : const Color(0xFFF0EDF0),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C)
                .withValues(alpha: isSelected ? 0.08 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            _openCategory(category);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF5E8EC)
                        : const Color(0xFFF8F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasChildren
                        ? Icons.folder_outlined
                        : Icons.category_outlined,
                    color: AppIconColors.standard,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF80152C)
                              : const Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasChildren
                            ? '$childCount subcategories'
                            : 'Select this category',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? const Color(0xFF80152C).withValues(alpha: 0.7)
                              : const Color(0xFF73737D),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasChildren)
                  const Icon(Icons.chevron_right, color: AppIconColors.standard)
                else if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF80152C))
                else
                  const Icon(
                    Icons.radio_button_unchecked,
                    color: Color(0xFFB8B5B8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  Widget _buildSearchResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 55, color: AppIconColors.standard),
              SizedBox(height: 12),
              Text(
                'No matching categories',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Try another category name.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = results[index];

        final String name = category['name']?.toString() ?? '';

        final String path = _buildPath(category['id'].toString());

        final bool isSelected =
            widget.selectedCategory?['id']?.toString() ==
            category['id'].toString();

        return Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              _selectCategory(category);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isSelected) const Icon(Icons.check_circle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
