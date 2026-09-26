import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  BookingRepository();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET VENDOR BOOKINGS
  // ============================================================

  Future<List<BookingModel>> getVendorBookings(
    String vendorId,
  ) async {
    final response = await _supabase
        .from('bookings')
        .select('''
          id,
          customer_id,
          vendor_id,
          service_id,
          event_type_id,
          event_date,
          guest_count,
          location,
          requirement,
          price,
          status,
          created_at,

          customers (
            id,
            name,
            email
          ),

          vendors (
            id,
            name,
            email
          ),

          services (
            id,
            name
          ),

          event_types (
            id,
            name
          )
        ''')
        .eq(
          'vendor_id',
          vendorId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => BookingModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE BOOKING
  // ============================================================

  Future<BookingModel> getBooking(
    String bookingId,
  ) async {
    final response = await _supabase
        .from('bookings')
        .select('''
          id,
          customer_id,
          vendor_id,
          service_id,
          event_type_id,
          event_date,
          guest_count,
          location,
          requirement,
          price,
          status,
          created_at,

          customers (
            id,
            name,
            email
          ),

          vendors (
            id,
            name,
            email
          ),

          services (
            id,
            name
          ),

          event_types (
            id,
            name
          )
        ''')
        .eq(
          'id',
          bookingId,
        )
        .single();

    return BookingModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ============================================================
  // ACCEPT BOOKING
  // ============================================================

  Future<void> acceptBooking(
    String bookingId,
    String vendorId,
  ) async {
    await _updateBookingStatus(
      bookingId: bookingId,
      vendorId: vendorId,
      status: 'accepted',
    );
  }

  // ============================================================
  // REJECT BOOKING
  // ============================================================

  Future<void> rejectBooking(
    String bookingId,
    String vendorId,
  ) async {
    await _updateBookingStatus(
      bookingId: bookingId,
      vendorId: vendorId,
      status: 'rejected',
    );
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> updateBookingStatus({
    required String bookingId,
    required String vendorId,
    required String status,
  }) async {
    const allowedStatuses = [
      'pending',
      'accepted',
      'rejected',
      'completed',
      'cancelled',
    ];

    if (!allowedStatuses.contains(status)) {
      throw Exception(
        'Invalid booking status.',
      );
    }

    await _updateBookingStatus(
      bookingId: bookingId,
      vendorId: vendorId,
      status: status,
    );
  }

  // ============================================================
  // INTERNAL STATUS UPDATE
  // ============================================================

  Future<void> _updateBookingStatus({
    required String bookingId,
    required String vendorId,
    required String status,
  }) async {
    await _supabase
        .from('bookings')
        .update({
          'status': status,
        })
        .eq(
          'id',
          bookingId,
        )
        .eq(
          'vendor_id',
          vendorId,
        );
  }
}