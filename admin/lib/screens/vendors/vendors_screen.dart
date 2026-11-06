import 'package:flutter/material.dart';

import '../../models/vendor_model.dart';
import '../../repositories/vendor_repository.dart';

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({
    super.key,
  });

  @override
  State<VendorsScreen> createState() =>
      _VendorsScreenState();
}

class _VendorsScreenState
    extends State<VendorsScreen> {
  final VendorRepository _repository =
      VendorRepository();

  final TextEditingController _searchController =
      TextEditingController();

  List<VendorModel> _vendors = [];

  bool _isLoading = true;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD VENDORS
  // ============================================================

  Future<void> _loadVendors() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final vendors =
          await _repository.getVendors();

      if (!mounted) return;

      setState(() {
        _vendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Failed to load vendors.\n$e',
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<VendorModel> get _filteredVendors {
    final query =
        _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _vendors;
    }

    return _vendors.where((vendor) {
      final name =
          vendor.name.toLowerCase();

      final email =
          vendor.email.toLowerCase();

      final id =
          vendor.id.toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          id.contains(query);
    }).toList();
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteVendor(
    VendorModel vendor,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Vendor?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${vendor.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
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
      await _repository.deleteVendor(
        vendor.id,
      );

      if (!mounted) return;

      _showMessage(
        'Vendor deleted successfully',
      );

      await _loadVendors();
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Failed to delete vendor.\n$e',
      );
    }
  }

  // ============================================================
  // BUILD
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
                      'Vendors',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage Eventor vendors',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Vendor count
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  '${_vendors.length} Vendors',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading
                    ? null
                    : _loadVendors,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search
          TextField(
            controller:
                _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search vendors by name, email or ID...',
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

                            setState(() {
                              _searchQuery =
                                  '';
                            });
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
        child:
            CircularProgressIndicator(),
      );
    }

    final vendors =
        _filteredVendors;

    if (vendors.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadVendors,
      child: ListView.separated(
        padding:
            const EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24,
        ),
        itemCount: vendors.length,
        separatorBuilder:
            (context, index) =>
                const SizedBox(height: 12),
        itemBuilder:
            (context, index) {
          return _buildVendorCard(
            vendors[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // VENDOR CARD
  // ============================================================

  Widget _buildVendorCard(
    VendorModel vendor,
  ) {
    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer,
              child: Text(
                _getInitial(
                  vendor.name,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Vendor information
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .email_outlined,
                        size: 16,
                        color: Colors
                            .grey.shade600,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Expanded(
                        child: Text(
                          vendor.email,
                          style: TextStyle(
                            color: Colors
                                .grey.shade700,
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .fingerprint,
                        size: 16,
                        color: Colors
                            .grey.shade600,
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Expanded(
                        child: Text(
                          vendor.id,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors
                                .grey.shade600,
                          ),
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Joined ${_formatDate(vendor.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteVendor(vendor);
                }
              },
              itemBuilder:
                  (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .delete_outline,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                      ),
                    ],
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
  // EMPTY STATE
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
              Icons.storefront_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'No vendors found',
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
                  : 'No vendors are registered yet.',
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
  // HELPERS
  // ============================================================

  String _getInitial(
    String name,
  ) {
    final trimmed =
        name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    return trimmed
        .substring(0, 1)
        .toUpperCase();
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Unknown';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

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