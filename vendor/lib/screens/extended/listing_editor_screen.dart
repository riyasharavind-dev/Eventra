import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../models/service_pricing.dart';
import '../../widgets/services/service_pricing_fields.dart';
import '../../widgets/profile_image_cropper.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/category_node_model.dart';
import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/listings/listing_ui.dart';

String _listingId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _ListingPhoto {
  String? url;
  final Uint8List? bytes;
  final String? extension, mime;
  _ListingPhoto.remote(this.url) : bytes = null, extension = null, mime = null;
  _ListingPhoto.local(this.bytes, this.extension, this.mime);
}

class ListingEditorScreen extends StatefulWidget {
  final ServiceModel? service;
  final SupabaseClient? client;
  final bool focusGallery;
  const ListingEditorScreen({
    super.key,
    this.service,
    this.client,
    this.focusGallery = false,
  });
  @override
  State<ListingEditorScreen> createState() => _ListingEditorScreenState();
}

class _ListingEditorScreenState extends State<ListingEditorScreen> {
  late final SupabaseClient db;
  late final ServiceRepository repo;
  final form = GlobalKey<FormState>();
  final galleryKey = GlobalKey();
  late final TextEditingController name, description, price;
  late final String id;
  final photos = <_ListingPhoto>[];
  List<Map<String, dynamic>> businesses = [];
  List<CategoryNodeModel> categories = [];
  ServicePricing pricing = const ServicePricing();
  String? businessId, categoryId;
  bool loading = true,
      loadingCategories = false,
      saving = false,
      picking = false;
  Object? businessError, categoryError;
  int categoryGeneration = 0, uploadedCount = 0;
  String t(String en) => AppSettingsScope.source(context, en);
  String get uid =>
      db.auth.currentUser?.id ??
      (throw StateError(
        AppSettingsScope.translate(
          context,
          "vendor.please_sign_in_again.2e1d1833",
        ),
      ));
  @override
  void initState() {
    super.initState();
    db = widget.client ?? Supabase.instance.client;
    repo = ServiceRepository(supabase: db);
    final s = widget.service;
    pricing = s?.pricing ?? const ServicePricing();
    id = s?.id ?? _listingId();
    businessId = s?.businessId;
    categoryId = s?.categoryNodeId;
    name = TextEditingController(text: s?.name ?? '');
    description = TextEditingController(text: s?.description ?? '');
    price = TextEditingController(text: s?.price.toString() ?? '');
    photos.addAll((s?.gallery ?? []).map(_ListingPhoto.remote));
    loadBusinesses();
    if (widget.focusGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && galleryKey.currentContext != null) {
          Scrollable.ensureVisible(
            galleryKey.currentContext!,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> loadBusinesses() async {
    setState(() {
      loading = true;
      businessError = null;
    });
    try {
      // Same creation rule as the original screen: this vendor's active businesses.
      final rows = List<Map<String, dynamic>>.from(
        await db
            .from('businesses')
            .select('id,name')
            .eq('vendor_id', uid)
            .eq('is_active', true)
            .order('name'),
      );
      // Editing an existing listing must not silently clear its current business.
      final current = widget.service?.businessId;
      if (current != null && !rows.any((b) => b['id'] == current)) {
        final existing = await db
            .from('businesses')
            .select('id,name')
            .eq('id', current)
            .eq('vendor_id', uid)
            .maybeSingle();
        if (existing != null) {
          rows.add(existing);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        businesses = rows;
        loading = false;
      });
      if (businessId != null) {
        await selectBusiness(businessId, keepCategory: true);
      } else if (widget.service == null && rows.length == 1) {
        await selectBusiness(rows.single['id'] as String);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          businessError = e;
          loading = false;
        });
      }
    }
  }

  Future<void> selectBusiness(
    String? value, {
    bool keepCategory = false,
  }) async {
    final request = ++categoryGeneration;
    final previous = keepCategory ? categoryId : null;
    setState(() {
      businessId = value;
      categoryId = null;
      categories = [];
      categoryError = null;
      loadingCategories = value != null;
    });
    if (value == null) {
      return;
    }
    try {
      final assigned = await db
          .from('business_category_nodes')
          .select('category_nodes(id,name,slug,parent_id,created_at)')
          .eq('business_id', value);
      final nodes = assigned
          .where((r) => r['category_nodes'] is Map)
          .map(
            (r) => CategoryNodeModel.fromMap(
              Map<String, dynamic>.from(r['category_nodes'] as Map),
            ),
          )
          .toList();
      final roots = nodes
          .where((n) => n.parentId == null)
          .map((n) => n.id)
          .toList();
      final children = <CategoryNodeModel>[];
      if (roots.isNotEmpty) {
        final rows = await db
            .from('category_nodes')
            .select('id,name,slug,parent_id,created_at')
            .inFilter('parent_id', roots)
            .order('name');
        children.addAll(rows.map(CategoryNodeModel.fromMap));
      }
      // EXACT original eligibility: direct children of assigned roots PLUS directly
      // assigned non-root nodes. No extra descendants or root fallback is added.
      final unique = {
        for (final n in children) n.id: n,
        for (final n in nodes.where((n) => n.parentId != null)) n.id: n,
      };
      final allowed = unique.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted || request != categoryGeneration || value != businessId) {
        return;
      }
      setState(() {
        categories = allowed;
        categoryId = allowed.any((n) => n.id == previous) ? previous : null;
        loadingCategories = false;
      });
    } catch (e) {
      if (mounted && request == categoryGeneration && value == businessId) {
        setState(() {
          categoryError = e;
          loadingCategories = false;
        });
      }
    }
  }

  Future<void> pickPhotos() async {
    final l10n = AppSettingsScope.localizationOf(context);
    if (picking || saving) {
      return;
    }
    setState(() => picking = true);
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1800,
        imageQuality: 85,
      );

      for (final file in files) {
        if (!mounted) return;
        final cropped = await ProfileImageCropper.cropService(context, file);
        if (!mounted) return;
        if (cropped == null) continue;
        final bytes = await cropped.readAsBytes();
        if (bytes.length > 8 * 1024 * 1024) {
          throw StateError(
            l10n.tr("vendor.each_image_must_be_smaller_than_8_mb.fc4d8ec8"),
          );
        }
        String extension, mime;
        if (bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255) {
          extension = 'jpg';
          mime = 'image/jpeg';
        } else if (bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71) {
          extension = 'png';
          mime = 'image/png';
        } else if (bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
          extension = 'webp';
          mime = 'image/webp';
        } else {
          throw StateError(
            l10n.tr("vendor.choose_jpg_png_or_webp_images.a2685523"),
          );
        }
        setState(() => photos.add(_ListingPhoto.local(bytes, extension, mime)));
      }
    } catch (e) {
      if (mounted) {
        listingError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => picking = false);
      }
    }
  }

  Future<void> save() async {
    final l10n = AppSettingsScope.localizationOf(context);
    if (saving || picking || loading || loadingCategories) {
      return;
    }
    if (!form.currentState!.validate()) {
      return;
    }
    if (businessId == null ||
        categoryId == null ||
        !categories.any((c) => c.id == categoryId)) {
      listingError(
        context,
        l10n.tr("vendor.choose_a_business_and_eligible_category.57992895"),
      );
      return;
    }
    final amount = double.tryParse(price.text.trim().replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount < 0) {
      listingError(context, l10n.tr("vendor.enter_a_valid_price.d9a7f498"));
      return;
    }
    try {
      pricing.validate(amount);
    } catch (e) {
      listingError(context, e);
      return;
    }
    setState(() {
      saving = true;
      uploadedCount = 0;
    });
    try {
      final user = uid;
      // Keep uploaded URLs after failure so Save retries do not re-upload photos.
      for (final photo in photos) {
        if (photo.url == null) {
          final path = 'services/$user/$id/${_listingId()}.${photo.extension}';
          await db.storage
              .from('service-gallery')
              .uploadBinary(
                path,
                photo.bytes!,
                fileOptions: FileOptions(contentType: photo.mime),
              );
          photo.url = db.storage.from('service-gallery').getPublicUrl(path);
        }
        if (mounted) {
          setState(() => uploadedCount++);
        }
      }
      final gallery = photos.map((p) => p.url!).toList();
      final existing = await repo.getServiceById(id);
      if (widget.service != null && existing == null) {
        throw StateError(
          l10n.tr(
            "vendor.this_service_was_removed_return_and_refresh.64f13278",
          ),
        );
      }
      if (existing != null) {
        await repo.updateService(
          service: existing,
          name: name.text.trim(),
          categoryNodeId: categoryId!,
          businessId: businessId,
          eventTypeId: existing.eventTypeId,
          description: description.text.trim().isEmpty
              ? null
              : description.text.trim(),
          price: amount,
          pricing: pricing,
          gallery: gallery,
        );
      } else {
        final slugName = name.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        await db.from('services').insert({
          'id': id,
          'vendor_id': user,
          'business_id': businessId,
          'category_node_id': categoryId,
          'name': name.text.trim(),
          'slug': '${slugName.isEmpty ? 'service' : slugName}-$id',
          'description': description.text.trim().isEmpty
              ? null
              : description.text.trim(),
          'price': amount,
          ...pricing.toMap(),
          'gallery': gallery,
          'is_active': true,
        });
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        listingError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF80152C), width: 1.4),
        ),
      ),
      validator: (v) {
        if (required && (v?.trim().isEmpty ?? true)) {
          return AppSettingsScope.translate(
            context,
            "vendor.required.4850b174",
          );
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !saving && !picking,
      child: VendorPageScaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Text(
            widget.service == null
                ? AppSettingsScope.translate(
                    context,
                    "vendor.add_service.62e79d2a",
                  )
                : AppSettingsScope.translate(
                    context,
                    "vendor.edit_service.c7c19d6f",
                  ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        body: AbsorbPointer(
          absorbing: saving || picking,
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.photos_cover.c30e0f29",
                  ),
                  key: galleryKey,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.first_photo_is_the_cover_changes_apply_when_y.377eef61",
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF73737D),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: pickPhotos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF80152C),
                    side: const BorderSide(color: Color(0xFF80152C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    picking
                        ? AppSettingsScope.translate(
                            context,
                            "vendor.reading_images.3bde4d3b",
                          )
                        : AppSettingsScope.translate(
                            context,
                            "vendor.add_photos.7b0a3d74",
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                ...photos.asMap().entries.map((entry) {
                  final index = entry.key, photo = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: photo.bytes == null
                                ? listingPhoto(
                                    photo.url,
                                    width: double.infinity,
                                    height: 170,
                                  )
                                : Image.memory(
                                    photo.bytes!,
                                    height: 170,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (index == 0)
                                Chip(
                                  label: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.cover_photo.0b91fdc2",
                                    ),
                                  ),
                                ),
                              if (index != 0)
                                TextButton(
                                  onPressed: () => setState(() {
                                    photos.removeAt(index);
                                    photos.insert(0, photo);
                                  }),
                                  child: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.set_as_cover.1a1cff92",
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: AppSettingsScope.translate(
                                  context,
                                  "vendor.move_earlier.736612d4",
                                ),
                                onPressed: index == 0
                                    ? null
                                    : () => setState(() {
                                        photos.removeAt(index);
                                        photos.insert(index - 1, photo);
                                      }),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: AppSettingsScope.translate(
                                  context,
                                  "vendor.move_later.d6e85608",
                                ),
                                onPressed: index == photos.length - 1
                                    ? null
                                    : () => setState(() {
                                        photos.removeAt(index);
                                        photos.insert(index + 1, photo);
                                      }),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => photos.removeAt(index)),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: colors.error,
                                ),
                                label: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.remove.c3812fc4",
                                  ),
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 22),
                if (loading) const ShimmerLoadingBar(),
                if (businessError != null)
                  ListTile(
                    title: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.could_not_load_businesses.9f0d74a9",
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: loadBusinesses,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.retry.942087cc",
                        ),
                      ),
                    ),
                  ),
                if (!loading && businessError == null && businesses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.no_active_business_found_create_a_business_fi.e39326b5",
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey('business-$businessId-${businesses.length}'),
                  initialValue: businesses.any((b) => b['id'] == businessId)
                      ? businessId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppSettingsScope.translate(
                      context,
                      "vendor.business.76f68a75",
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF80152C),
                        width: 1.4,
                      ),
                    ),
                  ),
                  items: businesses
                      .map(
                        (b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text(
                            b['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: loading ? null : (v) => selectBusiness(v),
                  validator: (v) => v == null
                      ? AppSettingsScope.translate(
                          context,
                          "vendor.select_business.f80cfed3",
                        )
                      : null,
                ),
                const SizedBox(height: 18),
                if (loadingCategories) const ShimmerLoadingBar(),
                if (categoryError != null)
                  ListTile(
                    title: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.could_not_load_categories.0a34a8fe",
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: businessId == null
                          ? null
                          : () => selectBusiness(businessId),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.retry.942087cc",
                        ),
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'category-$businessId-$categoryId-${categories.length}',
                  ),
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppSettingsScope.translate(
                      context,
                      "vendor.category.292c06f0",
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF80152C),
                        width: 1.4,
                      ),
                    ),
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: loadingCategories || businessId == null
                      ? null
                      : (v) => setState(() => categoryId = v),
                  validator: (v) => v == null
                      ? AppSettingsScope.translate(
                          context,
                          "vendor.select_category.e26788c5",
                        )
                      : null,
                ),
                if (businessId != null &&
                    !loadingCategories &&
                    categoryError == null &&
                    categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.no_child_categories_are_available_for_this_bu.4bc38f75",
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                field(
                  name,
                  AppSettingsScope.translate(
                    context,
                    "vendor.service_name.1bb8870c",
                  ),
                  required: true,
                ),
                ServicePricingFields(
                  value: pricing,
                  onChanged: (value) => setState(() => pricing = value),
                ),
                field(
                  price,
                  AppSettingsScope.translate(
                    context,
                    "vendor.price_inr.06cf5831",
                  ),
                  required: true,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                field(
                  description,
                  AppSettingsScope.translate(
                    context,
                    "vendor.description.526e0087",
                  ),
                  lines: 5,
                ),
                if (saving) ...[
                  const ShimmerLoadingBar(),
                  const SizedBox(height: 8),
                  Text(
                    '${AppSettingsScope.translate(context, "vendor.saving_photos.5a21dd22")}: $uploadedCount / ${photos.length}',
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        loading ||
                            loadingCategories ||
                            businessError != null ||
                            categoryError != null ||
                            saving ||
                            picking
                        ? null
                        : save,
                    icon: const Icon(Icons.check),
                    label: Text(
                      saving
                          ? AppSettingsScope.translate(
                              context,
                              "vendor.saving.23e39291",
                            )
                          : AppSettingsScope.translate(
                              context,
                              "vendor.save_service.c699ff1a",
                            ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
