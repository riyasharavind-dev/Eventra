import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/banner_model.dart';
import '../../repositories/banner_repository.dart';

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen>
    with LiveDataState<BannersScreen> {
  @override
  Set<String> get liveDatasets => {'admin:banners'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _loadBanners();
  }

  final BannerRepository _repository = BannerRepository();

  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _searchController = TextEditingController();

  List<BannerModel> _banners = [];

  bool _isLoading = true;
  bool _activeOnly = false;

  String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _loadBanners();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadBanners() async {
    if (!mounted) {
      return;
    }

    setState(() {
      if (!liveRefreshing) _isLoading = true;
    });

    try {
      final banners = await _repository.getBanners();

      if (!mounted) {
        return;
      }

      setState(() {
        _banners = banners;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(_cleanError(e), isError: true);
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<BannerModel> get _filteredBanners {
    return _banners.where((banner) {
      if (_activeOnly && !banner.isActive) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      return banner.title.toLowerCase().contains(_searchQuery) ||
          (banner.subtitle ?? '').toLowerCase().contains(_searchQuery) ||
          banner.actionType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _openAddBanner() async {
    final bool? created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _BannerFormDialog(
          imagePicker: _imagePicker,
          repository: _repository,
        );
      },
    );

    if (created == true) {
      await _loadBanners();
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _openEditBanner(BannerModel banner) async {
    final bool? updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _BannerFormDialog(
          imagePicker: _imagePicker,
          repository: _repository,
          banner: banner,
        );
      },
    );

    if (updated == true) {
      await _loadBanners();
    }
  }

  // ============================================================
  // TOGGLE
  // ============================================================

  Future<void> _toggleBanner(BannerModel banner) async {
    try {
      await _repository.toggleBannerStatus(banner);

      await _loadBanners();

      _showMessage(
        banner.isActive ? 'Banner deactivated.' : 'Banner activated.',
      );
    } catch (e) {
      _showMessage(_cleanError(e), isError: true);
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteBanner(BannerModel banner) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Banner?'),
          content: Text(
            'Are you sure you want to delete '
            '"${banner.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteBanner(banner);

      await _loadBanners();

      _showMessage('Banner deleted successfully.');
    } catch (e) {
      _showMessage(_cleanError(e), isError: true);
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBanners;

    final activeCount = _banners.where((banner) => banner.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF9F0101),
        foregroundColor: Colors.white,
        onPressed: _openAddBanner,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Banner',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Banners',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadBanners,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // ------------------------------------------
                    // TOP CARD
                    // ------------------------------------------

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9F0101),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 54,
                            width: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.view_carousel_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Home Banners',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_banners.length} total • '
                                '$activeCount active',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ------------------------------------------
                    // SEARCH
                    // ------------------------------------------
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search banners...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ------------------------------------------
                    // FILTER
                    // ------------------------------------------
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Active only'),
                          selected: _activeOnly,
                          onSelected: (value) {
                            setState(() {
                              _activeOnly = value;
                            });
                          },
                        ),
                        const Spacer(),
                        Text(
                          '${filtered.length} banners',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ------------------------------------------
                    // LIST
                    // ------------------------------------------
                    Expanded(child: _buildList(filtered)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildList(List<BannerModel> banners) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (banners.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 70,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No banners yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first banner to display '
                'it on the customer app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9F0101),
                ),
                onPressed: _openAddBanner,
                icon: const Icon(Icons.add),
                label: const Text('Add Banner'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBanners,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;

          // Responsive admin grid:
          // < 650  -> 1 column
          // < 1050 -> 2 columns
          // >=1050 -> 3 columns
          final int crossAxisCount = width >= 1050
              ? 3
              : width >= 650
              ? 2
              : 1;

          final double spacing = 14;
          final double cardWidth =
              (width - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

          final double imageHeight = (cardWidth * 0.56).clamp(130.0, 210.0);

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: _gridCardHeight(imageHeight, crossAxisCount),
            ),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              return _buildBannerCard(banners[index], imageHeight: imageHeight);
            },
          );
        },
      ),
    );
  }

  double _gridCardHeight(double imageHeight, int crossAxisCount) {
    // Compact height for grid cards while keeping enough
    // space for title, action and controls.
    if (crossAxisCount == 1) {
      return imageHeight + 205;
    }

    return imageHeight + 190;
  }

  // ============================================================
  // GRID CARD
  // ============================================================

  Widget _buildBannerCard(BannerModel banner, {required double imageHeight}) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================================
          // IMAGE
          // ========================================================

          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  banner.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 46,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF9F0101),
                        ),
                      ),
                    );
                  },
                ),

                // Image gradient.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),

                // Active badge.
                Positioned(
                  top: 10,
                  right: 10,
                  child: _statusBadge(banner.isActive),
                ),
              ],
            ),
          ),

          // ========================================================
          // DETAILS
          // ========================================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  Text(
                    banner.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  // ------------------------------------------------
                  // SUBTITLE
                  // ------------------------------------------------
                  if ((banner.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],

                  const Spacer(),

                  // ------------------------------------------------
                  // ACTION
                  // ------------------------------------------------
                  Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _actionLabel(banner),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  // ------------------------------------------------
                  // CONTROLS
                  // ------------------------------------------------
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () => _toggleBanner(banner),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              side: BorderSide(
                                color: banner.isActive
                                    ? Colors.grey.shade300
                                    : const Color(0xFF9F0101),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  banner.isActive
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    banner.isActive ? 'Deactivate' : 'Activate',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      _cardActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onPressed: () => _openEditBanner(banner),
                      ),

                      const SizedBox(width: 4),

                      _cardActionButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        iconColor: Colors.red,
                        onPressed: () => _deleteBanner(banner),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(BannerModel banner) {
    final String type = banner.actionType.trim().toLowerCase();

    final String value = banner.actionValue?.trim() ?? '';

    if (type == 'none') {
      return 'No action';
    }

    if (value.isEmpty) {
      return type.toUpperCase();
    }

    return '$type → $value';
  }

  Widget _cardActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color iconColor = Colors.black87,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 34,
        width: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: iconColor),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

// ============================================================
// BANNER FORM DIALOG
// ============================================================

class _BannerFormDialog extends StatefulWidget {
  final ImagePicker imagePicker;
  final BannerRepository repository;
  final BannerModel? banner;

  const _BannerFormDialog({
    required this.imagePicker,
    required this.repository,
    this.banner,
  });

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;

  late final TextEditingController _subtitleController;

  late final TextEditingController _actionValueController;

  late final TextEditingController _sortOrderController;

  XFile? _selectedImage;

  String _actionType = 'none';

  bool _isActive = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final banner = widget.banner;

    _titleController = TextEditingController(text: banner?.title ?? '');

    _subtitleController = TextEditingController(text: banner?.subtitle ?? '');

    _actionValueController = TextEditingController(
      text: banner?.actionValue ?? '',
    );

    _sortOrderController = TextEditingController(
      text: banner?.sortOrder.toString() ?? '0',
    );

    _actionType = banner?.actionType ?? 'none';

    _isActive = banner?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _actionValueController.dispose();
    _sortOrderController.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final XFile? image = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      _showMessage('Could not select image: $e', isError: true);
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.banner == null && _selectedImage == null) {
      _showMessage('Please select a banner image.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String imageUrl = widget.banner?.imageUrl ?? '';

      String imagePath = widget.banner?.imagePath ?? '';

      // ------------------------------------------
      // IMAGE UPLOAD
      // ------------------------------------------

      if (_selectedImage != null) {
        final image = _selectedImage!;

        final bytes = await image.readAsBytes();

        final extension = _getExtension(image.name);

        final contentType = _getContentType(extension);

        final fileName =
            'banner_${DateTime.now().millisecondsSinceEpoch}.$extension';

        imagePath = 'home/$fileName';

        imageUrl = await widget.repository.uploadBannerImage(
          path: imagePath,
          bytes: bytes,
          contentType: contentType,
        );

        // Delete old image after
        // successful new upload.
        if (widget.banner != null &&
            widget.banner!.imagePath.isNotEmpty &&
            widget.banner!.imagePath != imagePath) {
          try {
            await widget.repository.deleteImage(widget.banner!.imagePath);
          } catch (_) {}
        }
      }

      final int sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

      final String? actionValue = _actionValueController.text.trim().isEmpty
          ? null
          : _actionValueController.text.trim();

      // ------------------------------------------
      // UPDATE
      // ------------------------------------------

      if (widget.banner != null) {
        await widget.repository.updateBanner(
          id: widget.banner!.id,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim().isEmpty
              ? null
              : _subtitleController.text.trim(),
          imageUrl: imageUrl,
          imagePath: imagePath,
          actionType: _actionType,
          actionValue: actionValue,
          isActive: _isActive,
          sortOrder: sortOrder,
        );
      }
      // ------------------------------------------
      // CREATE
      // ------------------------------------------
      else {
        await widget.repository.createBanner(
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim().isEmpty
              ? null
              : _subtitleController.text.trim(),
          imageUrl: imageUrl,
          imagePath: imagePath,
          actionType: _actionType,
          actionValue: actionValue,
          isActive: _isActive,
          sortOrder: sortOrder,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _getExtension(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'png';
    }

    if (lower.endsWith('.webp')) {
      return 'webp';
    }

    return 'jpg';
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        return 'image/jpeg';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // BUILD DIALOG
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.banner != null;

    return AlertDialog(
      title: Text(
        isEdit ? 'Edit Banner' : 'Add Banner',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),

      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==============================================
                // IMAGE
                // ==============================================

                GestureDetector(
                  onTap: _isSaving ? null : _pickImage,
                  child: Container(
                    height: 210,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildImagePreview(),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickImage,
                    icon: const Icon(Icons.upload_outlined),
                    label: Text(
                      isEdit ? 'Change Banner Image' : 'Choose Banner Image',
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ==============================================
                // TITLE
                // ==============================================
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Banner Title',
                    hintText: 'Example: Wedding Season Offers',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter banner title';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ==============================================
                // SUBTITLE
                // ==============================================
                TextFormField(
                  controller: _subtitleController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle',
                    hintText: 'Optional banner description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subtitles_outlined),
                  ),
                ),

                const SizedBox(height: 14),

                // ==============================================
                // ACTION TYPE
                // ==============================================
                DropdownButtonFormField<String>(
                  initialValue: _actionType,
                  decoration: const InputDecoration(
                    labelText: 'Click Action',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.touch_app_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No Action')),
                    DropdownMenuItem(
                      value: 'screen',
                      child: Text('Open App Screen'),
                    ),
                    DropdownMenuItem(value: 'url', child: Text('Open URL')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _actionType = value;
                          });
                        },
                ),

                const SizedBox(height: 14),

                // ==============================================
                // ACTION VALUE
                // ==============================================
                TextFormField(
                  controller: _actionValueController,
                  enabled: !_isSaving && _actionType != 'none',
                  decoration: InputDecoration(
                    labelText: _actionType == 'url' ? 'URL' : 'Screen / Route',
                    hintText: _actionType == 'url'
                        ? 'https://example.com'
                        : '/discover',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link_outlined),
                  ),
                  validator: (value) {
                    if (_actionType == 'none') {
                      return null;
                    }

                    if (value == null || value.trim().isEmpty) {
                      return _actionType == 'url'
                          ? 'Enter URL'
                          : 'Enter screen route';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ==============================================
                // SORT ORDER
                // ==============================================
                TextFormField(
                  controller: _sortOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    hintText: '0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort_outlined),
                  ),
                ),

                const SizedBox(height: 4),

                // ==============================================
                // ACTIVE
                // ==============================================
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Active Banner',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Show this banner in the customer app'),
                  value: _isActive,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9F0101),
          ),
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save Banner'),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return FutureBuilder<List<int>>(
        future: _selectedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Image.memory(
            snapshot.data! as dynamic,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    }

    if (widget.banner != null && widget.banner!.imageUrl.isNotEmpty) {
      return Image.network(
        widget.banner!.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload_outlined, size: 52, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          'Click to choose banner image',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'JPG, PNG or WEBP • Max 5 MB',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
