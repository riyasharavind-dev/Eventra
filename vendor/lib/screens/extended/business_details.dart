import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/services/vendor_tour_controller.dart';
import 'package:eventor_vendor/widgets/trial/tour_anchor.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/business/business_list_card.dart';
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

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen>
    with LiveDataState<BusinessDetailsScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:businesses',
    'own:business_category_nodes',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await refresh();
  }

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
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: Text(
        AppSettingsScope.translate(context, "vendor.my_businesses.126e368c"),
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => open(null),
      backgroundColor: const Color(0xFF80152C),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.add),
      label: Text(
        AppSettingsScope.translate(context, "vendor.add_business.3bdd110b"),
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: FutureBuilder<List<BusinessModel>>(
      future: loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.could_not_load_businesses.9f0d74a9",
                  ),
                ),
                TextButton(
                  onPressed: refresh,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF80152C),
                  ),
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.retry.942087cc",
                    ),
                  ),
                ),
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
          color: const Color(0xFF80152C),
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.one_vendor_all_your_businesses.a6a6ddd2",
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17171B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.manage_each_business_with_its_own_categories_.7ff7e3c9",
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0EDF0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5E8EC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 28,
                          color: AppIconColors.standard,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.add_your_first_business_to_get_started.caeaee0c",
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF17171B),
                        ),
                      ),
                    ],
                  ),
                ),
              ...rows.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BusinessListCard(
                    key: ValueKey(b.id),
                    business: b,
                    onOpen: () => open(b),
                    rating: ReviewRatingCard(
                      businessId: b.id,
                      vendorMode: true,
                      compact: true,
                      refreshKey: loading,
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
      primary = rootPrimary ?? roots.firstOrNull;
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
          return AppSettingsScope.translate(
            context,
            "vendor.enter_at_least_2_characters.373e6931",
          );
        }
        if (key == 'address' && v.length < 5) {
          return AppSettingsScope.translate(
            context,
            "vendor.enter_your_full_shop_address.18404c05",
          );
        }
        if (v.isEmpty) {
          return null;
        }
        if (key == 'email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
          return AppSettingsScope.translate(
            context,
            "vendor.enter_a_valid_email.c6e81fdf",
          );
        }
        if (['website_url', 'instagram_url'].contains(key) && !webUrl(v)) {
          return AppSettingsScope.translate(
            context,
            "vendor.enter_a_full_https_link.211c0d22",
          );
        }
        if (['phone', 'whatsapp'].contains(key) &&
            !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(v)) {
          return AppSettingsScope.translate(
            context,
            "vendor.enter_a_valid_number_with_country_code.00277c23",
          );
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
      setState(() => regionsLoading = false);
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
      final expectedParent = level == 'district'
          ? stateId
          : level == 'subdistrict'
          ? districtId
          : null;
      if (result.level != level || result.parentId != expectedParent) {
        throw StateError('Location selection changed. Please select again.');
      }
      setState(() {
        if (level == 'state') {
          states = rows;
          if (stateId != result.id) {
            clearPin();
            stateId = result.id;
            districtId = null;
            subdistrictId = null;
            districts = [];
            subdistricts = [];
          }
        } else if (level == 'district') {
          districts = rows;
          if (districtId != result.id) {
            clearPin();
            districtId = result.id;
            subdistrictId = null;
            subdistricts = [];
          }
        } else {
          subdistricts = rows;
          if (subdistrictId != result.id) {
            clearPin();
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
    if (regionsLoading || busy) return;
    setState(() => regionsLoading = true);
    try {
      final boundary = await repo.boundary(subdistrictId!);
      if (!mounted) return;
      setState(() => regionsLoading = false);
      final lat = double.tryParse(value('latitude')),
          lng = double.tryParse(value('longitude'));
      final point = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (_) => ShopLocationPicker(
            boundary: boundary,
            initialLocation: lat != null && lng != null
                ? LatLng(lat, lng)
                : null,
            cityCenter: boundary.center,
          ),
        ),
      );
      if (!mounted || point == null) return;
      setState(() {
        fields['latitude']!.text = point.latitude.toString();
        fields['longitude']!.text = point.longitude.toString();
      });
    } catch (e) {
      if (mounted) businessError(context, e);
    } finally {
      if (mounted) setState(() => regionsLoading = false);
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    if (primary == null) {
      businessError(context, 'Select one business category.');
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
      final result = await repo.save(
        id,
        {
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
        },
        [primary!],
      );
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
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.could_not_load_categories_retry.410c44bf",
                  ),
                ),
              ),
            )
          : AbsorbPointer(
              absorbing: busy || regionsLoading,
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    heading(
                      AppSettingsScope.translate(
                        context,
                        "vendor.business_identity.6f104bec",
                      ),
                    ),
                    field(
                      'name',
                      AppSettingsScope.translate(
                        context,
                        "vendor.business_name.a921756e",
                      ),
                      required: true,
                    ),
                    field(
                      'description',
                      AppSettingsScope.translate(
                        context,
                        "vendor.about_this_business.fb47aebd",
                      ),
                      lines: 4,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              businessImage(logo, height: 90),
                              TextButton.icon(
                                onPressed: () => image('logo'),
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.logo.d707dc2f",
                                  ),
                                ),
                              ),
                              if (logo != null)
                                TextButton(
                                  onPressed: () => setState(() => logo = null),
                                  child: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.remove.c3812fc4",
                                    ),
                                  ),
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
                                label: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.banner.b7f4d98f",
                                  ),
                                ),
                              ),
                              if (banner != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => banner = null),
                                  child: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.remove.c3812fc4",
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    heading(
                      AppSettingsScope.translate(
                        context,
                        "vendor.category.292c06f0",
                      ),
                    ),
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.choose_one_main_category_for_this_business_su.bb63f4f6",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TourAnchor(
                      id: TourTargets.category,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('business-category-$primary'),
                        initialValue: primary,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppSettingsScope.translate(
                            context,
                            "vendor.business_category.1674badc",
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: categories
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
                        validator: (v) => v == null
                            ? AppSettingsScope.translate(
                                context,
                                "vendor.select_one_business_category.2e45b13b",
                              )
                            : null,
                        onChanged: (v) => setState(() => primary = v),
                      ),
                    ),
                    heading(
                      AppSettingsScope.translate(
                        context,
                        "vendor.contact_details.9681395d",
                      ),
                    ),
                    field(
                      'phone',
                      AppSettingsScope.translate(
                        context,
                        "vendor.business_phone.471f6f94",
                      ),
                      keyboard: TextInputType.phone,
                    ),
                    field(
                      'whatsapp',
                      AppSettingsScope.translate(
                        context,
                        "vendor.whatsapp_include_country_code.22ed7c06",
                      ),
                      keyboard: TextInputType.phone,
                    ),
                    field(
                      'email',
                      AppSettingsScope.translate(
                        context,
                        "vendor.business_email.e9afc27f",
                      ),
                      keyboard: TextInputType.emailAddress,
                    ),
                    heading(
                      AppSettingsScope.translate(
                        context,
                        "vendor.shop_location.0ff027f5",
                      ),
                    ),
                    field(
                      'address',
                      AppSettingsScope.translate(
                        context,
                        "vendor.shop_address.4a61a6c4",
                      ),
                      lines: 3,
                      required: true,
                    ),
                    SizedBox(
                      height: 4,
                      child: regionsLoading ? const ShimmerLoadingBar() : null,
                    ),
                    Card(
                      key: const ValueKey('shop-state'),
                      child: ListTile(
                        leading: const Icon(Icons.public),
                        title: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.state.a3b50c47",
                          ),
                        ),
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
                      key: const ValueKey('shop-district'),
                      child: ListTile(
                        leading: const Icon(Icons.location_city_outlined),
                        title: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.district.50f1878d",
                          ),
                        ),
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
                      key: const ValueKey('shop-subdistrict'),
                      child: ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.sub_district.ad6093e8",
                          ),
                        ),
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
                        title: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.shop_on_map.94fa8707",
                          ),
                        ),
                        subtitle: Text(
                          value('latitude').isEmpty
                              ? 'Mark your exact shop location'
                              : 'Shop location selected ✓',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: selectShopLocation,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.your_shop_pin_is_used_to_show_nearby_business.0fced8bd",
                        ),
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
    extends State<BusinessSingleDetailsScreen>
    with LiveDataState<BusinessSingleDetailsScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:businesses',
    'own:business_category_nodes',
    'own:services',
    'public:category_nodes',
    'public:administrative_regions',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    refresh();
    await loading;
  }

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
    final results = await Future.wait<Object>([
      repo.regionDetails([
        ?business.shopStateId,
        ?business.shopDistrictId,
        ?business.shopSubdistrictId,
      ]),
      repo.categoryIds(business.id),
      repo.categories(),
      repo.services(business.id),
    ]);
    locationRegions = results[0] as List<AdministrativeRegion>;
    ids = results[1] as List<String>;
    categories = results[2] as List<Map<String, dynamic>>;
    services = results[3] as List<Map<String, dynamic>>;
    displayCategoryIds = ids
        .map((id) => businessRootCategory(id, categories))
        .toSet();
    displayPrimaryCategoryId = business.primaryCategoryId == null
        ? null
        : businessRootCategory(business.primaryCategoryId!, categories);
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

  Widget section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0EDF0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF80152C).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
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
          tooltip: AppSettingsScope.translate(
            context,
            "vendor.edit_business.93a35820",
          ),
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
                Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.could_not_load_business_details.e785e0aa",
                  ),
                ),
                TextButton(
                  onPressed: refresh,
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.retry.942087cc",
                    ),
                  ),
                ),
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
                  borderRadius: BorderRadius.circular(20),
                  child: businessImage(b.bannerUrl, height: 190),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFCB48),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
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
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17171B),
                            ),
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
                section(
                  AppSettingsScope.translate(
                    context,
                    "vendor.about_this_business.fb47aebd",
                  ),
                  [
                    if (b.description?.isNotEmpty == true)
                      Text(
                        b.description!,
                        style: const TextStyle(
                          height: 1.5,
                          color: Color(0xFF17171B),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .where(
                            (c) =>
                                c['parent_id'] == null &&
                                displayCategoryIds.contains(c['id']),
                          )
                          .map((c) {
                            final isPrimary =
                                c['id'] == displayPrimaryCategoryId;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isPrimary
                                    ? const Color(0xFFFFCB48)
                                          .withValues(alpha: 0.2)
                                    : const Color(0xFFF5E8EC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPrimary
                                      ? const Color(0xFFFFCB48)
                                      : const Color(0xFF80152C)
                                            .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPrimary) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: Color(0xFF8A6200),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    c['name'].toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isPrimary
                                          ? const Color(0xFF8A6200)
                                          : const Color(0xFF80152C),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ),
                    if (ids.isEmpty)
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.edit_this_business_to_choose_its_categories.3cad23d2",
                        ),
                      ),
                  ],
                ),
                section(
                  AppSettingsScope.translate(
                    context,
                    "vendor.contact_shop_location.2227e162",
                  ),
                  [
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.phone.63dceb88",
                      ),
                      b.phone,
                      onTap: b.phone == null
                          ? null
                          : () => link('tel:${b.phone}'),
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.whatsapp.6a40edf1",
                      ),
                      b.whatsapp,
                      onTap: b.whatsapp == null
                          ? null
                          : () => link(
                              'https://wa.me/${b.whatsapp!.replaceAll(RegExp(r'\D'), '')}',
                            ),
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.email.969ccbd3",
                      ),
                      b.email,
                      onTap: b.email == null
                          ? null
                          : () => link(
                              Uri(scheme: 'mailto', path: b.email).toString(),
                            ),
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.shop_address.4a61a6c4",
                      ),
                      b.shopAddress ?? b.address,
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.state.a3b50c47",
                      ),
                      locationRegions
                          .where((r) => r.id == b.shopStateId)
                          .firstOrNull
                          ?.name,
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.district.50f1878d",
                      ),
                      locationRegions
                          .where((r) => r.id == b.shopDistrictId)
                          .firstOrNull
                          ?.name,
                    ),
                    info(
                      AppSettingsScope.translate(
                        context,
                        "vendor.sub_district.ad6093e8",
                      ),
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
                        label: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.view_location.1cab3648",
                          ),
                        ),
                      ),
                  ],
                ),
                section(
                  AppSettingsScope.translate(
                    context,
                    "vendor.services_value0.8c0bb97d",
                    args: {"value0": services.length},
                  ),
                  [
                    if (b.availabilityStatus != 'archived')
                      OutlinedButton.icon(
                        onPressed: () => service(),
                        icon: const Icon(Icons.add),
                        label: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.add_service.7d9366fd",
                          ),
                        ),
                      ),
                    if (services.isEmpty)
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.no_services_added_to_this_business_yet.b64199af",
                        ),
                      ),
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
                  ],
                ),

                if (busy) const Center(child: AppShimmerIndicator()),
              ],
            ),
          ),
        );
      },
    ),
  );
}
