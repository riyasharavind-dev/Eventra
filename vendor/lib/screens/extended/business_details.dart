import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../models/service_pricing.dart';

import 'package:latlong2/latlong.dart';

import '../../models/administrative_region.dart';
import '../../widgets/administrative_region_picker.dart';
import '../../widgets/profile_image_cropper.dart';
import 'shop_location_picker.dart';

import 'package:flutter/material.dart';

import '../../widgets/reviews/review_rating_card.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/business_model.dart';
import '../../repositories/business_workspace_repository.dart';
import 'business_service_editor.dart';

// Business categories use roots only. Services keep the full category tree.
String businessRootCategory(String id, List<Map<String, dynamic>> nodes) {
  final byId = {for (final node in nodes) node['id'] as String: node};
  final visited = <String>{};
  var current = id;
  while (visited.add(current)) {
    final node = byId[current];
    if (node == null) {
      throw StateError('A saved category is missing. Please contact support.');
    }
    final parent = node['parent_id'] as String?;
    if (parent == null) {
      return current;
    }
    current = parent;
  }
  throw StateError('Invalid category hierarchy. Please contact support.');
}

void businessError(BuildContext context, Object error) {
  final text = error.toString().replaceFirst('Bad state: ', '');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget businessImage(String? url, {double height = 150}) =>
    url == null || url.isEmpty
    ? SizedBox(
        height: height,
        child: const Center(child: Icon(Icons.storefront_outlined, size: 48)),
      )
    : Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => SizedBox(
          height: height,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );

class BusinessDetailsScreen extends StatefulWidget {
  final List<BusinessModel> businesses;
  const BusinessDetailsScreen({super.key, this.businesses = const []});
  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final repo = BusinessWorkspaceRepository();
  late Future<List<BusinessModel>> loading;

  @override
  void initState() {
    super.initState();
    loading = repo.list();
  }

  Future<void> refresh() async {
    setState(() {
      loading = repo.list();
    });
    try {
      await loading;
    } catch (_) {
      /* The FutureBuilder displays retry. */
    }
  }

  Future<void> open(BusinessModel? business) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => business == null
            ? const AddBusinessScreen()
            : BusinessSingleDetailsScreen(business: business),
      ),
    );
    if (mounted) {
      await refresh();
    }
  }

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    appBar: AppBar(title: const Text('My Businesses')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => open(null),
      icon: const Icon(Icons.add),
      label: const Text('Add business'),
    ),
    body: FutureBuilder<List<BusinessModel>>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load businesses.'),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: AppContentSkeleton(layout: SkeletonLayout.listings),
          );
        }
        final all = snapshot.data!;
        final rows = all;
        return AppShimmerRefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'One vendor. All your businesses.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage each business with its own categories, services, contact details and shop location.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Add your first business to get started.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ...rows.map(
                (b) => Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => open(b),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        businessImage(b.bannerUrl ?? b.logoUrl),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: ReviewRatingCard(
                            businessId: b.id,
                            vendorMode: true,
                            compact: true,
                            refreshKey: loading,
                          ),
                        ),
                        ListTile(
                          title: Text(b.name),
                          subtitle: Text(b.shopAddress ?? b.address ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AddBusinessScreen extends StatefulWidget {
  final BusinessModel? business;
  final BusinessWorkspaceRepository? repository;
  const AddBusinessScreen({super.key, this.business, this.repository});
  @override
  State<AddBusinessScreen> createState() => _AddBusinessScreenState();
}

class _AddBusinessScreenState extends State<AddBusinessScreen> {
  late final BusinessWorkspaceRepository repo;
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late final String id;
  List<Map<String, dynamic>> categories = [];
  final Set<String> selected = {};
  String? primary, logo, banner;

  bool busy = false, loading = true;
  List<AdministrativeRegion> states = [], districts = [], subdistricts = [];
  bool regionsLoading = false;
  String? stateId, districtId, subdistrictId;

  Object? loadError;

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? BusinessWorkspaceRepository();
    final b = widget.business;
    id = b?.id ?? BusinessWorkspaceRepository.newId();
    final data = b?.toMap() ?? <String, dynamic>{};
    for (final key in [
      'name',
      'description',
      'phone',
      'whatsapp',
      'email',
      'address',
      'latitude',
      'longitude',
      'started_year',
      'website_url',
      'instagram_url',
    ]) {
      fields[key] = TextEditingController(text: data[key]?.toString() ?? '');
    }
    primary = b?.primaryCategoryId;
    logo = b?.logoUrl;
    banner = b?.bannerUrl;
    stateId = b?.shopStateId;
    districtId = b?.shopDistrictId;
    subdistrictId = b?.shopSubdistrictId;

    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final allCategories = await repo.categories();
      states = await repo.regions(level: 'state');
      if (stateId != null) {
        districts = await repo.regions(level: 'district', parentId: stateId);
      }
      if (districtId != null) {
        subdistricts = await repo.regions(
          level: 'subdistrict',
          parentId: districtId,
        );
      }
      final savedIds = widget.business == null
          ? <String>[]
          : await repo.categoryIds(id);
      // Older child selections become their top-level business category.
      // Saving the form persists these root IDs atomically.
      final roots = savedIds
          .map((categoryId) => businessRootCategory(categoryId, allCategories))
          .toSet();
      final savedPrimary = widget.business?.primaryCategoryId;
      final rootPrimary = savedPrimary == null
          ? null
          : businessRootCategory(savedPrimary, allCategories);
      categories = allCategories.where((c) => c['parent_id'] == null).toList();
      selected
        ..clear()
        ..addAll(roots);
      primary = roots.contains(rootPrimary) ? rootPrimary : roots.firstOrNull;
    } catch (e) {
      loadError = e;
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  String? optional(String key) => value(key).isEmpty ? null : value(key);
  String categoryLabel(Map<String, dynamic> c) {
    return c['name'].toString();
  }

  bool webUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.contains('.');
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    bool required = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: fields[key],
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (raw) {
        final v = raw?.trim() ?? '';
        if (required && v.length < 2) {
          return 'Enter at least 2 characters';
        }
        if (key == 'address' && v.length < 5) {
          return 'Enter your full shop address';
        }
        if (v.isEmpty) {
          return null;
        }
        if (key == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
          return 'Enter a valid email';
        }
        if (['website_url', 'instagram_url'].contains(key) && !webUrl(v)) {
          return 'Enter a full https:// link';
        }
        if (['phone', 'whatsapp'].contains(key) &&
            !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(v)) {
          return 'Enter a valid number with country code';
        }
        if (key == 'started_year') {
          final y = int.tryParse(v);
          if (y == null || y < 1900 || y > DateTime.now().year) {
            return 'Enter a year from 1900 to ${DateTime.now().year}';
          }
        }
        if (['latitude', 'longitude'].contains(key)) {
          final n = double.tryParse(v);
          final max = key == 'latitude' ? 90 : 180;
          if (n == null || !n.isFinite || n.abs() > max) {
            return 'Enter a value between -$max and $max';
          }
        }
        return null;
      },
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 14),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Future<void> image(String type) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 88,
      );
      if (file == null) {
        return;
      }
      if (!mounted) return;
      final cropped = type == 'logo'
          ? await ProfileImageCropper.cropLogo(context, file)
          : await ProfileImageCropper.cropBanner(context, file);
      if (!mounted || cropped == null) return;
      final url = await repo.uploadImage(id, cropped);
      if (!mounted) {
        return;
      }
      setState(() {
        if (type == 'logo') {
          logo = url;
        } else if (type == 'banner') {
          banner = url;
        }
      });
    } catch (e) {
      if (mounted) {
        businessError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void clearPin() {
    fields['latitude']!.clear();
    fields['longitude']!.clear();
  }

  Future<void> selectRegion(String level) async {
    if (regionsLoading || busy) return;
    if (level == 'district' && stateId == null) {
      businessError(context, 'Select a state first.');
      return;
    }
    if (level == 'subdistrict' && districtId == null) {
      businessError(context, 'Select a district first.');
      return;
    }
    setState(() => regionsLoading = true);
    try {
      final rows = await repo.regions(
        level: level,
        parentId: level == 'district'
            ? stateId
            : level == 'subdistrict'
            ? districtId
            : null,
      );
      if (!mounted) return;
      final result = await Navigator.push<AdministrativeRegion>(
        context,
        MaterialPageRoute(
          builder: (_) => AdministrativeRegionPicker(
            regions: rows,
            title: level == 'state'
                ? 'Select state'
                : level == 'district'
                ? 'Select district'
                : 'Select sub-district',
            selectedId: level == 'state'
                ? stateId
                : level == 'district'
                ? districtId
                : subdistrictId,
          ),
        ),
      );
      if (!mounted || result == null) return;
      setState(() {
        if (level == 'state') {
          states = rows;
          if (stateId != result.id) {
            if (stateId != null) clearPin();
            stateId = result.id;
            districtId = null;
            subdistrictId = null;
            districts = [];
            subdistricts = [];
          }
        } else if (level == 'district') {
          districts = rows;
          if (districtId != result.id) {
            if (districtId != null) clearPin();
            districtId = result.id;
            subdistrictId = null;
            subdistricts = [];
          }
        } else {
          subdistricts = rows;
          if (subdistrictId != result.id) {
            if (subdistrictId != null) clearPin();
            subdistrictId = result.id;
          }
        }
      });
    } catch (e) {
      if (mounted) businessError(context, e);
    } finally {
      if (mounted) setState(() => regionsLoading = false);
    }
  }

  Future<void> selectShopLocation() async {
    if (subdistrictId == null) {
      businessError(context, 'Select state, district and sub-district first.');
      return;
    }
    final region =
        subdistricts
            .where((r) => r.id == subdistrictId && r.latitude != null)
            .firstOrNull ??
        districts
            .where((r) => r.id == districtId && r.latitude != null)
            .firstOrNull;
    final lat = double.tryParse(value('latitude')),
        lng = double.tryParse(value('longitude'));
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => ShopLocationPicker(
          initialLocation: lat != null && lng != null ? LatLng(lat, lng) : null,
          cityCenter: region?.latitude != null && region?.longitude != null
              ? LatLng(region!.latitude!, region.longitude!)
              : null,
        ),
      ),
    );
    if (!mounted || point == null) return;
    setState(() {
      fields['latitude']!.text = point.latitude.toString();
      fields['longitude']!.text = point.longitude.toString();
    });
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    if (selected.isEmpty || primary == null || !selected.contains(primary)) {
      businessError(context, 'Select categories and a primary category.');
      return;
    }
    if (stateId == null || districtId == null || subdistrictId == null) {
      businessError(
        context,
        'Select your shop state, district and sub-district.',
      );
      return;
    }
    if (value('latitude').isEmpty || value('longitude').isEmpty) {
      businessError(context, 'Mark the exact shop location on the map.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await repo.save(id, {
        for (final key in [
          'name',
          'description',
          'phone',
          'whatsapp',
          'email',
          'address',
        ])
          key: optional(key),
        'latitude': double.tryParse(value('latitude')),
        'longitude': double.tryParse(value('longitude')),
        'shop_address': value('address'),
        'shop_state_id': stateId,
        'shop_district_id': districtId,
        'shop_subdistrict_id': subdistrictId,
        'primary_category_id': primary,
        'logo_url': logo,
        'banner_url': banner,
      }, selected.toList());
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        businessError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !regionsLoading,
    child: VendorPageScaffold(
      appBar: AppBar(
        title: Text(widget.business == null ? 'Add Business' : 'Edit Business'),
      ),
      body: loading
          ? const Center(child: AppContentSkeleton(layout: SkeletonLayout.form))
          : loadError != null
          ? Center(
              child: TextButton(
                onPressed: load,
                child: const Text('Could not load categories. Retry'),
              ),
            )
          : AbsorbPointer(
              absorbing: busy || regionsLoading,
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    heading('Business identity'),
                    field('name', 'Business name', required: true),
                    field('description', 'About this business', lines: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              businessImage(logo, height: 90),
                              TextButton.icon(
                                onPressed: () => image('logo'),
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Logo'),
                              ),
                              if (logo != null)
                                TextButton(
                                  onPressed: () => setState(() => logo = null),
                                  child: const Text('Remove'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              businessImage(banner, height: 90),
                              TextButton.icon(
                                onPressed: () => image('banner'),
                                icon: const Icon(Icons.panorama_outlined),
                                label: const Text('Banner'),
                              ),
                              if (banner != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => banner = null),
                                  child: const Text('Remove'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    heading('Categories'),
                    const Text(
                      'Choose the main categories this business offers. Select one as its primary category. Subcategories are chosen when adding services.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: categories
                          .map(
                            (c) => FilterChip(
                              label: Text(categoryLabel(c)),
                              selected: selected.contains(c['id']),
                              onSelected: (on) => setState(() {
                                final key = c['id'] as String;
                                if (on) {
                                  selected.add(key);
                                  primary ??= key;
                                } else {
                                  selected.remove(key);
                                  if (primary == key) {
                                    primary = selected.firstOrNull;
                                  }
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    if (selected.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey(primary),
                        initialValue: primary,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Primary category',
                        ),
                        items: categories
                            .where((c) => selected.contains(c['id']))
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(
                                  categoryLabel(c),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => primary = v),
                      ),
                    heading('Contact details'),
                    field(
                      'phone',
                      'Business phone',
                      keyboard: TextInputType.phone,
                    ),
                    field(
                      'whatsapp',
                      'WhatsApp (include country code)',
                      keyboard: TextInputType.phone,
                    ),
                    field(
                      'email',
                      'Business email',
                      keyboard: TextInputType.emailAddress,
                    ),
                    heading('Shop location'),
                    field('address', 'Shop address', lines: 3, required: true),
                    if (regionsLoading) const ShimmerLoadingBar(),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.public),
                        title: const Text('State'),
                        subtitle: Text(
                          states
                                  .where((r) => r.id == stateId)
                                  .firstOrNull
                                  ?.name ??
                              'Select state',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => selectRegion('state'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_city_outlined),
                        title: const Text('District'),
                        subtitle: Text(
                          districts
                                  .where((r) => r.id == districtId)
                                  .firstOrNull
                                  ?.name ??
                              'Select district',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => selectRegion('district'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: const Text('Sub-district'),
                        subtitle: Text(
                          subdistricts
                                  .where((r) => r.id == subdistrictId)
                                  .firstOrNull
                                  ?.name ??
                              'Select sub-district / taluk',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => selectRegion('subdistrict'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.map_outlined),
                        title: const Text('Shop on map'),
                        subtitle: Text(
                          value('latitude').isEmpty
                              ? 'Mark your exact shop location'
                              : 'Shop location selected ✓',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: selectShopLocation,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Your shop pin is used to show nearby businesses and distance. You can accept bookings from any area.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: save,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: AppShimmerIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(busy ? 'Saving…' : 'Save business'),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    ),
  );
}

class BusinessSingleDetailsScreen extends StatefulWidget {
  final BusinessModel business;
  const BusinessSingleDetailsScreen({super.key, required this.business});
  @override
  State<BusinessSingleDetailsScreen> createState() =>
      _BusinessSingleDetailsScreenState();
}

class _BusinessSingleDetailsScreenState
    extends State<BusinessSingleDetailsScreen> {
  final repo = BusinessWorkspaceRepository();
  late BusinessModel business;
  late Future<void> loading;
  List<Map<String, dynamic>> categories = [], services = [];
  List<AdministrativeRegion> locationRegions = [];
  List<String> ids = [];
  Set<String> displayCategoryIds = {};
  String? displayPrimaryCategoryId;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    business = widget.business;
    loading = load();
  }

  Future<void> load() async {
    business = await repo.get(business.id);
    locationRegions = await repo.regionDetails([
      ?business.shopStateId,
      ?business.shopDistrictId,
      ?business.shopSubdistrictId,
    ]);
    ids = await repo.categoryIds(business.id);
    categories = await repo.categories();
    displayCategoryIds = ids
        .map((id) => businessRootCategory(id, categories))
        .toSet();
    displayPrimaryCategoryId = business.primaryCategoryId == null
        ? null
        : businessRootCategory(business.primaryCategoryId!, categories);
    services = await repo.services(business.id);
  }

  Future<void> refresh() async {
    setState(() {
      loading = load();
    });
    try {
      await loading;
    } catch (_) {
      /* Render retry state. */
    }
  }

  Future<void> link(String value) async {
    try {
      if (!await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Could not open this link.');
      }
    } catch (e) {
      if (mounted) {
        businessError(context, e);
      }
    }
  }

  Future<void> edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute<BusinessModel>(
        builder: (_) => AddBusinessScreen(business: business),
      ),
    );
    if (mounted) {
      await refresh();
    }
  }

  Future<void> service([Map<String, dynamic>? current]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => BusinessServiceEditor(
          business: business,
          service: current,
          categories: categories,
          businessCategoryIds: ids,
        ),
      ),
    );
    if (mounted) {
      await refresh();
    }
  }

  Widget section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget info(String title, String? text, {VoidCallback? onTap}) =>
      text == null || text.trim().isEmpty
      ? const SizedBox.shrink()
      : ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(text),
          onTap: onTap,
          trailing: onTap == null
              ? null
              : const Icon(Icons.open_in_new, size: 18),
        );
  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    appBar: AppBar(
      title: Text(business.name),
      actions: [
        IconButton(
          tooltip: 'Edit business',
          onPressed: busy ? null : edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: FutureBuilder<void>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load business details.'),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: AppContentSkeleton(layout: SkeletonLayout.form),
          );
        }
        final b = business;
        return AbsorbPointer(
          absorbing: busy,
          child: AppShimmerRefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: businessImage(b.bannerUrl, height: 190),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: businessImage(b.logoUrl, height: 72),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ReviewRatingCard(
                  businessId: b.id,
                  vendorMode: true,
                  refreshKey: loading,
                ),
                const SizedBox(height: 16),
                section('About this business', [
                  if (b.description?.isNotEmpty == true) Text(b.description!),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: categories
                        .where(
                          (c) =>
                              c['parent_id'] == null &&
                              displayCategoryIds.contains(c['id']),
                        )
                        .map(
                          (c) => Chip(
                            avatar: c['id'] == displayPrimaryCategoryId
                                ? const Icon(Icons.star, size: 16)
                                : null,
                            label: Text(c['name'].toString()),
                          ),
                        )
                        .toList(),
                  ),
                  if (ids.isEmpty)
                    const Text('Edit this business to choose its categories.'),
                ]),
                section('Contact & shop location', [
                  info(
                    'Phone',
                    b.phone,
                    onTap: b.phone == null
                        ? null
                        : () => link('tel:${b.phone}'),
                  ),
                  info(
                    'WhatsApp',
                    b.whatsapp,
                    onTap: b.whatsapp == null
                        ? null
                        : () => link(
                            'https://wa.me/${b.whatsapp!.replaceAll(RegExp(r'\D'), '')}',
                          ),
                  ),
                  info(
                    'Email',
                    b.email,
                    onTap: b.email == null
                        ? null
                        : () => link(
                            Uri(scheme: 'mailto', path: b.email).toString(),
                          ),
                  ),
                  info('Shop address', b.shopAddress ?? b.address),
                  info(
                    'State',
                    locationRegions
                        .where((r) => r.id == b.shopStateId)
                        .firstOrNull
                        ?.name,
                  ),
                  info(
                    'District',
                    locationRegions
                        .where((r) => r.id == b.shopDistrictId)
                        .firstOrNull
                        ?.name,
                  ),
                  info(
                    'Sub-district',
                    locationRegions
                        .where((r) => r.id == b.shopSubdistrictId)
                        .firstOrNull
                        ?.name,
                  ),
                  if (b.latitude != null && b.longitude != null)
                    TextButton.icon(
                      onPressed: () => link(
                        'https://www.google.com/maps/search/?api=1&query=${b.latitude},${b.longitude}',
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View location'),
                    ),
                ]),
                section('Services (${services.length})', [
                  if (b.availabilityStatus != 'archived')
                    OutlinedButton.icon(
                      onPressed: () => service(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add service'),
                    ),
                  if (services.isEmpty)
                    const Text('No services added to this business yet.'),
                  ...services.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['name'].toString()),
                      subtitle: Text(
                        '${ServicePricing.fromMap(s).format((s['price'] as num).toDouble())} · ${s['is_active'] == true
                            ? 'Visible'
                            : s['vendor_enabled'] == true
                            ? 'Hidden by business availability'
                            : 'Disabled'}',
                      ),
                      trailing: b.availabilityStatus == 'archived'
                          ? null
                          : const Icon(Icons.edit_outlined),
                      onTap: b.availabilityStatus == 'archived'
                          ? null
                          : () => service(s),
                    ),
                  ),
                ]),

                if (busy) const Center(child: AppShimmerIndicator()),
              ],
            ),
          ),
        );
      },
    ),
  );
}
