import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';
import '../../widgets/eventor_image_cropper.dart';

class AdminRecordEditor extends StatefulWidget {
  final AdminRepository repo;
  final AdminModule module;
  final List<AdminModule> modules;
  final AdminRecord? record;
  final Map<String, dynamic> initial;
  const AdminRecordEditor({
    super.key,
    required this.repo,
    required this.module,
    required this.modules,
    this.record,
    this.initial = const {},
  });
  @override
  State<AdminRecordEditor> createState() => _AdminRecordEditorState();
}

class _AdminRecordEditorState extends State<AdminRecordEditor> {
  final form = GlobalKey<FormState>();
  final controls = <String, TextEditingController>{};
  final values = <String, dynamic>{}, labels = <String, String>{};
  final requestId = adminRequestId();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.module.editable) {
      final value = widget.record != null
          ? widget.record!.values[f.name]
          : widget.initial[f.name] ?? f.defaultValue();
      values[f.name] = value;
      if (f.type != 'bool' &&
          f.type != 'jsonb' &&
          f.referenceTable == null &&
          f.choices.isEmpty) {
        controls[f.name] = TextEditingController(
          text: value == null
              ? ''
              : value is List
              ? value.join(', ')
              : f.type == 'timestamptz'
              ? (DateTime.tryParse(value.toString())
                        ?.toLocal()
                        .toIso8601String() ??
                    value.toString())
              : value.toString(),
        );
      }
      if (f.referenceTable != null && value != null) {
        labels[f.name] = widget.record?.related(f.name) ?? value.toString();
        resolveLabel(f, value.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> resolveLabel(AdminField f, String id) async {
    final module = widget.modules
        .where((m) => m.name == f.referenceTable)
        .firstOrNull;
    if (module == null) {
      return;
    }
    try {
      final row = await widget.repo.record(module, id);
      if (mounted && values[f.name]?.toString() == id) {
        setState(() => labels[f.name] = row.title);
      }
    } catch (_) {
      /* Keep saved reference visible. */
    }
  }

  Future<void> upload(AdminField f) async {
    if (busy) {
      return;
    }
    if (widget.module.name == 'services' && values['vendor_id'] == null) {
      adminError(context, 'Select the vendor first.');
      return;
    }
    setState(() => busy = true);
    try {
      final icon =
          f.name == 'icon_url' &&
          ['category_nodes', 'social_links'].contains(widget.module.name);
      final banner = widget.module.name == 'banners' && f.name == 'image_url';
      final cropRequired = icon || banner;
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: cropRequired ? null : 2000,
        imageQuality: cropRequired ? null : 88,
      );
      if (picked == null || !mounted) return;
      final image = cropRequired
          ? await EventorImageCropper.crop(
              context,
              picked,
              title: banner ? 'Crop banner' : 'Crop icon',
              aspectRatio: banner ? 16 / 9 : 1,
              banner: banner,
              maxDimension: banner ? 1800 : 512,
              preserveTransparency: icon,
              outputName: banner ? 'banner.jpg' : 'icon.png',
            )
          : picked;
      if (image == null || !mounted) return;
      final result = await widget.repo.upload(
        widget.module.name,
        f.name,
        await image.readAsBytes(),
        image.name,
        vendorId: values['vendor_id']?.toString(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (f.type == 'jsonb') {
          values[f.name] = [...values[f.name] as List? ?? [], result['url']!];
        } else {
          controls[f.name]?.text = result['url']!;
          values[f.name] = result['url'];
          if (widget.module.name == 'banners') {
            controls['image_path']?.text = result['path']!;
            values['image_path'] = result['path'];
          }
        }
      });
    } catch (e) {
      if (mounted) {
        adminError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> reference(AdminField f, FormFieldState<String> state) async {
    final module = widget.modules
        .where((m) => m.name == f.referenceTable)
        .firstOrNull;
    if (module == null) {
      adminError(context, 'This reference is read-only.');
      return;
    }
    final filters = <String, dynamic>{};
    if (widget.module.name == 'businesses' && f.name == 'primary_category_id') {
      filters['parent_id'] = null;
    }
    if (f.name == 'business_id' && values['vendor_id'] != null) {
      filters['vendor_id'] = values['vendor_id'];
    }
    final selected = await pickAdminReference(
      context,
      widget.repo,
      module,
      filters: filters,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      values[f.name] = selected;
      if (f.name == 'vendor_id' && widget.module.name == 'services') {
        values['business_id'] = null;
        values['category_node_id'] = null;
      }
      if (f.name == 'business_id' && widget.module.name == 'services') {
        values['category_node_id'] = null;
      }
    });
    state.didChange(selected);
    await resolveLabel(f, selected);
  }

  Future<void> date(AdminField f) async {
    final current =
        DateTime.tryParse(controls[f.name]?.text ?? '')?.toLocal() ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDate: current,
    );
    if (picked == null || !mounted) {
      return;
    }
    DateTime result = picked;
    if (f.type == 'timestamptz') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null) {
        return;
      }
      result = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    }
    if (mounted) {
      setState(
        () => controls[f.name]!.text = f.type == 'date'
            ? result.toIso8601String().split('T').first
            : result.toIso8601String(),
      );
    }
  }

  Future<void> save() async {
    if (busy) {
      return;
    }
    if (controls['slug'] != null &&
        controls['slug']!.text.trim().isEmpty &&
        controls['name']?.text.trim().isNotEmpty == true) {
      controls['slug']!.text =
          '${controls['name']!.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-$requestId';
    }
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      final payload = <String, dynamic>{};
      for (final f in widget.module.editable) {
        payload[f.name] = controls.containsKey(f.name)
            ? f.parse(controls[f.name]!.text)
            : values[f.name];
      }
      if (widget.module.name == 'support_settings' &&
          payload['whatsapp_number'] is String) {
        payload['whatsapp_number'] = (payload['whatsapp_number'] as String)
            .replaceAll(RegExp(r'[^0-9]'), '');
      }
      final saved = await widget.repo.save(
        widget.module,
        payload,
        before: widget.record,
        requestId: widget.record == null ? requestId : null,
      );
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        adminError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget field(AdminField f) {
    final locked =
        widget.record != null &&
        (f.name == widget.module.pk ||
            (['services', 'businesses'].contains(widget.module.name) &&
                f.name == 'vendor_id') ||
            (widget.module.name == 'support_tickets' && f.name == 'user_id'));

    if (f.type == 'bool') {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0EDF0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              f.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              values[f.name] == true
                  ? 'Enabled / Active'
                  : 'Disabled / Inactive',
              style: TextStyle(
                fontSize: 12,
                color: values[f.name] == true
                    ? const Color(0xFF80152C)
                    : Colors.grey.shade600,
              ),
            ),
            activeThumbColor: const Color(0xFF80152C),
            value: values[f.name] == true,
            onChanged: locked
                ? null
                : (v) => setState(() => values[f.name] = v),
          ),
        ),
      );
    }

    if (f.type == 'jsonb') {
      return _ListEditor(
        key: ValueKey(f.name),
        field: f,
        value: List<dynamic>.from(values[f.name] as List? ?? []),
        onChanged: (v) => setState(() => values[f.name] = v),
        onUpload: f.name == 'gallery' ? () => upload(f) : null,
      );
    }

    if (f.referenceTable != null) {
      return FormField<String>(
        key: ValueKey('${f.name}-${values[f.name]}'),
        initialValue: values[f.name]?.toString(),
        validator: (v) =>
            f.required && (v == null || v.isEmpty) ? 'Select ${f.label}' : null,
        builder: (state) {
          final isSelected = values[f.name] != null && values[f.name] != '';
          final displayLabel =
              labels[f.name] ??
              values[f.name]?.toString() ??
              'Select ${f.label}…';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.module.name == 'category_nodes' && f.name == 'parent_id'
                    ? 'Parent Category'
                    : f.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF2D2F33),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: locked ? null : () => reference(f, state),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: locked ? const Color(0xFFF3F3F5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.hasError
                          ? Colors.red.shade400
                          : isSelected
                          ? const Color(0xFF80152C).withValues(alpha: 0.4)
                          : const Color(0xFFE2E2E6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFBF4F6)
                              : const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSelected ? Icons.link : Icons.search,
                          size: 18,
                          color: isSelected
                              ? const Color(0xFF80152C)
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF1F2024)
                                    : Colors.grey.shade500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isSelected)
                              Text(
                                'ID: ${values[f.name]}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!locked && isSelected) ...[
                        if (f.nullable)
                          IconButton(
                            tooltip: 'Clear selection',
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                values[f.name] = null;
                                labels.remove(f.name);
                              });
                              state.didChange(null);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        OutlinedButton(
                          onPressed: () => reference(f, state),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                      if (!isSelected && !locked)
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.module.name == 'category_nodes' &&
                  f.name == 'parent_id')
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Leave empty for a main root category. Select a parent for a subcategory.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    state.errorText ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
            ],
          );
        },
      );
    }

    if (f.choices.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: f.choices.contains(values[f.name])
            ? values[f.name] as String?
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          filled: true,
          fillColor: locked ? const Color(0xFFF3F3F5) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          if (f.nullable)
            const DropdownMenuItem<String>(value: null, child: Text('Not set')),
          ...f.choices.map(
            (v) => DropdownMenuItem(value: v, child: Text(adminLabel(v))),
          ),
        ],
        onChanged: locked ? null : (v) => setState(() => values[f.name] = v),
        validator: (v) => f.required && v == null ? 'Select ${f.label}' : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controls[f.name],
          readOnly: locked,
          maxLines: f.longText ? (f.name == 'content_markdown' ? 14 : 5) : 1,
          keyboardType: f.numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : null,
          decoration: InputDecoration(
            labelText:
                widget.module.name == 'social_links' && f.name == 'icon_url'
                ? 'Social icon URL'
                : f.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            filled: true,
            fillColor: locked ? const Color(0xFFF3F3F5) : Colors.white,
            helperText:
                widget.module.name == 'social_links' && f.name == 'icon_url'
                ? 'Upload PNG, WebP or JPG (max 2 MB). Transparent square icons recommended. Then save the link.'
                : widget.module.name == 'support_settings' &&
                      f.name == 'whatsapp_number'
                ? 'Include country code, e.g. 919876543210. The app opens this number in WhatsApp.'
                : widget.module.name == 'support_settings' && f.name == 'email'
                ? 'Email address customers or vendors can contact for support.'
                : f.type.startsWith('_')
                ? 'Separate entries with commas'
                : f.type == 'time'
                ? 'HH:MM or HH:MM:SS'
                : f.name == 'content_markdown'
                ? 'Markdown content; published versions are immutable'
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: ['date', 'timestamptz'].contains(f.type)
                ? IconButton(
                    onPressed: () => date(f),
                    icon: const Icon(Icons.calendar_today_outlined),
                  )
                : null,
          ),
          validator: (v) {
            if (f.required && (v?.trim().isEmpty ?? true)) {
              return '${f.label} is required';
            }
            try {
              if (widget.module.name == 'social_links' &&
                  ['link', 'icon_url'].contains(f.name) &&
                  (v?.trim().isNotEmpty ?? false)) {
                final uri = Uri.tryParse(v!.trim());
                if (uri == null ||
                    uri.scheme != 'https' ||
                    uri.host.isEmpty ||
                    uri.userInfo.isNotEmpty) {
                  return 'Enter a valid https:// URL';
                }
              }
              if (widget.module.name == 'support_settings' &&
                  (v?.trim().isNotEmpty ?? false)) {
                if (f.name == 'email' &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v!.trim())) {
                  return 'Enter a valid support email';
                }
                if (f.name == 'whatsapp_number' &&
                    (!RegExp(r'^\+?[0-9\s()-]+$').hasMatch(v!.trim()) ||
                        !RegExp(r'^[1-9][0-9]{6,14}$')
                            .hasMatch(v.replaceAll(RegExp(r'[^0-9]'), '')))) {
                  return 'Enter a phone number with country code (7–15 digits)';
                }
              }
              final parsed = f.parse(v ?? '');
              if (f.name == 'price' && parsed is num && parsed < 0) {
                return 'Price cannot be negative';
              }
              if (f.type == 'time' &&
                  v?.isNotEmpty == true &&
                  !RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$')
                      .hasMatch(v!)) {
                return 'Enter time as HH:MM';
              }
              return null;
            } catch (e) {
              return e.toString().replaceFirst('FormatException: ', '');
            }
          },
        ),
        if (f.name == 'icon_url' &&
            ['category_nodes', 'social_links'].contains(widget.module.name))
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controls[f.name]!,
            builder: (context, value, _) {
              final url = value.text.trim();
              if (url.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No uploaded icon yet. The fallback icon will be used.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0EDF0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E2E6)),
                        ),
                        child: Image.network(
                          url,
                          key: ValueKey(url),
                          fit: BoxFit.contain,
                          errorBuilder: (_, e, s) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Icon preview. Click Save changes below to update live.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (widget.module.name == 'banners' && f.name == 'image_url')
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Banners are cropped to 16:9 aspect ratio.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        if (f.image)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => upload(f),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(
                  f.name == 'icon_url'
                      ? 'Upload Icon File'
                      : 'Upload Image File',
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Groups fields into clean, logical visual cards for effortless editing
  List<Widget> _buildGroupedSections() {
    final fields = widget.module.editable;
    if (fields.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No editable fields available for this module.'),
          ),
        ),
      ];
    }

    // Classify fields
    final statusFields = <AdminField>[];
    final mediaFields = <AdminField>[];
    final contentFields = <AdminField>[];
    final pricingFields = <AdminField>[];
    final generalFields = <AdminField>[];

    for (final f in fields) {
      if (f.type == 'bool' ||
          f.name == 'status' ||
          f.name == 'moderation_status') {
        statusFields.add(f);
      } else if (f.image ||
          f.name == 'gallery' ||
          f.name == 'portfolio' ||
          f.name.contains('image') ||
          f.name.contains('icon') ||
          f.name.contains('photo')) {
        mediaFields.add(f);
      } else if (f.longText ||
          f.name == 'description' ||
          f.name == 'content_markdown' ||
          f.name == 'features' ||
          f.name == 'notes') {
        contentFields.add(f);
      } else if (f.name == 'price' ||
          f.name == 'pricing_type' ||
          f.name == 'pricing_unit' ||
          f.name == 'duration' ||
          f.name == 'sort_order') {
        pricingFields.add(f);
      } else {
        generalFields.add(f);
      }
    }

    Widget buildCard({
      required String title,
      required IconData icon,
      required String subtitle,
      required List<AdminField> sectionFields,
    }) {
      if (sectionFields.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0EDF0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF80152C)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2024),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: Color(0xFFF5F5F7)),
            ),
            ...sectionFields.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: field(f),
              ),
            ),
          ],
        ),
      );
    }

    return [
      buildCard(
        title: 'Core Details',
        icon: Icons.info_outline,
        subtitle: 'Key attributes and identifiers',
        sectionFields: generalFields,
      ),
      buildCard(
        title: 'Content & Information',
        icon: Icons.article_outlined,
        subtitle: 'Detailed descriptions, notes, and specs',
        sectionFields: contentFields,
      ),
      buildCard(
        title: 'Pricing & Operations',
        icon: Icons.payments_outlined,
        subtitle: 'Rates, units, ordering, and schedule',
        sectionFields: pricingFields,
      ),
      buildCard(
        title: 'Media & Visual Assets',
        icon: Icons.photo_library_outlined,
        subtitle: 'Photos, icons, and visual content',
        sectionFields: mediaFields,
      ),
      buildCard(
        title: 'Status & Visibility',
        icon: Icons.tune,
        subtitle: 'Publication controls and state flags',
        sectionFields: statusFields,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.record == null;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isNew ? 'Create' : 'Edit'} ${widget.module.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              if (!isNew)
                Text(
                  widget.record!.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF80152C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(busy ? 'Saving…' : 'Save Changes'),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel & Return'),
              ),
              const Spacer(),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Text(
                    'Saving changes to platform…',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              FilledButton.icon(
                onPressed: busy ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF80152C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(busy ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: AbsorbPointer(
              absorbing: busy,
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  children: [
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          color: Color(0xFF80152C),
                        ),
                      ),
                    ..._buildGroupedSections(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListEditor extends StatelessWidget {
  final AdminField field;
  final List<dynamic> value;
  final ValueChanged<List<dynamic>> onChanged;
  final VoidCallback? onUpload;
  const _ListEditor({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.onUpload,
  });

  Future<void> edit(BuildContext context, [int? index]) async {
    final map = field.name != 'gallery';
    final current = index == null ? null : value[index];
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => _ListItemDialog(kind: field.name, value: current),
    );
    if (result == null) {
      return;
    }
    final next = List<dynamic>.from(value);
    if (index == null) {
      next.add(map ? Map<String, dynamic>.from(result as Map) : result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isGallery = field.name == 'gallery';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                field.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '${value.length} items',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isGallery) ...[
          // Visual thumbnail grid for gallery photos
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...value.asMap().entries.map((entry) {
                final idx = entry.key;
                final url = entry.value.toString();
                final isCover = idx == 0;

                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCover
                          ? const Color(0xFF80152C)
                          : const Color(0xFFE2E2E6),
                      width: isCover ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      if (isCover)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF80152C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'COVER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 14,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Remove photo',
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              final next = List<dynamic>.from(value)
                                ..removeAt(idx);
                              onChanged(next);
                            },
                          ),
                        ),
                      ),
                      if (!isCover)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              final next = List<dynamic>.from(value);
                              final item = next.removeAt(idx);
                              next.insert(0, item);
                              onChanged(next);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Make Cover',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              // Upload photo button
              if (onUpload != null)
                InkWell(
                  onTap: onUpload,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF80152C).withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 28,
                          color: Color(0xFF80152C),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF80152C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ] else ...[
          // Non-gallery list (e.g. features, portfolio)
          ...value.asMap().entries.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  title: Text(
                    entry.value is Map
                        ? (entry.value['title'] ??
                                  entry.value['caption'] ??
                                  entry.value['url'] ??
                                  'Item')
                              .toString()
                        : entry.value.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle:
                      entry.value is Map && entry.value['description'] != null
                      ? Text(
                          entry.value['description'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  onTap: () => edit(context, entry.key),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.key > 0)
                        IconButton(
                          tooltip: 'Move to top',
                          iconSize: 18,
                          onPressed: () {
                            final next = List<dynamic>.from(value),
                                item = value[entry.key];
                            next.removeAt(entry.key);
                            next.insert(0, item);
                            onChanged(next);
                          },
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      IconButton(
                        tooltip: 'Edit item',
                        iconSize: 18,
                        onPressed: () => edit(context, entry.key),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        iconSize: 18,
                        onPressed: () {
                          final next = List<dynamic>.from(value)
                            ..removeAt(entry.key);
                          onChanged(next);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => edit(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(isGallery ? 'Add Image URL' : 'Add Item'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ListItemDialog extends StatefulWidget {
  final String kind;
  final dynamic value;
  const _ListItemDialog({required this.kind, this.value});
  @override
  State<_ListItemDialog> createState() => _ListItemDialogState();
}

class _ListItemDialogState extends State<_ListItemDialog> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  String type = 'image';

  @override
  void initState() {
    super.initState();
    final map = widget.value is Map
        ? Map<String, dynamic>.from(widget.value as Map)
        : <String, dynamic>{};
    type = map['type']?.toString() ?? 'image';
    for (final key
        in widget.kind == 'features'
            ? ['title', 'description']
            : widget.kind == 'portfolio'
            ? ['url', 'caption']
            : ['url']) {
      fields[key] = TextEditingController(
        text: widget.kind == 'gallery'
            ? widget.value?.toString() ?? ''
            : map[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.edit_note,
            color: Color(0xFF80152C),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Edit ${adminLabel(widget.kind)} Item',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.kind == 'portfolio')
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'image', child: Text('Image')),
                    DropdownMenuItem(value: 'video', child: Text('Video link')),
                  ],
                  onChanged: (v) => type = v!,
                ),
              ...fields.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: e.value,
                    maxLines: e.key == 'description' ? 4 : 1,
                    decoration: InputDecoration(
                      labelText: adminLabel(e.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) {
                      if (e.key == 'url') {
                        final u = Uri.tryParse(v?.trim() ?? '');
                        if (u == null ||
                            !['http', 'https'].contains(u.scheme) ||
                            u.host.isEmpty) {
                          return 'Enter a full http/https URL';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF80152C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          if (!form.currentState!.validate()) {
            return;
          }
          Navigator.pop(
            context,
            widget.kind == 'gallery'
                ? fields['url']!.text.trim()
                : <String, dynamic>{
                    if (widget.value is Map)
                      ...Map<String, dynamic>.from(widget.value as Map),
                    for (final e in fields.entries) e.key: e.value.text.trim(),
                    if (widget.kind == 'portfolio') 'type': type,
                  },
          );
        },
        child: const Text('Save Item'),
      ),
    ],
  );
}
