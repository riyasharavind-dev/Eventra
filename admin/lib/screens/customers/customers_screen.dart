import 'package:flutter/material.dart';

import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
  });

  @override
  State<CustomersScreen> createState() =>
      _CustomersScreenState();
}

class _CustomersScreenState
    extends State<CustomersScreen> {

  final CustomerRepository _repository =
      CustomerRepository();

  final TextEditingController _searchController =
      TextEditingController();

  List<CustomerModel> _customers = [];

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });

    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers =
          await _repository.getCustomers();

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError(
        'Unable to load customers',
        e.toString(),
      );
    }
  }

  // ============================================================
  // DELETE CUSTOMER
  // ============================================================

  Future<void> _deleteCustomer(
    CustomerModel customer,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Customer?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '${customer.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteCustomer(
        customer.id,
      );

      if (!mounted) return;

      setState(() {
        _customers.removeWhere(
          (item) => item.id == customer.id,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Customer deleted successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to delete customer',
        e.toString(),
      );
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<CustomerModel> get _filteredCustomers {
    if (_searchQuery.isEmpty) {
      return _customers;
    }

    return _customers.where((customer) {
      return customer.name
              .toLowerCase()
              .contains(_searchQuery) ||
          customer.email
              .toLowerCase()
              .contains(_searchQuery) ||
          customer.id
              .toLowerCase()
              .contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return '-';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final customers =
        _filteredCustomers;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            // ==================================================
            // SEARCH + REFRESH
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _searchController,
                      decoration:
                          InputDecoration(
                        hintText:
                            'Search customers...',
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

                  IconButton(
                    tooltip: 'Refresh',
                    onPressed:
                        _isLoading
                            ? null
                            : _loadCustomers,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CUSTOMER COUNT
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Text(
                    '${customers.length} Customers',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: _buildContent(
                customers,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    List<CustomerModel> customers,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (customers.isEmpty) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(32),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No customers found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? 'No customers have registered yet.'
                    : 'Try another search.',
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        30,
      ),
      itemCount: customers.length,
      itemBuilder: (
        context,
        index,
      ) {
        final customer =
            customers[index];

        return _buildCustomerCard(
          customer,
        );
      },
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  Widget _buildCustomerCard(
    CustomerModel customer,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [

            // AVATAR
            CircleAvatar(
              radius: 25,
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0]
                        .toUpperCase()
                    : '?',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    customer.name,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    customer.email,
                    style:
                        const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'ID: ${customer.id}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Joined: ${_formatDate(customer.createdAt)}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // DELETE
            IconButton(
              tooltip:
                  'Delete Customer',
              onPressed: () =>
                  _deleteCustomer(
                customer,
              ),
              icon: const Icon(
                Icons.delete_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}