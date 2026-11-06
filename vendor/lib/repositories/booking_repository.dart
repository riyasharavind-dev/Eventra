import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  final SupabaseClient _db;
  BookingRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;
  String get vendorId =>
      _db.auth.currentUser?.id ?? (throw StateError('Please sign in again.'));
  RealtimeChannel watchBookings(VoidCallback onChange) {
    return _db
        .channel('vendor-bookings-$vendorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'vendor_id',
            value: vendorId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe((status, error) {
          // Also reconcile after the initial join and every reconnect.
          if (status == RealtimeSubscribeStatus.subscribed) onChange();
        });
  }

  Future<void> stopWatching(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }

  void _owner(String id) {
    if (id != vendorId) {
      throw StateError('Vendor account does not match.');
    }
  }

  List<Map<String, dynamic>> _rows(dynamic response) => (response as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  // Keyset paging avoids the PostgREST default row limit. Counts and client
  // filters operate over the complete loaded vendor list.
  Future<List<BookingModel>> getVendorBookings(String vendorId) async {
    _owner(vendorId);
    final bookings = <String, BookingModel>{};
    BookingModel? before;
    while (true) {
      final rows = _rows(
        await _db.rpc(
          'get_vendor_booking_data',
          params: {
            'p_limit': 200,
            'p_before_created': before?.createdAt?.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          },
        ),
      );
      final page = rows.map(BookingModel.fromMap).toList();
      for (final booking in page) {
        bookings[booking.id] = booking;
      }
      if (page.length < 200) {
        break;
      }
      before = page.last;
    }
    return bookings.values.toList();
  }

  Future<BookingModel> getBooking(String bookingId) async {
    final rows = _rows(
      await _db.rpc(
        'get_vendor_booking_data',
        params: {'p_booking_id': bookingId, 'p_limit': 1},
      ),
    );
    if (rows.isEmpty) {
      throw StateError('Booking not found.');
    }
    return BookingModel.fromMap(rows.single);
  }

  Future<List<Map<String, dynamic>>> history(String bookingId) async => _rows(
    await _db.rpc(
      'get_vendor_booking_history',
      params: {'p_booking_id': bookingId},
    ),
  );
  Future<List<Map<String, dynamic>>> conflicts(String bookingId) async => _rows(
    await _db.rpc(
      'get_vendor_booking_conflicts',
      params: {'p_booking_id': bookingId},
    ),
  );
  Future<int> saveNote(
    BookingModel booking,
    String note, {
    int? expectedVersion,
  }) async => await _db.rpc(
    'save_vendor_booking_note',
    params: {
      'p_booking_id': booking.id,
      'p_note': note.trim(),
      'p_expected_version': expectedVersion ?? booking.noteVersion,
    },
  ) as int;

  Future<void> updateBookingStatus({
    required String bookingId,
    required String vendorId,
    required String status,
    String? expectedStatus,
    String? reason,
    bool acknowledgeOverlap = false,
  }) async {
    _owner(vendorId);
    final previous = expectedStatus ?? (await getBooking(bookingId)).status;
    await _db.rpc(
      'change_vendor_booking_status',
      params: {
        'p_booking_id': bookingId,
        'p_expected_status': previous,
        'p_status': status,
        'p_reason': reason,
        'p_ack_overlap': acknowledgeOverlap,
      },
    );
  }

  Future<void> acceptBooking(String bookingId, String vendorId) =>
      updateBookingStatus(
        bookingId: bookingId,
        vendorId: vendorId,
        status: 'accepted',
      );
  Future<void> rejectBooking(
    String bookingId,
    String vendorId, {
    String reason = 'Declined by vendor',
  }) => updateBookingStatus(
    bookingId: bookingId,
    vendorId: vendorId,
    status: 'rejected',
    reason: reason,
  );
}
