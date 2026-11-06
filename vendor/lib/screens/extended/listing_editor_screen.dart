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
  String t(String en, String ta) => listingText(context, en, ta);
  String get uid =>
      db.auth.currentUser?.id ??
      (throw StateError(t('Please sign in again.', 'மீண்டும் உள்நுழையவும்.')));
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
            t(
              'Each image must be smaller than 8 MB.',
              'ஒவ்வொரு படமும் 8 MB-க்கு குறைவாக இருக்க வேண்டும்.',
            ),
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
            t(
              'Choose JPG, PNG or WebP images.',
              'JPG, PNG அல்லது WebP படங்களைத் தேர்வு செய்யவும்.',
            ),
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
        t(
          'Choose a business and eligible category.',
          'வணிகம் மற்றும் பொருத்தமான வகையைத் தேர்வு செய்யவும்.',
        ),
      );
      return;
    }
    final amount = double.tryParse(price.text.trim().replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount < 0) {
      listingError(
        context,
        t('Enter a valid price.', 'சரியான விலையை உள்ளிடவும்.'),
      );
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
          t(
            'This service was removed. Return and refresh.',
            'இந்த சேவை நீக்கப்பட்டது. திரும்பிச் சென்று புதுப்பிக்கவும்.',
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
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (required && (v?.trim().isEmpty ?? true)) {
          return t('Required', 'கட்டாயம்');
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.service == null
                ? t('Add Service', 'சேவை சேர்')
                : t('Edit Service', 'சேவையைத் திருத்து'),
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
                  t('Photos & cover', 'புகைப்படங்கள் மற்றும் அட்டைப்படம்'),
                  key: galleryKey,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'First photo is the cover. Changes apply when you save.',
                    'முதல் படம் அட்டைப்படம். சேமிக்கும்போது மாற்றங்கள் செயல்படும்.',
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    picking
                        ? t('Reading images…', 'படங்களை ஏற்றுகிறது…')
                        : t('Add photos', 'புகைப்படங்கள் சேர்'),
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
                                  label: Text(t('Cover photo', 'அட்டைப்படம்')),
                                ),
                              if (index != 0)
                                TextButton(
                                  onPressed: () => setState(() {
                                    photos.removeAt(index);
                                    photos.insert(0, photo);
                                  }),
                                  child: Text(
                                    t('Set as cover', 'அட்டைப்படமாக வை'),
                                  ),
                                ),
                              IconButton(
                                tooltip: t('Move earlier', 'முன்னால் நகர்த்து'),
                                onPressed: index == 0
                                    ? null
                                    : () => setState(() {
                                        photos.removeAt(index);
                                        photos.insert(index - 1, photo);
                                      }),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: t('Move later', 'பின்னால் நகர்த்து'),
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
                                  t('Remove', 'நீக்கு'),
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
                      t(
                        'Could not load businesses.',
                        'வணிகங்களை ஏற்ற முடியவில்லை.',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: loadBusinesses,
                      child: Text(t('Retry', 'மீண்டும் முயற்சி')),
                    ),
                  ),
                if (!loading && businessError == null && businesses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      t(
                        'No active business found. Create a business first.',
                        'செயலில் உள்ள வணிகம் இல்லை. முதலில் வணிகத்தை உருவாக்கவும்.',
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
                    labelText: t('Business', 'வணிகம்'),
                    border: const OutlineInputBorder(),
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
                      ? t('Select business', 'வணிகத்தைத் தேர்வு செய்')
                      : null,
                ),
                const SizedBox(height: 18),
                if (loadingCategories) const ShimmerLoadingBar(),
                if (categoryError != null)
                  ListTile(
                    title: Text(
                      t(
                        'Could not load categories.',
                        'வகைகளை ஏற்ற முடியவில்லை.',
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: businessId == null
                          ? null
                          : () => selectBusiness(businessId),
                      child: Text(t('Retry', 'மீண்டும் முயற்சி')),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'category-$businessId-$categoryId-${categories.length}',
                  ),
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t('Category', 'வகை'),
                    border: const OutlineInputBorder(),
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
                      ? t('Select category', 'வகையைத் தேர்வு செய்')
                      : null,
                ),
                if (businessId != null &&
                    !loadingCategories &&
                    categoryError == null &&
                    categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t(
                        'No child categories are available for this business.',
                        'இந்த வணிகத்திற்கு துணை வகைகள் இல்லை.',
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                field(
                  name,
                  t('Service name', 'சேவையின் பெயர்'),
                  required: true,
                ),
                ServicePricingFields(
                  value: pricing,
                  onChanged: (value) => setState(() => pricing = value),
                ),
                field(
                  price,
                  t('Price (INR)', 'விலை (ரூபாய்)'),
                  required: true,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                field(description, t('Description', 'விளக்கம்'), lines: 5),
                if (saving) ...[
                  const ShimmerLoadingBar(),
                  const SizedBox(height: 8),
                  Text(
                    '${t('Saving photos', 'படங்கள் சேமிக்கப்படுகின்றன')}: $uploadedCount / ${photos.length}',
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
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
                        ? t('Saving…', 'சேமிக்கிறது…')
                        : t('Save service', 'சேவையைச் சேமி'),
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
