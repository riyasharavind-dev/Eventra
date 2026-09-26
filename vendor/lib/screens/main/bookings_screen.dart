import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../widgets/bookings/booking_details_dialog.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
  });

  @override
  State<BookingsScreen> createState() =>
      _BookingsScreenState();
}

class _BookingsScreenState
    extends State<BookingsScreen> {
  // ============================================================
  // REPOSITORY
  // ============================================================

  final BookingRepository _repository =
      BookingRepository();

  // ============================================================
  // STATE
  // ============================================================

  List<BookingModel> _bookings = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _selectedFilter = 'all';

  String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadBookings();
  }

  // ============================================================
  // LOAD BOOKINGS
  // ============================================================

  Future<void> _loadBookings() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user =
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Vendor is not logged in.',
        );
      }

      final bookings =
          await _repository.getVendorBookings(
        user.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  // ============================================================
  // FILTERED BOOKINGS
  // ============================================================

  List<BookingModel>
      get _filteredBookings {
    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    return _bookings.where(
      (booking) {
        final bool matchesFilter =
            _selectedFilter == 'all' ||
                booking.status ==
                    _selectedFilter;

        if (!matchesFilter) {
          return false;
        }

        if (query.isEmpty) {
          return true;
        }

        return booking.customerName
                .toLowerCase()
                .contains(query) ||
            booking.customerEmail
                .toLowerCase()
                .contains(query) ||
            booking.serviceName
                .toLowerCase()
                .contains(query) ||
            booking.location
                .toLowerCase()
                .contains(query) ||
            booking.id
                .toLowerCase()
                .contains(query);
      },
    ).toList();
  }

  // ============================================================
  // STATUS COUNT
  // ============================================================

  int _countStatus(
    String status,
  ) {
    return _bookings
        .where(
          (booking) =>
              booking.status == status,
        )
        .length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: CustomScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ----------------------------------------------------
          // HEADER
          // ----------------------------------------------------

          SliverPadding(
            padding:
                const EdgeInsets.all(20),
            sliver:
                SliverToBoxAdapter(
              child: _buildHeader(),
            ),
          ),

          // ----------------------------------------------------
          // FILTERS
          // ----------------------------------------------------

          SliverPadding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            sliver:
                SliverToBoxAdapter(
              child: _buildFilters(),
            ),
          ),

          // ----------------------------------------------------
          // CONTENT
          // ----------------------------------------------------

          SliverPadding(
            padding:
                const EdgeInsets.all(20),
            sliver: _buildContent(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Bookings',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Manage customer booking requests for your services.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadBookings,
          icon: const Icon(
            Icons.refresh,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------
        // SEARCH
        // ------------------------------------------------------

        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration:
              InputDecoration(
            hintText:
                'Search customer, service, location...',
            prefixIcon:
                const Icon(
              Icons.search,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        // ------------------------------------------------------
        // FILTER CHIPS
        // ------------------------------------------------------

        SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                count:
                    _bookings.length,
                selected:
                    _selectedFilter ==
                        'all',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'all';
                  });
                },
              ),

              _FilterChip(
                label: 'Pending',
                count:
                    _countStatus(
                  'pending',
                ),
                selected:
                    _selectedFilter ==
                        'pending',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'pending';
                  });
                },
              ),

              _FilterChip(
                label: 'Accepted',
                count:
                    _countStatus(
                  'accepted',
                ),
                selected:
                    _selectedFilter ==
                        'accepted',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'accepted';
                  });
                },
              ),

              _FilterChip(
                label: 'Rejected',
                count:
                    _countStatus(
                  'rejected',
                ),
                selected:
                    _selectedFilter ==
                        'rejected',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'rejected';
                  });
                },
              ),

              _FilterChip(
                label: 'Completed',
                count:
                    _countStatus(
                  'completed',
                ),
                selected:
                    _selectedFilter ==
                        'completed',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'completed';
                  });
                },
              ),

              _FilterChip(
                label: 'Cancelled',
                count:
                    _countStatus(
                  'cancelled',
                ),
                selected:
                    _selectedFilter ==
                        'cancelled',
                onTap: () {
                  setState(() {
                    _selectedFilter =
                        'cancelled';
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(),
      );
    }

    final List<BookingModel>
        bookings =
        _filteredBookings;

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (bookings.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    // ----------------------------------------------------------
    // LIST
    // ----------------------------------------------------------

    return SliverList(
      delegate:
          SliverChildBuilderDelegate(
        (context, index) {
          final BookingModel booking =
              bookings[index];

          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 14,
            ),
            child: _BookingCard(
              booking: booking,

              onView: () {
                _showBookingDetails(
                  booking,
                );
              },

              onAccept:
                  booking.status ==
                          'pending'
                      ? () {
                          _acceptBooking(
                            booking,
                          );
                        }
                      : null,

              onReject:
                  booking.status ==
                          'pending'
                      ? () {
                          _rejectBooking(
                            booking,
                          );
                        }
                      : null,
            ),
          );
        },
        childCount:
            bookings.length,
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 64,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            _searchQuery.isNotEmpty
                ? 'No bookings found'
                : 'No bookings yet',
            style:
                const TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search.'
                : 'New customer booking requests will appear here.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'Unable to load bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            ElevatedButton.icon(
              onPressed:
                  _loadBookings,
              icon:
                  const Icon(
                Icons.refresh,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SHOW BOOKING DETAILS
  // ============================================================

  void _showBookingDetails(
    BookingModel booking,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          BookingDetailsDialog(
        booking: booking,
      ),
    );
  }

  // ============================================================
  // ACCEPT BOOKING
  // ============================================================

  Future<void> _acceptBooking(
    BookingModel booking,
  ) async {
    final bool? confirmed =
        await _showConfirmationDialog(
      title: 'Accept Booking?',
      message:
          'Accept this booking request from ${booking.customerName}?',
      confirmText: 'Accept',
    );

    if (confirmed != true) {
      return;
    }

    await _changeBookingStatus(
      booking,
      'accepted',
    );
  }

  // ============================================================
  // REJECT BOOKING
  // ============================================================

  Future<void> _rejectBooking(
    BookingModel booking,
  ) async {
    final bool? confirmed =
        await _showConfirmationDialog(
      title: 'Reject Booking?',
      message:
          'Reject this booking request from ${booking.customerName}?',
      confirmText: 'Reject',
      isDestructive: true,
    );

    if (confirmed != true) {
      return;
    }

    await _changeBookingStatus(
      booking,
      'rejected',
    );
  }

  // ============================================================
  // CHANGE BOOKING STATUS
  // ============================================================

  Future<void> _changeBookingStatus(
    BookingModel booking,
    String status,
  ) async {
    try {
      final User? user =
          Supabase.instance.client.auth
              .currentUser;

      if (user == null) {
        throw Exception(
          'Vendor is not logged in.',
        );
      }

      await _repository
          .updateBookingStatus(
        bookingId: booking.id,
        vendorId: user.id,
        status: status,
      );

      if (!mounted) {
        return;
      }

      await _loadBookings();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted'
                ? 'Booking accepted successfully.'
                : 'Booking rejected successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
          backgroundColor:
              Colors.red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================

  Future<bool?>
      _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),

          content: Text(message),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),

            ElevatedButton(
              style: isDestructive
                  ? ElevatedButton
                      .styleFrom(
                      backgroundColor:
                          Colors.red,
                      foregroundColor:
                          Colors.white,
                    )
                  : null,

              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
                  Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// BOOKING CARD
// =================================================================

class _BookingCard
    extends StatelessWidget {
  final BookingModel booking;

  final VoidCallback onView;

  final VoidCallback? onAccept;

  final VoidCallback? onReject;

  const _BookingCard({
    required this.booking,
    required this.onView,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,

      margin: EdgeInsets.zero,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        side: BorderSide(
          color:
              Colors.grey.withValues(
            alpha: 0.20,
          ),
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // TOP ROW
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                _StatusBadge(
                  status:
                      booking.status,
                ),
              ],
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Booking #${_shortId(booking.id)}',
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // CUSTOMER
            // ==================================================

            _DetailLine(
              icon:
                  Icons.person_outline,
              label: 'Customer',
              value:
                  booking.customerName,
            ),

            _DetailLine(
              icon:
                  Icons.email_outlined,
              label: 'Email',
              value:
                  booking.customerEmail,
            ),

            // ==================================================
            // EVENT DATE
            // ==================================================

            _DetailLine(
              icon:
                  Icons.calendar_today_outlined,
              label: 'Event Date',
              value:
                  _formatDate(
                booking.eventDate,
              ),
            ),

            // ==================================================
            // GUESTS
            // ==================================================

            _DetailLine(
              icon:
                  Icons.people_outline,
              label: 'Guests',
              value:
                  booking.guestCount
                          ?.toString() ??
                      'Not specified',
            ),

            // ==================================================
            // LOCATION
            // ==================================================

            _DetailLine(
              icon:
                  Icons.location_on_outlined,
              label: 'Location',
              value:
                  booking.location,
            ),

            const SizedBox(
              height: 10,
            ),

            // ==================================================
            // PRICE
            // ==================================================

            Row(
              children: [
                const Text(
                  'Booking Price',
                  style:
                      TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),

                const Spacer(),

                Text(
                  '₹${booking.price.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ACTION BUTTONS
            // ==================================================

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onView,
                  icon:
                      const Icon(
                    Icons
                        .visibility_outlined,
                  ),
                  label:
                      const Text(
                    'View',
                  ),
                ),

                const Spacer(),

                // ----------------------------------------------
                // REJECT
                // ----------------------------------------------

                if (onReject != null)
                  OutlinedButton.icon(
                    onPressed:
                        onReject,
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          Colors.red,
                      side:
                          const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                    icon:
                        const Icon(
                      Icons.close,
                    ),
                    label:
                        const Text(
                      'Reject',
                    ),
                  ),

                if (onReject != null &&
                    onAccept != null)
                  const SizedBox(
                    width: 8,
                  ),

                // ----------------------------------------------
                // ACCEPT
                // ----------------------------------------------

                if (onAccept != null)
                  ElevatedButton.icon(
                    onPressed:
                        onAccept,
                    icon:
                        const Icon(
                      Icons.check,
                    ),
                    label:
                        const Text(
                      'Accept',
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
  // SHORT BOOKING ID
  // ============================================================

  String _shortId(
    String id,
  ) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(
      0,
      8,
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not specified';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// =================================================================
// DETAIL LINE
// =================================================================

class _DetailLine
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey,
          ),

          const SizedBox(
            width: 10,
          ),

          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// STATUS BADGE
// =================================================================

class _StatusBadge
    extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;

      case 'rejected':
        color = Colors.red;
        break;

      case 'completed':
        color = Colors.blue;
        break;

      case 'cancelled':
        color = Colors.grey;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Text(
        status.toUpperCase(),

        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}

// =================================================================
// FILTER CHIP
// =================================================================

class _FilterChip
    extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),

      child: ChoiceChip(
        label: Text(
          '$label ($count)',
        ),

        selected: selected,

        onSelected: (_) {
          onTap();
        },
      ),
    );
  }
}