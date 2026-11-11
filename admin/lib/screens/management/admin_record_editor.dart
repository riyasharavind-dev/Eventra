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
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(f.label),
        value: values[f.name] == true,
        onChanged: locked ? null : (v) => setState(() => values[f.name] = v),
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
        builder: (state) => InputDecorator(
          decoration: InputDecoration(
            labelText:
                widget.module.name == 'category_nodes' && f.name == 'parent_id'
                ? 'Parent category'
                : widget.module.name == 'social_links' && f.name == 'icon_url'
                ? 'Social icon URL'
                : f.label,
            helperText:
                widget.module.name == 'category_nodes' && f.name == 'parent_id'
                ? 'Leave empty for a main category. Select a parent for a subcategory.'
                : null,
            helperMaxLines: 3,
            errorText: state.errorText,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  labels[f.name] ?? values[f.name]?.toString() ?? 'Select…',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!locked) ...[
                if (f.nullable)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      setState(() {
                        values[f.name] = null;
                        labels.remove(f.name);
                      });
                      state.didChange(null);
                    },
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: 'Choose ${f.label}',
                  onPressed: () => reference(f, state),
                  icon: const Icon(Icons.search),
                ),
              ],
            ],
          ),
        ),
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
          border: const OutlineInputBorder(),
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
            border: const OutlineInputBorder(),
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
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        url,
                        key: ValueKey(url),
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, s) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Icon preview. Click Save changes to publish this change.',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (widget.module.name == 'banners' && f.name == 'image_url')
          const Text('Banners are cropped to 16:9.'),
        if (f.image)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => upload(f),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                f.name == 'icon_url' ? 'Upload icon' : 'Upload image',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.record == null ? 'Add' : 'Edit'} ${widget.module.label}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: AbsorbPointer(
            absorbing: busy,
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (busy) const LinearProgressIndicator(),
                  ...widget.module.editable.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: field(f),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(busy ? 'Saving…' : 'Save changes'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(field.label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      ...value.asMap().entries.map(
        (entry) => Card(
          child: ListTile(
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
            ),
            subtitle: field.name == 'gallery' && entry.key == 0
                ? const Text('Cover image')
                : null,
            onTap: () => edit(context, entry.key),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.key > 0)
                  IconButton(
                    tooltip: 'Move first',
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
                  tooltip: 'Remove item',
                  onPressed: () {
                    final next = List<dynamic>.from(value)..removeAt(entry.key);
                    onChanged(next);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
          if (onUpload != null)
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Upload photo'),
            ),
        ],
      ),
    ],
  );
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
    title: Text('Edit ${adminLabel(widget.kind)} item'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.kind == 'portfolio')
              DropdownButtonFormField<String>(
                initialValue: type,
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
                  decoration: InputDecoration(labelText: adminLabel(e.key)),
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
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
        child: const Text('Save item'),
      ),
    ],
  );
}
