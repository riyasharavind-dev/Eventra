import '../common/app_shimmer.dart';
import '../../models/service_pricing.dart';
import '../../widgets/services/service_pricing_fields.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../edit/image_picker_widget.dart';

class AddServiceDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final ImagePicker imagePicker;
  final Future<void> Function() onServiceCreated;

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
  // IMAGES
  // ============================================================

  List<XFile> _selectedImages = [];

  // ============================================================
  // CATEGORY
  // ============================================================

  List<Map<String, dynamic>> _categories = [];

  String? _selectedCategoryId;

  bool _isLoadingCategories = true;

  String? _categoryError;

  // ============================================================
  // EVENT TYPES
  // ============================================================

  List<Map<String, dynamic>> _eventTypes = [];

  String? _selectedEventTypeId;

  bool _isLoadingEventTypes = true;

  String? _eventTypeError;

  // ============================================================
  // CREATE
  // ============================================================

  bool _isCreating = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCategories();
    _loadEventTypes();
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
    if (!mounted) return;

    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      debugPrint('CATEGORY: Loading category_nodes...');

      final List<dynamic> response = await widget.supabase
          .from('category_nodes')
          .select('id, name, slug, parent_id')
          .order('name', ascending: true);

      debugPrint('CATEGORY: ${response.length} rows found');

      final List<Map<String, dynamic>> categories = response
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e, stackTrace) {
      debugPrint('CATEGORY ERROR: $e');

      debugPrint('CATEGORY STACKTRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoadingCategories = false;
        _categoryError = e.toString();
      });
    }
  }

  // ============================================================
  // LOAD EVENT TYPES
  // ============================================================

  Future<void> _loadEventTypes() async {
    if (!mounted) return;

    setState(() {
      _isLoadingEventTypes = true;
      _eventTypeError = null;
    });

    try {
      debugPrint('EVENT TYPE: Loading event_types...');

      /*
       * IMPORTANT
       *
       * We intentionally DO NOT use:
       *
       * .eq('is_active', true)
       *
       * because you asked for all event types
       * during development.
       *
       * Later we can enable active/inactive filtering.
       */

      final List<dynamic> response = await widget.supabase
          .from('event_types')
          .select(
            'id, name, slug, description, icon, image_url, is_active, sort_order',
          )
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      debugPrint('EVENT TYPE: ${response.length} rows found');

      for (final dynamic item in response) {
        debugPrint('EVENT TYPE: ${item['name']}');
      }

      final List<Map<String, dynamic>> eventTypes = response
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        _eventTypes = eventTypes;
        _isLoadingEventTypes = false;
      });
    } catch (e, stackTrace) {
      debugPrint('EVENT TYPE ERROR: $e');

      debugPrint('EVENT TYPE STACKTRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoadingEventTypes = false;
        _eventTypeError = e.toString();
      });
    }
  }

  // ============================================================
  // SELECT EVENT TYPE
  // ============================================================

  void _selectEventType(String id) {
    if (_isCreating) return;

    debugPrint('EVENT TYPE SELECTED: $id');

    setState(() {
      _selectedEventTypeId = id;
    });
  }

  // ============================================================
  // CREATE SERVICE
  // ============================================================

  Future<void> _createService() async {
    FocusScope.of(context).unfocus();

    // ==========================================================
    // FORM VALUES
    // ==========================================================

    final String name = _nameController.text.trim();

    final String description = _descriptionController.text.trim();

    final String priceText = _priceController.text.trim();

    final double? price = double.tryParse(priceText);

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (name.isEmpty) {
      _showError('Please enter service name.');
      return;
    }

    if (_selectedCategoryId == null) {
      _showError('Please select a category.');
      return;
    }

    if (_selectedEventTypeId == null) {
      _showError('Please select an event type.');
      return;
    }

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

    if (_selectedImages.isEmpty) {
      _showError('Please select at least one image.');
      return;
    }

    // ==========================================================
    // CURRENT USER
    // ==========================================================

    final user = widget.supabase.auth.currentUser;

    if (user == null) {
      _showError('User session expired. Please login again.');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    String? serviceId;

    final List<String> uploadedPaths = [];

    try {
      // ========================================================
      // CREATE UNIQUE SLUG
      // ========================================================

      final String slug = await _generateUniqueSlug(name);

      debugPrint('SERVICE: Creating service');

      debugPrint('SERVICE: vendor_id = ${user.id}');

      debugPrint('SERVICE: category_node_id = $_selectedCategoryId');

      debugPrint('SERVICE: event_type_id = $_selectedEventTypeId');

      // ========================================================
      // INSERT SERVICE
      // ========================================================

      final Map<String, dynamic> inserted = await widget.supabase
          .from('services')
          .insert({
            'vendor_id': user.id,

            'category_node_id': _selectedCategoryId,

            'event_type_id': _selectedEventTypeId,

            'name': name,

            'slug': slug,

            'description': description.isEmpty ? null : description,

            'price': price,
            ...pricing.toMap(),

            'gallery': [],

            'is_active': true,
          })
          .select('id')
          .single();

      serviceId = inserted['id'].toString();

      debugPrint('SERVICE CREATED: $serviceId');

      // ========================================================
      // UPLOAD IMAGES
      // ========================================================

      final List<String> publicUrls = [];

      for (int index = 0; index < _selectedImages.length; index++) {
        final XFile image = _selectedImages[index];

        final String fileName =
            'image-${DateTime.now().millisecondsSinceEpoch}-$index.jpg';

        final String storagePath = '${user.id}/$serviceId/$fileName';

        final bytes = await image.readAsBytes();

        debugPrint('IMAGE UPLOAD: $storagePath');

        await widget.supabase.storage
            .from('service-gallery')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        uploadedPaths.add(storagePath);

        final String publicUrl = widget.supabase.storage
            .from('service-gallery')
            .getPublicUrl(storagePath);

        publicUrls.add(publicUrl);
      }

      // ========================================================
      // UPDATE GALLERY
      // ========================================================

      await widget.supabase
          .from('services')
          .update({
            'gallery': publicUrls,

            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', serviceId);

      debugPrint('SERVICE: Gallery updated');

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) return;

      await widget.onServiceCreated();

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('CREATE SERVICE ERROR: $e');

      debugPrint('CREATE SERVICE STACKTRACE: $stackTrace');

      // ========================================================
      // CLEANUP STORAGE
      // ========================================================

      if (uploadedPaths.isNotEmpty) {
        try {
          await widget.supabase.storage
              .from('service-gallery')
              .remove(uploadedPaths);
        } catch (cleanupError) {
          debugPrint('STORAGE CLEANUP ERROR: $cleanupError');
        }
      }

      // ========================================================
      // CLEANUP DATABASE
      // ========================================================

      if (serviceId != null) {
        try {
          await widget.supabase.from('services').delete().eq('id', serviceId);
        } catch (cleanupError) {
          debugPrint('DATABASE CLEANUP ERROR: $cleanupError');
        }
      }

      if (!mounted) return;

      setState(() {
        _isCreating = false;
      });

      _showError(_cleanError(e));
    }
  }

  // ============================================================
  // UNIQUE SLUG
  // ============================================================

  Future<String> _generateUniqueSlug(String name) async {
    String baseSlug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (baseSlug.isEmpty) {
      baseSlug = 'service';
    }

    String slug = baseSlug;

    int counter = 1;

    while (true) {
      final List<dynamic> existing = await widget.supabase
          .from('services')
          .select('id')
          .eq('slug', slug)
          .limit(1);

      if (existing.isEmpty) {
        return slug;
      }

      counter++;

      slug = '$baseSlug-$counter';
    }
  }

  // ============================================================
  // EVENT TYPE UI
  // ============================================================

  Widget _buildEventTypeSection() {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoadingEventTypes) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(vertical: 22),

        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),

          borderRadius: BorderRadius.circular(12),
        ),

        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            SizedBox(
              width: 20,
              height: 20,

              child: AppShimmerIndicator(strokeWidth: 2),
            ),

            SizedBox(width: 10),

            Text('Loading event types...'),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_eventTypeError != null) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.red.shade50,

          border: Border.all(color: Colors.red.shade200),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),

                const SizedBox(width: 8),

                const Expanded(
                  child: Text(
                    'Failed to load event types.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _eventTypeError!,

              maxLines: 5,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _loadEventTypes,

              icon: const Icon(Icons.refresh),

              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (_eventTypes.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.orange.shade50,

          border: Border.all(color: Colors.orange.shade200),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),

            const SizedBox(width: 8),

            const Expanded(
              child: Text('No event types found in the database.'),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // EVENT TYPE LIST
    // ----------------------------------------------------------

    return Wrap(
      spacing: 10,

      runSpacing: 10,

      children: _eventTypes.map((Map<String, dynamic> eventType) {
        final String id = eventType['id']?.toString() ?? '';

        final String name = eventType['name']?.toString() ?? 'Unnamed';

        final String icon = eventType['icon']?.toString() ?? '';

        final bool selected = _selectedEventTypeId == id;

        return InkWell(
          borderRadius: BorderRadius.circular(12),

          onTap: _isCreating
              ? null
              : () {
                  _selectEventType(id);
                },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),

            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.10)
                  : Theme.of(context).colorScheme.surface,

              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,

                width: selected ? 1.5 : 1,
              ),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                if (icon.isNotEmpty)
                  Text(icon, style: const TextStyle(fontSize: 17))
                else
                  Icon(
                    Icons.event_outlined,

                    size: 18,

                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade700,
                  ),

                const SizedBox(width: 7),

                Text(
                  name,

                  style: TextStyle(
                    fontSize: 13,

                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,

                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black87,
                  ),
                ),

                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),

                    child: Icon(
                      Icons.check_circle,

                      size: 16,

                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown() {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoadingCategories) {
      return Container(
        height: 56,

        alignment: Alignment.center,

        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),

          borderRadius: BorderRadius.circular(8),
        ),

        child: const SizedBox(
          width: 20,

          height: 20,

          child: AppShimmerIndicator(strokeWidth: 2),
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_categoryError != null) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.red.shade50,

          borderRadius: BorderRadius.circular(8),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Unable to load categories.',

              style: TextStyle(
                color: Colors.red.shade700,

                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _categoryError!,

              maxLines: 4,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _loadCategories,

              icon: const Icon(Icons.refresh),

              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (_categories.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.orange.shade50,

          border: Border.all(color: Colors.orange.shade200),

          borderRadius: BorderRadius.circular(8),
        ),

        child: const Text('No categories found in category_nodes.'),
      );
    }

    // ----------------------------------------------------------
    // DROPDOWN
    // ----------------------------------------------------------

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,

      isExpanded: true,

      decoration: const InputDecoration(
        hintText: 'Select category',

        prefixIcon: Icon(Icons.category_outlined),

        border: OutlineInputBorder(),
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

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

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
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Text(
      text,

      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 800),

        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),

              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add Service',

                      style: TextStyle(
                        fontSize: 21,

                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: _isCreating
                        ? null
                        : () {
                            Navigator.pop(context);
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // SERVICE NAME
                    // ==========================================

                    _buildLabel('Service Name'),

                    const SizedBox(height: 7),

                    TextField(
                      controller: _nameController,

                      enabled: !_isCreating,

                      textInputAction: TextInputAction.next,

                      decoration: const InputDecoration(
                        hintText: 'Enter service name',

                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // CATEGORY
                    // ==========================================
                    _buildLabel('Category'),

                    const SizedBox(height: 7),

                    _buildCategoryDropdown(),

                    const SizedBox(height: 20),

                    // ==========================================
                    // EVENT TYPE
                    // ==========================================
                    _buildLabel('Event Type'),

                    const SizedBox(height: 5),

                    Text(
                      'Select the event this service is suitable for',

                      style: TextStyle(
                        fontSize: 12,

                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildEventTypeSection(),

                    const SizedBox(height: 20),

                    // ==========================================
                    // DESCRIPTION
                    // ==========================================
                    _buildLabel('Description'),

                    const SizedBox(height: 7),

                    TextField(
                      controller: _descriptionController,

                      enabled: !_isCreating,

                      maxLines: 3,

                      decoration: const InputDecoration(
                        hintText: 'Describe your service',

                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // PRICE
                    // ==========================================
                    _buildLabel('Price'),

                    const SizedBox(height: 7),

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

                      decoration: const InputDecoration(
                        prefixText: '₹ ',

                        hintText: 'Enter price',

                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==========================================
                    // IMAGES
                    // ==========================================
                    IgnorePointer(
                      ignoring: _isCreating,

                      child: ImagePickerWidget(
                        images: _selectedImages,

                        onChanged: (List<XFile> images) {
                          setState(() {
                            _selectedImages = images;
                          });
                        },

                        maxImages: 8,

                        cropRatioX: 16,

                        cropRatioY: 9,

                        cropTitle: 'Adjust Service Image',
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // CREATE
                    // ==========================================
                    SizedBox(
                      width: double.infinity,

                      height: 52,

                      child: FilledButton.icon(
                        onPressed: _isCreating ? null : _createService,

                        icon: _isCreating
                            ? const SizedBox(
                                width: 19,

                                height: 19,

                                child: AppShimmerIndicator(
                                  strokeWidth: 2,

                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_business_outlined),

                        label: Text(
                          _isCreating
                              ? 'Creating Service...'
                              : 'Create Service',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
