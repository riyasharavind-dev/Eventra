import 'package:flutter/material.dart';

import '../../models/event_type_model.dart';

class EventTypeFormDialog extends StatefulWidget {
  final EventTypeModel? eventType;

  const EventTypeFormDialog({
    super.key,
    this.eventType,
  });

  @override
  State<EventTypeFormDialog> createState() =>
      _EventTypeFormDialogState();
}

class _EventTypeFormDialogState
    extends State<EventTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController
      _descriptionController;
  late final TextEditingController _iconController;
  late final TextEditingController
      _imageUrlController;
  late final TextEditingController
      _sortOrderController;

  bool _isActive = true;

  bool get _isEditing =>
      widget.eventType != null;

  @override
  void initState() {
    super.initState();

    final event = widget.eventType;

    _nameController = TextEditingController(
      text: event?.name ?? '',
    );

    _slugController = TextEditingController(
      text: event?.slug ?? '',
    );

    _descriptionController =
        TextEditingController(
      text: event?.description ?? '',
    );

    _iconController = TextEditingController(
      text: event?.icon ?? '',
    );

    _imageUrlController =
        TextEditingController(
      text: event?.imageUrl ?? '',
    );

    _sortOrderController =
        TextEditingController(
      text: (event?.sortOrder ?? 0).toString(),
    );

    _isActive = event?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();

    super.dispose();
  }

  // ============================================================
  // SLUG
  // ============================================================

  String _generateSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        )
        .replaceAll(
          RegExp(r'^-+|-+$'),
          '');
  }

  // ============================================================
  // SAVE
  // ============================================================

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name =
        _nameController.text.trim();

    var slug =
        _slugController.text.trim();

    if (slug.isEmpty) {
      slug = _generateSlug(name);
    } else {
      slug = _generateSlug(slug);
    }

    final sortOrder = int.tryParse(
          _sortOrderController.text.trim(),
        ) ??
        0;

    final eventType = EventTypeModel(
      id: widget.eventType?.id ?? '',
      name: name,
      slug: slug,
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      icon:
          _iconController.text.trim().isEmpty
              ? null
              : _iconController.text.trim(),
      imageUrl:
          _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
      isActive: _isActive,
      sortOrder: sortOrder,
      createdAt:
          widget.eventType?.createdAt,
      updatedAt:
          widget.eventType?.updatedAt,
    );

    Navigator.of(context).pop(eventType);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing
                ? Icons.edit_outlined
                : Icons.event_outlined,
          ),
          const SizedBox(width: 10),
          Text(
            _isEditing
                ? 'Edit Event Type'
                : 'Add Event Type',
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                // EVENT NAME
                TextFormField(
                  controller: _nameController,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration:
                      const InputDecoration(
                    labelText: 'Event Name',
                    hintText: 'Wedding',
                    prefixIcon:
                        Icon(Icons.event_outlined),
                    border:
                        OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (!_isEditing) {
                      _slugController.text =
                          _generateSlug(value);
                    }
                  },
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter event name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // SLUG
                TextFormField(
                  controller: _slugController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Slug',
                    hintText: 'wedding',
                    prefixIcon:
                        Icon(Icons.link_outlined),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter slug';
                    }

                    final slug =
                        _generateSlug(
                      value,
                    );

                    if (slug.isEmpty) {
                      return 'Enter a valid slug';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // DESCRIPTION
                TextFormField(
                  controller:
                      _descriptionController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Wedding related events',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 16),

                // ICON
                TextFormField(
                  controller: _iconController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Icon',
                    hintText:
                        'favorite / cake / celebration',
                    prefixIcon: Icon(
                      Icons.emoji_emotions_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // IMAGE URL
                TextFormField(
                  controller:
                      _imageUrlController,
                  keyboardType:
                      TextInputType.url,
                  decoration:
                      const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'https://...',
                    prefixIcon:
                        Icon(Icons.image_outlined),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // SORT ORDER
                TextFormField(
                  controller:
                      _sortOrderController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText: 'Sort Order',
                    hintText: '1',
                    prefixIcon:
                        Icon(Icons.sort_outlined),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter sort order';
                    }

                    if (int.tryParse(
                          value.trim(),
                        ) ==
                        null) {
                      return 'Enter a valid number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // ACTIVE
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'Active',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Visible to vendors'
                        : 'Hidden from vendors',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(
            Icons.save_outlined,
          ),
          label: Text(
            _isEditing
                ? 'Update'
                : 'Create',
          ),
        ),
      ],
    );
  }
}