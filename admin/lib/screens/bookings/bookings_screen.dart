import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';

import '../../widgets/bookings/booking_details_dialog.dart';

class BookingsScreen
    extends StatefulWidget {
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

  final BookingRepository
      _repository =
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
      final List<BookingModel>
          bookings =
          await _repository
              .getBookings();

      if (!mounted) {
        return;
      }

      setState(() {
        _bookings = bookings;

        _isLoading = false;

        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage =
            _cleanError(e);
      });
    }
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    if (error
        is PostgrestException) {
      return error.message;
    }

    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<BookingModel>
      get _filteredBookings {
    List<BookingModel>
        result;

    if (_selectedFilter ==
        'all') {
      result = List<
          BookingModel>.from(
        _bookings,
      );
    } else {
      result = _bookings
          .where(
            (BookingModel booking) =>
                booking.status
                    .toLowerCase() ==
                _selectedFilter,
          )
          .toList();
    }

    if (_searchQuery
        .trim()
        .isEmpty) {
      return result;
    }

    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    return result
        .where(
          (BookingModel booking) {
            return booking
                    .customerName
                    .toLowerCase()
                    .contains(query) ||
                booking
                    .customerEmail
                    .toLowerCase()
                    .contains(query) ||
                booking
                    .vendorName
                    .toLowerCase()
                    .contains(query) ||
                booking
                    .vendorEmail
                    .toLowerCase()
                    .contains(query) ||
                booking
                    .serviceName
                    .toLowerCase()
                    .contains(query) ||
                booking.id
                    .toLowerCase()
                    .contains(query);
          },
        )
        .toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int _countStatus(
    String status,
  ) {
    return _bookings
        .where(
          (BookingModel booking) =>
              booking.status
                  .toLowerCase() ==
              status,
        )
        .length;
  }

  // ============================================================
  // SET FILTER
  // ============================================================

  void _setFilter(
    String filter,
  ) {
    if (_selectedFilter ==
        filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
    });
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'accepted':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'rejected':
        return Colors.red;

      case 'cancelled':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;

      case 'accepted':
        return Icons.check_circle_outline;

      case 'completed':
        return Icons.done_all;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'cancelled':
        return Icons.block_outlined;

      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // PRICE
  // ============================================================

  String _formatPrice(
    double price,
  ) {
    return '₹${price.toStringAsFixed(0)}';
  }

  // ============================================================
  // SHOW DETAILS
  // ============================================================

  void _showBookingDetails(
    BookingModel booking,
  ) {
    showDialog(
      context: context,

      builder:
          (_) =>
              BookingDetailsDialog(
        booking: booking,
      ),
    );
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> _updateStatus(
    BookingModel booking,
    String status,
  ) async {
    try {
      await _repository
          .updateStatus(
        bookingId: booking.id,
        status: status,
      );

      await _loadBookings();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Booking status updated to $status.',
          ),
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
            _cleanError(e),
          ),

          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteBooking(
    BookingModel booking,
  ) async {
    final bool?
        confirmed =
        await showDialog<bool>(
      context: context,

      builder:
          (BuildContext context) {
        return AlertDialog(
          title:
              const Text(
            'Delete Booking?',
          ),

          content:
              const Text(
            'This booking will be permanently deleted.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
                  const Text(
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

              child:
                  const Text(
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
      await _repository
          .deleteBooking(
        booking.id,
      );

      await _loadBookings();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Booking deleted.',
          ),
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
            _cleanError(e),
          ),

          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // SEARCH
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                12,
              ),

              child: TextField(
                onChanged:
                    (String value) {
                  setState(() {
                    _searchQuery =
                        value;
                  });
                },

                decoration:
                    InputDecoration(
                  hintText:
                      'Search bookings...',

                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),

                  suffixIcon:
                      _searchQuery
                              .isEmpty
                          ? null
                          : IconButton(
                              onPressed:
                                  () {
                                setState(
                                  () {
                                    _searchQuery =
                                        '';
                                  },
                                );
                              },

                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                            ),

                  filled:
                      true,

                  fillColor:
                      Colors.white,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),

                    borderSide:
                        BorderSide
                            .none,
                  ),
                ),
              ),
            ),

            // ==================================================
            // FILTER CHIPS
            // ==================================================

            SizedBox(
              height: 55,

              child:
                  ListView(
                scrollDirection:
                    Axis.horizontal,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                ),

                children: [
                  _FilterChip(
                    label:
                        'All',

                    count:
                        _bookings.length,

                    selected:
                        _selectedFilter ==
                            'all',

                    onTap: () {
                      _setFilter(
                        'all',
                      );
                    },
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  _FilterChip(
                    label:
                        'Pending',

                    count:
                        _countStatus(
                      'pending',
                    ),

                    selected:
                        _selectedFilter ==
                            'pending',

                    color:
                        Colors.orange,

                    onTap: () {
                      _setFilter(
                        'pending',
                      );
                    },
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  _FilterChip(
                    label:
                        'Completed',

                    count:
                        _countStatus(
                      'completed',
                    ),

                    selected:
                        _selectedFilter ==
                            'completed',

                    color:
                        Colors.blue,

                    onTap: () {
                      _setFilter(
                        'completed',
                      );
                    },
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  _FilterChip(
                    label:
                        'Rejected',

                    count:
                        _countStatus(
                      'rejected',
                    ),

                    selected:
                        _selectedFilter ==
                            'rejected',

                    color:
                        Colors.red,

                    onTap: () {
                      _setFilter(
                        'rejected',
                      );
                    },
                  ),
                ],
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child:
                  _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage !=
        null) {
      return _buildError();
    }

    final List<BookingModel>
        bookings =
        _filteredBookings;

    if (bookings.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh:
          _loadBookings,

      child:
          ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          30,
        ),

        itemCount:
            bookings.length,

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return _BookingCard(
            booking:
                bookings[index],

            formatDate:
                _formatDate,

            formatPrice:
                _formatPrice,

            statusColor:
                _statusColor,

            statusIcon:
                _statusIcon,

            onView:
                () {
              _showBookingDetails(
                bookings[index],
              );
            },

            onStatusChanged:
                (String status) {
              _updateStatus(
                bookings[index],
                status,
              );
            },

            onDelete:
                () {
              _deleteBooking(
                bookings[index],
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Icon(
            Icons
                .calendar_month_outlined,

            size: 70,

            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            _selectedFilter ==
                    'all'
                ? 'No bookings yet'
                : 'No $_selectedFilter bookings',

            style:
                const TextStyle(
              fontSize: 20,

              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Bookings will appear here.',

            style:
                TextStyle(
              color:
                  Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.error_outline,

              size: 60,

              color:
                  Colors.red,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to load bookings',

              style:
                  TextStyle(
                fontSize: 19,

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
                color:
                    Colors.grey,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton.icon(
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
}

// =================================================================
// FILTER CHIP
// =================================================================

class _FilterChip
    extends StatelessWidget {
  final String label;

  final int count;

  final bool selected;

  final Color? color;

  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color chipColor =
        color ??
            Theme.of(context)
                .colorScheme
                .primary;

    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),

        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 15,
          vertical: 9,
        ),

        decoration:
            BoxDecoration(
          color: selected
              ? chipColor
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            25,
          ),

          border: Border.all(
            color: selected
                ? chipColor
                : Colors.grey
                    .shade300,
          ),
        ),

        child: Row(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Text(
              label,

              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.black87,

                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 7,
                vertical: 2,
              ),

              decoration:
                  BoxDecoration(
                color: selected
                    ? Colors.white
                        .withValues(
                    alpha: 0.20,
                  )
                    : chipColor
                        .withValues(
                    alpha: 0.10,
                  ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child: Text(
                count.toString(),

                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : chipColor,

                  fontSize: 12,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// BOOKING CARD
// =================================================================

class _BookingCard
    extends StatelessWidget {
  final BookingModel booking;

  final String Function(
    DateTime?,
  ) formatDate;

  final String Function(
    double,
  ) formatPrice;

  final Color Function(
    String,
  ) statusColor;

  final IconData Function(
    String,
  ) statusIcon;

  final VoidCallback onView;

  final ValueChanged<String>
      onStatusChanged;

  final VoidCallback onDelete;

  const _BookingCard({
    required this.booking,
    required this.formatDate,
    required this.formatPrice,
    required this.statusColor,
    required this.statusIcon,
    required this.onView,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        statusColor(
      booking.status,
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      elevation: 0,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // TOP
            // ==================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration:
                      BoxDecoration(
                    color:
                        color.withValues(
                      alpha: 0.10,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),

                  child: Icon(
                    Icons
                        .calendar_month_outlined,

                    color:
                        color,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        booking.serviceName,

                        maxLines: 1,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          fontSize: 16,

                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Booking #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}',

                        style:
                            const TextStyle(
                          color:
                              Colors.grey,

                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 7,
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

                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      Icon(
                        statusIcon(
                          booking.status,
                        ),

                        size: 14,

                        color:
                            color,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        booking.status,

                        style:
                            TextStyle(
                          color:
                              color,

                          fontSize: 12,

                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            const Divider(
              height: 1,
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // CUSTOMER
            // ==================================================

            _InfoRow(
              icon:
                  Icons.person_outline,

              label:
                  'Customer',

              value:
                  booking.customerName,
            ),

            const SizedBox(
              height: 9,
            ),

            // ==================================================
            // VENDOR
            // ==================================================

            _InfoRow(
              icon:
                  Icons.storefront_outlined,

              label:
                  'Vendor',

              value:
                  booking.vendorName,
            ),

            const SizedBox(
              height: 9,
            ),

            // ==================================================
            // EVENT DATE
            // ==================================================

            _InfoRow(
              icon:
                  Icons
                      .calendar_today_outlined,

              label:
                  'Event Date',

              value:
                  formatDate(
                booking.eventDate,
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            // ==================================================
            // LOCATION
            // ==================================================

            _InfoRow(
              icon:
                  Icons.location_on_outlined,

              label:
                  'Location',

              value:
                  booking.location,
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // PRICE
            // ==================================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Booking Price',

                    style:
                        TextStyle(
                      color:
                          Colors.grey,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),

                Text(
                  formatPrice(
                    booking.price,
                  ),

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
              height: 14,
            ),

            // ==================================================
            // ACTIONS
            // ==================================================

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      onView,

                  icon:
                      const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                  ),

                  label:
                      const Text(
                    'View',
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                if (booking.status
                        .toLowerCase() ==
                    'pending')
                  PopupMenuButton<String>(
                    onSelected:
                        onStatusChanged,

                    itemBuilder:
                        (
                      BuildContext context,
                    ) {
                      return const [
                        PopupMenuItem(
                          value:
                              'accepted',

                          child:
                              Text(
                            'Accept',
                          ),
                        ),

                        PopupMenuItem(
                          value:
                              'rejected',

                          child:
                              Text(
                            'Reject',
                          ),
                        ),
                      ];
                    },

                    child:
                        const Chip(
                      avatar:
                          Icon(
                        Icons.edit_outlined,
                        size: 17,
                      ),

                      label:
                          Text(
                        'Status',
                      ),
                    ),
                  ),

                const Spacer(),

                IconButton(
                  tooltip:
                      'Delete',

                  onPressed:
                      onDelete,

                  icon:
                      const Icon(
                    Icons
                        .delete_outline,

                    color:
                        Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// INFO ROW
// =================================================================

class _InfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Icon(
          icon,

          size: 18,

          color:
              Colors.grey,
        ),

        const SizedBox(
          width: 8,
        ),

        SizedBox(
          width: 75,

          child: Text(
            label,

            style:
                const TextStyle(
              color:
                  Colors.grey,

              fontSize: 13,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,

            maxLines: 2,

            overflow:
                TextOverflow.ellipsis,

            style:
                const TextStyle(
              fontSize: 13,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}