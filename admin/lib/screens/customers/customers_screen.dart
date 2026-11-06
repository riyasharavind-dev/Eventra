import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/auth_model.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  List<AuthModel> _customers = [];
  List<AuthModel> _filteredCustomers = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterCustomers);
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCustomers);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> _loadCustomers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('customers')
          .select(
            '''
            id,
            name,
            email,
            created_at,
            phone,
            avatar_url,
            updated_at,
            address,
            latitude,
            longitude
            ''',
          )
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;

      final List<AuthModel> customers = rows.map((row) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(row as Map);

        // customers table doesn't need a role column.
        // Admin screen knows these records are customers.
        data['role'] = 'customer';

        return AuthModel.fromMap(data);
      }).toList();

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterCustomers() {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _customers;
      });
      return;
    }

    final List<AuthModel> filtered = _customers.where((customer) {
      final String name = customer.name.toLowerCase();
      final String email = customer.email.toLowerCase();
      final String phone = customer.phone?.toLowerCase() ?? '';
      final String address = customer.address?.toLowerCase() ?? '';
      final String id = customer.id.toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          address.contains(query) ||
          id.contains(query);
    }).toList();

    setState(() {
      _filteredCustomers = filtered;
    });
  }

  // ============================================================
  // DELETE CUSTOMER
  // ============================================================

  Future<void> _deleteCustomer(AuthModel customer) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Customer'),
          content: Text(
            'Are you sure you want to delete ${customer.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('customers')
          .delete()
          .eq('id', customer.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${customer.name} deleted successfully'),
        ),
      );

      await _loadCustomers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(AuthModel customer, {double size = 54}) {
    final String? avatarUrl = customer.avatarUrl;

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialAvatar(customer, size);
          },
        ),
      );
    }

    return _buildInitialAvatar(customer, size);
  }

  Widget _buildInitialAvatar(AuthModel customer, double size) {
    final String initial = customer.name.trim().isNotEmpty
        ? customer.name.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xFFC00000),
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  Widget _customerCard(AuthModel customer) {
    final String joinedDate = customer.createdAt != null
        ? _formatDate(customer.createdAt!)
        : 'Unknown';

    final bool hasCoordinates =
        customer.latitude != null && customer.longitude != null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(customer, size: 58),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name.isEmpty
                            ? 'Unnamed Customer'
                            : customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8E8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CUSTOMER',
                          style: TextStyle(
                            color: Color(0xFFC00000),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteCustomer(customer);
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // INFORMATION
            // --------------------------------------------------

            _infoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: customer.email,
            ),

            _infoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: customer.phone ?? '',
            ),

            _infoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: customer.address ?? '',
            ),

            if (hasCoordinates)
              _infoRow(
                icon: Icons.my_location,
                label: 'Location',
                value:
                    '${customer.latitude!.toStringAsFixed(6)}, '
                    '${customer.longitude!.toStringAsFixed(6)}',
              ),

            _infoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Joined',
              value: joinedDate,
            ),

            const SizedBox(height: 6),

            // --------------------------------------------------
            // USER ID
            // --------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ID: ${customer.id}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    final bool searching = _searchController.text.trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 38,
              color: Color(0xFFC00000),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            searching ? 'No customers found' : 'No customers yet',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            searching
                ? 'Try a different search term.'
                : 'Customers will appear here after registration.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();

    return '$day/$month/$year';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      body: Column(
        children: [
          // ====================================================
          // HEADER
          // ====================================================

          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF6DEDE),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  icon: const Icon(Icons.menu),
                ),

                const SizedBox(width: 12),

                const Text(
                  'Customers',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(),

                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadCustomers,
                  icon: const Icon(
                    Icons.refresh,
                    color: Color(0xFFC00000),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // CONTENT
          // ====================================================

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customers',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Manage customer profiles and information',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CUSTOMER COUNT
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              color: Color(0xFFC00000),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_customers.length}',
                              style: const TextStyle(
                                color: Color(0xFFC00000),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // REFRESH
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _loadCustomers,
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFFC00000),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // SEARCH
                  // ------------------------------------------------

                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, email, phone, address or ID...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFC00000),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFFC00000),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // BODY
                  // ------------------------------------------------

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFC00000),
                            ),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Unable to load customers',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: _loadCustomers,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _filteredCustomers.isEmpty
                                ? _emptyState()
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      int crossAxisCount;

                                      if (constraints.maxWidth >= 1500) {
                                        crossAxisCount = 4;
                                      } else if (constraints.maxWidth >= 1050) {
                                        crossAxisCount = 3;
                                      } else if (constraints.maxWidth >= 700) {
                                        crossAxisCount = 2;
                                      } else {
                                        crossAxisCount = 1;
                                      }

                                      return GridView.builder(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount:
                                              crossAxisCount,
                                          crossAxisSpacing: 18,
                                          mainAxisSpacing: 18,
                                          childAspectRatio:
                                              crossAxisCount == 1
                                                  ? 1.8
                                                  : 1.05,
                                        ),
                                        itemCount:
                                            _filteredCustomers.length,
                                        itemBuilder:
                                            (context, index) {
                                          return _customerCard(
                                            _filteredCustomers[index],
                                          );
                                        },
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}