import 'package:flutter/material.dart';

import '../../models/event_type_model.dart';
import '../../repositories/event_type_repository.dart';
import '../../widgets/event_types/event_type_form_dialog.dart';

class EventTypesScreen extends StatefulWidget {
  const EventTypesScreen({
    super.key,
  });

  @override
  State<EventTypesScreen> createState() =>
      _EventTypesScreenState();
}

class _EventTypesScreenState
    extends State<EventTypesScreen> {
  final EventTypeRepository _repository =
      EventTypeRepository();

  final TextEditingController
      _searchController =
      TextEditingController();

  List<EventTypeModel> _eventTypes = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _refreshSearch,
    );

    _loadEventTypes();
  }

  @override
  void dispose() {
    _searchController.removeListener(
      _refreshSearch,
    );
    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadEventTypes() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result =
          await _repository.getEventTypes();

      if (!mounted) return;

      setState(() {
        _eventTypes = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  List<EventTypeModel>
      get _filteredEventTypes {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return _eventTypes;
    }

    return _eventTypes.where((event) {
      return event.name
              .toLowerCase()
              .contains(query) ||
          event.slug
              .toLowerCase()
              .contains(query) ||
          (event.description ?? '')
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addEventType() async {
    final result =
        await showDialog<EventTypeModel>(
      context: context,
      builder: (context) {
        return const EventTypeFormDialog();
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _repository.createEventType(
        result,
      );

      if (!mounted) return;

      _showMessage(
        'Event type created successfully',
      );

      await _loadEventTypes();
    } catch (e) {
      if (!mounted) return;

      _showError(
        _formatError(e),
      );
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editEventType(
    EventTypeModel eventType,
  ) async {
    final result =
        await showDialog<EventTypeModel>(
      context: context,
      builder: (context) {
        return EventTypeFormDialog(
          eventType: eventType,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _repository.updateEventType(
        result,
      );

      if (!mounted) return;

      _showMessage(
        'Event type updated successfully',
      );

      await _loadEventTypes();
    } catch (e) {
      if (!mounted) return;

      _showError(
        _formatError(e),
      );
    }
  }

  // ============================================================
  // TOGGLE
  // ============================================================

  Future<void> _toggleEventType(
    EventTypeModel eventType,
  ) async {
    try {
      await _repository.toggleEventType(
        eventType,
      );

      if (!mounted) return;

      _showMessage(
        eventType.isActive
            ? 'Event type deactivated'
            : 'Event type activated',
      );

      await _loadEventTypes();
    } catch (e) {
      if (!mounted) return;

      _showError(
        _formatError(e),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteEventType(
    EventTypeModel eventType,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Event Type?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${eventType.name}"?\n\n'
            'If this event type is already linked '
            'to a service, Supabase may prevent '
            'the deletion.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .error,
              ),
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteEventType(
        eventType.id,
      );

      if (!mounted) return;

      _showMessage(
        'Event type deleted',
      );

      await _loadEventTypes();
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Cannot delete this event type. '
        'It may already be used by a service.',
      );
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
          content: Text(message),
        ),
      );
  }

  String _formatError(Object error) {
    final text = error.toString();

    if (text.contains('23505') ||
        text.toLowerCase().contains(
              'duplicate',
            )) {
      return 'This event name or slug already exists.';
    }

    return text;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered =
        _filteredEventTypes;

    return Scaffold(
      backgroundColor:
          Theme.of(context)
              .colorScheme
              .surface,
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      Icons.event_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Event Types',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage event and occasion types used across Eventra.',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  FilledButton.icon(
                    onPressed:
                        _addEventType,
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Add Event',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SEARCH
              TextField(
                controller:
                    _searchController,
                decoration:
                    InputDecoration(
                  hintText:
                      'Search event types...',
                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),
                  suffixIcon:
                      _searchController
                              .text
                              .isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController
                                    .clear();
                              },
                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                            )
                          : null,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child:
                    _buildContent(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    List<EventTypeModel> events,
  ) {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load event types',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _loadEventTypes,
              icon: const Icon(
                Icons.refresh,
              ),
              label:
                  const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              size: 60,
            ),
            const SizedBox(height: 14),
            const Text(
              'No Event Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first event type.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed:
                  _addEventType,
              icon:
                  const Icon(Icons.add),
              label: const Text(
                'Add Event Type',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEventTypes,
      child: GridView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 235,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: events.length,
        itemBuilder:
            (context, index) {
          return _buildEventCard(
            events[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildEventCard(
    EventTypeModel event,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        side: BorderSide(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(
                    color: event.isActive
                        ? theme
                            .colorScheme
                            .primaryContainer
                        : theme
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    _getIcon(
                      event.icon,
                    ),
                    color: event
                            .isActive
                        ? theme
                            .colorScheme
                            .onPrimaryContainer
                        : theme
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        event.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        event.slug,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<
                    String>(
                  onSelected:
                      (value) {
                    switch (value) {
                      case 'edit':
                        _editEventType(
                          event,
                        );
                        break;

                      case 'toggle':
                        _toggleEventType(
                          event,
                        );
                        break;

                      case 'delete':
                        _deleteEventType(
                          event,
                        );
                        break;
                    }
                  },
                  itemBuilder:
                      (context) {
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(
                            Icons
                                .edit_outlined,
                          ),
                          title:
                              Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: ListTile(
                          leading:
                              Icon(
                            event.isActive
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),
                          title:
                              Text(
                            event.isActive
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(
                            Icons
                                .delete_outline,
                            color:
                                Colors.red,
                          ),
                          title:
                              Text(
                            'Delete',
                            style:
                                TextStyle(
                              color:
                                  Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              event.description
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? event.description!
                  : 'No description',
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const Spacer(),

            Row(
              children: [
                _statusBadge(
                  event.isActive,
                ),
                const Spacer(),
                Text(
                  'Order: ${event.sortOrder}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusBadge(
    bool active,
  ) {
    final color =
        active ? Colors.green : Colors.grey;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(
              color: color,
              shape:
                  BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active
                ? 'ACTIVE'
                : 'INACTIVE',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _getIcon(
    String? icon,
  ) {
    switch (
        icon?.toLowerCase()) {
      case 'favorite':
        return Icons.favorite_outline;

      case 'cake':
        return Icons.cake_outlined;

      case 'celebration':
        return Icons.celebration_outlined;

      case 'business':
        return Icons.business_outlined;

      case 'school':
        return Icons.school_outlined;

      case 'home':
        return Icons.home_outlined;

      case 'child':
        return Icons.child_care_outlined;

      case 'groups':
        return Icons.groups_outlined;

      case 'work':
        return Icons.work_outline;

      default:
        return Icons.event_outlined;
    }
  }
}