import '../../widgets/vendor_page_scaffold.dart';
import '../../models/service_pricing.dart';
import '../../widgets/services/service_pricing_fields.dart';

import 'package:flutter/material.dart';

import '../../models/business_model.dart';
import '../../repositories/business_workspace_repository.dart';

class BusinessServiceEditor extends StatefulWidget {
  final BusinessModel business;
  final Map<String, dynamic>? service;
  final List<Map<String, dynamic>> categories;
  final List<String> businessCategoryIds;
  const BusinessServiceEditor({
    super.key,
    required this.business,
    this.service,
    required this.categories,
    required this.businessCategoryIds,
  });
  @override
  State<BusinessServiceEditor> createState() => _BusinessServiceEditorState();
}

class _BusinessServiceEditorState extends State<BusinessServiceEditor> {
  final repo = BusinessWorkspaceRepository();
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, price, gallery;
  late final String id;
  late final List<Map<String, dynamic>> allowed;
  ServicePricing pricing = const ServicePricing();
  String? category;
  bool enabled = true, busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.service;
    pricing = ServicePricing.fromMap(s ?? {});
    id = s?['id'] as String? ?? BusinessWorkspaceRepository.newId();
    name = TextEditingController(text: s?['name']?.toString() ?? '');
    description = TextEditingController(
      text: s?['description']?.toString() ?? '',
    );
    price = TextEditingController(text: s?['price']?.toString() ?? '');
    gallery = TextEditingController(
      text: (s?['gallery'] as List? ?? []).join('\n'),
    );
    enabled = s?['vendor_enabled'] as bool? ?? s?['is_active'] as bool? ?? true;
    final ids = widget.businessCategoryIds.toSet();
    bool changed = true;
    while (changed) {
      changed = false;
      for (final c in widget.categories) {
        if (ids.contains(c['parent_id']) && ids.add(c['id'] as String)) {
          changed = true;
        }
      }
    }
    allowed = widget.categories.where((c) => ids.contains(c['id'])).toList();
    category = s?['category_node_id'] as String?;
    if (!allowed.any((c) => c['id'] == category)) {
      category = null;
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    gallery.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    try {
      pricing.validate(double.parse(price.text.trim()));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    setState(() => busy = true);
    try {
      await repo.saveService(id, widget.business.id, {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'price': double.parse(price.text.trim()),
        ...pricing.toMap(),
        'category_node_id': category,
        'vendor_enabled': enabled,
        'gallery': gallery.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: VendorPageScaffold(
      appBar: AppBar(
        title: Text(widget.service == null ? 'Add service' : 'Edit service'),
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.business.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Service name'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter a service name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: allowed
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => category = v,
                validator: (v) =>
                    v == null ? 'Choose a business category' : null,
              ),
              if (allowed.isEmpty)
                const Text('Edit the business and choose categories first.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Service description',
                ),
              ),
              const SizedBox(height: 16),
              ServicePricingFields(
                value: pricing,
                onChanged: (value) => setState(() => pricing = value),
              ),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price (INR)'),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  return n == null || !n.isFinite || n < 0
                      ? 'Enter a valid price'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: gallery,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Gallery image URLs (one per line)',
                ),
                validator: (v) {
                  for (final line
                      in (v ?? '')
                          .split('\n')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)) {
                    final u = Uri.tryParse(line);
                    if (u == null ||
                        !['https', 'http'].contains(u.scheme) ||
                        u.host.isEmpty) {
                      return 'Enter full image URLs, one per line';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable service'),
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
              if (widget.business.availabilityStatus != 'active')
                const Text(
                  'This service stays hidden until the business is active.',
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: save,
                child: Text(busy ? 'Saving…' : 'Save service'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
