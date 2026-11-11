import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../common/app_shimmer.dart';
import '../../models/service_pricing.dart';
import '../../widgets/services/service_pricing_fields.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../edit/image_picker_widget.dart';

class EditServiceDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final ServiceModel service;

  const EditServiceDialog({
    super.key,
    required this.supabase,
    required this.service,
  });

  @override
  State<EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<EditServiceDialog> {
  ServicePricing pricing = const ServicePricing();

  // ============================================================
  // REPOSITORY
  // ============================================================

  late final ServiceRepository _repository;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  // ============================================================
  // CATEGORY STATE
  // ============================================================

  List<Map<String, dynamic>> _categories = [];

  String? _selectedCategoryId;

  bool _isLoadingCategories = true;
  bool _isSaving = false;

  // ============================================================
  // IMAGE STATE
  // ============================================================

  late List<String> _existingImages;

  List<XFile> _newImages = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    pricing = widget.service.pricing;

    _repository = ServiceRepository(supabase: widget.supabase);

    _nameController = TextEditingController(text: widget.service.name);

    _descriptionController = TextEditingController(
      text: widget.service.description ?? '',
    );

    _priceController = TextEditingController(
      text: widget.service.price.toString(),
    );

    _existingImages = List<String>.from(widget.service.gallery);

    _selectedCategoryId = widget.service.categoryNodeId;

    _loadCategories();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD CATEGORIES
  // ============================================================

  Future<void> _loadCategories() async {
    try {
      final List<dynamic> response = await widget.supabase
          .from('category_nodes')
          .select('id,name,slug,parent_id')
          .order('name', ascending: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = response
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();

        _isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCategories = false;
      });

      _showError(
        'Failed to load categories: '
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REMOVE EXISTING IMAGE
  // ============================================================

  void _removeExistingImage(int index) {
    if (_isSaving) {
      return;
    }

    setState(() {
      _existingImages.removeAt(index);
    });
  }

  // ============================================================
  // SAVE SERVICE
  // ============================================================

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    // ----------------------------------------------------------
    // NAME
    // ----------------------------------------------------------

    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter service name.');
      return;
    }

    // ----------------------------------------------------------
    // CATEGORY
    // ----------------------------------------------------------

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      _showError('Please select a category.');
      return;
    }

    // ----------------------------------------------------------
    // PRICE
    // ----------------------------------------------------------

    final double? price = double.tryParse(_priceController.text.trim());

    if (price == null || price < 0) {
      _showError('Please enter a valid price.');
      return;
    }
    try {
      pricing.validate(price);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    // ----------------------------------------------------------
    // START SAVING
    // ----------------------------------------------------------

    setState(() {
      _isSaving = true;
    });

    final List<String> uploadedPaths = [];

    try {
      final currentUser = widget.supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('You are not logged in.');
      }

      // ========================================================
      // UPLOAD NEW IMAGES
      // ========================================================

      for (int i = 0; i < _newImages.length; i++) {
        final XFile image = _newImages[i];

        final File file = File(image.path);

        final String fileName =
            'image-'
            '${DateTime.now().microsecondsSinceEpoch}'
            '-$i.jpg';

        final String path =
            '${currentUser.id}/'
            '${widget.service.id}/'
            '$fileName';

        await widget.supabase.storage
            .from('service-gallery')
            .upload(
              path,
              file,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        uploadedPaths.add(path);
      }

      // ========================================================
      // CREATE PUBLIC URLS
      // ========================================================

      final List<String> newImageUrls = uploadedPaths.map((String path) {
        return widget.supabase.storage
            .from('service-gallery')
            .getPublicUrl(path);
      }).toList();

      // ========================================================
      // FINAL GALLERY
      // ========================================================

      final List<String> finalGallery = [..._existingImages, ...newImageUrls];

      // ========================================================
      // UPDATE DATABASE
      // ========================================================

      await _repository.updateService(
        service: widget.service,
        name: name,
        categoryNodeId: _selectedCategoryId!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        pricing: pricing,
        price: price,
        gallery: finalGallery,
      );

      // ========================================================
      // FIND REMOVED OLD IMAGES
      // ========================================================

      final Set<String> originalImages = widget.service.gallery.toSet();

      final Set<String> remainingImages = _existingImages.toSet();

      final List<String> removedImages = originalImages
          .difference(remainingImages)
          .toList();

      // ========================================================
      // DELETE REMOVED OLD STORAGE FILES
      // ========================================================

      if (removedImages.isNotEmpty) {
        final List<String> removedPaths = removedImages
            .map(_extractStoragePath)
            .where((String path) => path.isNotEmpty)
            .toList();

        if (removedPaths.isNotEmpty) {
          try {
            await widget.supabase.storage
                .from('service-gallery')
                .remove(removedPaths);
          } catch (_) {
            // Database update already succeeded.
          }
        }
      }

      // ========================================================
      // CLOSE DIALOG
      // ========================================================

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      // ========================================================
      // CLEANUP NEW UPLOADS
      // ========================================================

      if (uploadedPaths.isNotEmpty) {
        try {
          await widget.supabase.storage
              .from('service-gallery')
              .remove(uploadedPaths);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showError(
        'Failed to update service:\n'
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // EXTRACT STORAGE PATH
  // ============================================================

  String _extractStoragePath(String url) {
    try {
      const String marker = '/storage/v1/object/public/service-gallery/';

      final Uri uri = Uri.parse(url);

      final String fullUrl = uri.toString();

      final int index = fullUrl.indexOf(marker);

      if (index == -1) {
        return '';
      }

      final String path = fullUrl.substring(index + marker.length);

      return Uri.decodeComponent(path);
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.edit_service.c7c19d6f",
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ==================================================
            // CONTENT
            // ==================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // NAME
                    // ==========================================

                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.service_name.2133ed9a",
                      ),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: AppSettingsScope.translate(
                          context,
                          "vendor.enter_service_name.717bf07a",
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // CATEGORY
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.category.292c06f0",
                      ),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    _buildCategoryDropdown(),

                    const SizedBox(height: 18),

                    // ==========================================
                    // DESCRIPTION
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.description.526e0087",
                      ),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: AppSettingsScope.translate(
                          context,
                          "vendor.describe_your_service.0f4d39c0",
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // PRICE
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.price.93c91c85",
                      ),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    ServicePricingFields(
                      value: pricing,
                      onChanged: (value) => setState(() => pricing = value),
                    ),

                    TextField(
                      controller: _priceController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        hintText: AppSettingsScope.translate(
                          context,
                          "vendor.enter_price.cec17a55",
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // CURRENT IMAGES
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.current_images.1d0a441f",
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _existingImages.isEmpty
                          ? 'No current images.'
                          : 'Remove images you no longer want.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildExistingImages(),

                    const SizedBox(height: 24),

                    // ==========================================
                    // NEW IMAGES
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.add_new_images.aaa28548",
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.new_images_will_be_cropped_to_16_9.dc0ceafb",
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ImagePickerWidget(
                      images: _newImages,
                      onChanged: (List<XFile> images) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _newImages = images;
                        });
                      },
                      maxImages: 8,
                      cropRatioX: 16,
                      cropRatioY: 9,
                      cropTitle: 'Adjust Service Image',
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // ==================================================
            // ACTIONS
            // ==================================================
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF73737D),
                        side: const BorderSide(color: Color(0xFFE8E5E8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.cancel.19766ed6",
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF80152C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppShimmerIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: AppShimmerIndicator(strokeWidth: 2),
        ),
      );
    }

    final bool categoryExists = _categories.any(
      (Map<String, dynamic> category) =>
          category['id']?.toString() == _selectedCategoryId,
    );

    return DropdownButtonFormField<String>(
      initialValue: categoryExists ? _selectedCategoryId : null,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: AppSettingsScope.translate(
          context,
          "vendor.select_category.e26788c5",
        ),
      ),
      items: _categories.map((Map<String, dynamic> category) {
        final String id = category['id']?.toString() ?? '';

        final String name = category['name']?.toString() ?? 'Unnamed';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (String? value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
    );
  }

  // ============================================================
  // EXISTING IMAGES
  // ============================================================

  Widget _buildExistingImages() {
    if (_existingImages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 36,
              color: AppIconColors.standard,
            ),
            const SizedBox(height: 8),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.no_current_images.9dadfabb",
              ),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _existingImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 16 / 9,
      ),
      itemBuilder: (BuildContext context, int index) {
        final String url = _existingImages[index];

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
              ),
            ),

            // ================================================
            // DELETE IMAGE
            // ================================================
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.65),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isSaving
                      ? null
                      : () {
                          _removeExistingImage(index);
                        },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
