import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../common/app_shimmer.dart';
import '../../models/service_pricing.dart';
import '../../widgets/services/service_pricing_fields.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../edit/image_picker_widget.dart';

class AddServiceDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final ImagePicker imagePicker;

  final VoidCallback onServiceCreated;

  const AddServiceDialog({
    super.key,
    required this.supabase,
    required this.imagePicker,
    required this.onServiceCreated,
  });

  @override
  State<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<AddServiceDialog> {
  ServicePricing pricing = const ServicePricing();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _priceController = TextEditingController();

  // ============================================================
  // CATEGORY
  // ============================================================

  List<Map<String, dynamic>> _categories = [];

  String? _selectedCategoryId;

  bool _isLoadingCategories = true;

  bool _isCreating = false;

  // ============================================================
  // IMAGES
  // ============================================================

  List<XFile> _selectedImages = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

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

      _showError('Failed to load categories: $e');
    }
  }

  // ============================================================
  // CREATE SERVICE
  // ============================================================

  Future<void> _createService() async {
    if (_isCreating) {
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
    // USER
    // ----------------------------------------------------------

    final user = widget.supabase.auth.currentUser;

    if (user == null) {
      _showError('You are not logged in.');
      return;
    }

    // ----------------------------------------------------------
    // START
    // ----------------------------------------------------------

    setState(() {
      _isCreating = true;
    });

    String? serviceId;

    final List<String> uploadedPaths = [];

    try {
      // ========================================================
      // SLUG
      // ========================================================

      final String slug = await _generateUniqueSlug(name);

      // ========================================================
      // CREATE DATABASE ROW
      // ========================================================

      final dynamic inserted = await widget.supabase
          .from('services')
          .insert({
            'vendor_id': user.id,
            'category_node_id': _selectedCategoryId,
            'name': name,
            'slug': slug,
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'price': price,
            ...pricing.toMap(),
            'gallery': [],
            'is_active': true,
          })
          .select('id')
          .single();

      serviceId = inserted['id'].toString();

      // ========================================================
      // UPLOAD CROPPED IMAGES
      // ========================================================

      final List<String> imageUrls = [];

      for (int i = 0; i < _selectedImages.length; i++) {
        final XFile image = _selectedImages[i];

        final File file = File(image.path);

        final String path =
            '${user.id}/'
            '$serviceId/'
            'image-${DateTime.now().microsecondsSinceEpoch}-$i.jpg';

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

        final String url = widget.supabase.storage
            .from('service-gallery')
            .getPublicUrl(path);

        imageUrls.add(url);
      }

      // ========================================================
      // UPDATE GALLERY
      // ========================================================

      await widget.supabase
          .from('services')
          .update({
            'gallery': imageUrls,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('vendor_id', user.id);

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) {
        return;
      }

      widget.onServiceCreated();

      Navigator.of(context).pop(true);
    } catch (e) {
      // ========================================================
      // CLEANUP STORAGE
      // ========================================================

      if (uploadedPaths.isNotEmpty) {
        try {
          await widget.supabase.storage
              .from('service-gallery')
              .remove(uploadedPaths);
        } catch (_) {}
      }

      // ========================================================
      // CLEANUP DATABASE
      // ========================================================

      if (serviceId != null) {
        try {
          await widget.supabase
              .from('services')
              .delete()
              .eq('id', serviceId)
              .eq('vendor_id', user.id);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreating = false;
      });

      _showError('Failed to create service:\n$e');
    }
  }

  // ============================================================
  // UNIQUE SLUG
  // ============================================================

  Future<String> _generateUniqueSlug(String name) async {
    String slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (slug.isEmpty) {
      slug = 'service';
    }

    String finalSlug = slug;

    int counter = 1;

    while (true) {
      final existing = await widget.supabase
          .from('services')
          .select('id')
          .eq('slug', finalSlug)
          .maybeSingle();

      if (existing == null) {
        return finalSlug;
      }

      counter++;

      finalSlug = '$slug-$counter';
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
                        "vendor.add_service.62e79d2a",
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isCreating
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
            // FORM
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
                      enabled: !_isCreating,
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
                      enabled: !_isCreating,
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
                      enabled: !_isCreating,
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
                    // IMAGES
                    // ==========================================
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.service_images.3f04b445",
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
                        "vendor.select_one_or_more_images_each_image_will_ope.0925a105",
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ImagePickerWidget(
                      images: _selectedImages,
                      onChanged: (List<XFile> images) {
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _selectedImages = images;
                        });
                      },
                      maxImages: 8,
                      cropRatioX: 16,
                      cropRatioY: 9,
                      cropTitle: 'Crop Service Image',
                    ),
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
                      onPressed: _isCreating
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
                      onPressed: _isCreating ? null : _createService,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppShimmerIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                        _isCreating ? 'Creating...' : 'Create Service',
                      ),
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

    return DropdownButtonFormField<String>(
      initialValue:
          _categories.any(
            (Map<String, dynamic> category) =>
                category['id']?.toString() == _selectedCategoryId,
          )
          ? _selectedCategoryId
          : null,
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
      onChanged: _isCreating
          ? null
          : (String? value) {
              setState(() {
                _selectedCategoryId = value;
              });
            },
    );
  }
}
