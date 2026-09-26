import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/services/service_details_dialog.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
  });

  @override
  State<ServicesScreen> createState() =>
      _ServicesScreenState();
}

class _ServicesScreenState
    extends State<ServicesScreen> {
  final ServiceRepository _repository =
      ServiceRepository();

  final TextEditingController _searchController =
      TextEditingController();

  List<ServiceModel> _services = [];

  bool _isLoading = true;

  String _searchQuery = '';

  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final services =
          await _repository.getServices();

      if (!mounted) return;

      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Failed to load services.\n$e',
      );
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<ServiceModel> get _filteredServices {
    final query =
        _searchQuery.trim().toLowerCase();

    return _services.where((service) {
      // Status
      if (_statusFilter == 'active' &&
          !service.isActive) {
        return false;
      }

      if (_statusFilter == 'inactive' &&
          service.isActive) {
        return false;
      }

      // Search
      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        service.name,
        service.slug,
        service.description ?? '',
        service.vendorName ?? '',
        service.vendorEmail ?? '',
        service.categoryName ?? '',
        service.eventTypeName ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  // ============================================================
  // VIEW DETAILS
  // ============================================================

  void _showDetails(
    ServiceModel service,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return ServiceDetailsDialog(
          service: service,
        );
      },
    );
  }

  // ============================================================
  // TOGGLE
  // ============================================================

  Future<void> _toggleService(
    ServiceModel service,
  ) async {
    try {
      await _repository.toggleService(
        service,
      );

      if (!mounted) return;

      _showMessage(
        service.isActive
            ? 'Service deactivated'
            : 'Service activated',
      );

      await _loadServices();
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Failed to update service.\n$e',
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteService(
    ServiceModel service,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Service?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${service.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteService(
        service.id,
      );

      if (!mounted) return;

      _showMessage(
        'Service deleted successfully',
      );

      await _loadServices();
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Failed to delete service.\n$e',
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(
    String value,
  ) {
    setState(() {
      _searchQuery = value;
    });
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),

        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage vendor services',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading
                    ? null
                    : _loadServices,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _searchController,
                  onChanged:
                      _onSearchChanged,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Search services...',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController
                                      .clear();

                                  _onSearchChanged(
                                    '',
                                  );
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
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 150,
                child: DropdownButtonFormField<
                    String>(
                  initialValue:
                      _statusFilter,
                  decoration:
                      InputDecoration(
                    labelText: 'Status',
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'All',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(
                        'Active',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text(
                        'Inactive',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _statusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final services =
        _filteredServices;

    if (services.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView.separated(
        padding:
            const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24,
        ),
        itemCount: services.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(height: 12),
        itemBuilder:
            (context, index) {
          return _buildServiceCard(
            services[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard(
    ServiceModel service,
  ) {
    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showDetails(service);
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildImage(service),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style:
                                const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),

                        _buildStatusBadge(
                          service.isActive,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      service.slug,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey.shade600,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metaItem(
                          Icons.storefront_outlined,
                          service.vendorName ??
                              'Unknown vendor',
                        ),
                        _metaItem(
                          Icons.category_outlined,
                          service.categoryName ??
                              'No category',
                        ),
                        _metaItem(
                          Icons.event_outlined,
                          service.eventTypeName ??
                              'No event type',
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      children: [
                        Text(
                          '₹${service.price.toStringAsFixed(2)}',
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const Spacer(),

                        IconButton(
                          tooltip:
                              'View Details',
                          onPressed: () {
                            _showDetails(
                              service,
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .visibility_outlined,
                          ),
                        ),

                        IconButton(
                          tooltip: service
                                  .isActive
                              ? 'Deactivate'
                              : 'Activate',
                          onPressed: () {
                            _toggleService(
                              service,
                            );
                          },
                          icon: Icon(
                            service.isActive
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),
                        ),

                        IconButton(
                          tooltip:
                              'Delete',
                          onPressed: () {
                            _deleteService(
                              service,
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage(
    ServiceModel service,
  ) {
    if (service.gallery.isEmpty) {
      return Container(
        width: 120,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons
              .miscellaneous_services_outlined,
          size: 35,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        service.gallery.first,
        width: 120,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) {
          return Container(
            width: 120,
            height: 90,
            color: Colors.grey.shade100,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusBadge(
    bool isActive,
  ) {
    final background =
        isActive
            ? Colors.green.withValues(
                alpha: 0.10,
              )
            : Colors.red.withValues(
                alpha: 0.10,
              );

    final foreground =
        isActive
            ? Colors.green.shade700
            : Colors.red.shade700;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        isActive
            ? 'Active'
            : 'Inactive',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // META ITEM
  // ============================================================

  Widget _metaItem(
    IconData icon,
    String text,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .miscellaneous_services_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'No services found',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _searchQuery.isNotEmpty
                  ? 'Try another search.'
                  : 'No vendor services are available yet.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}