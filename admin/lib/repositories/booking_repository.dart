import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  BookingRepository();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET ALL BOOKINGS
  // ============================================================

  Future<List<BookingModel>>
      getBookings() async {
    final response =
        await _supabase
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
            .order(
              'created_at',
              ascending: false,
            );

    final List<dynamic> rows =
        response as List<dynamic>;

    return rows
        .map(
          (dynamic item) =>
              BookingModel.fromMap(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE BOOKING
  // ============================================================

  Future<BookingModel>
      getBooking(
    String bookingId,
  ) async {
    final response =
        await _supabase
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
  // UPDATE STATUS
  // ============================================================

  Future<void> updateStatus({
    required String bookingId,
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
        );
  }

  // ============================================================
  // DELETE BOOKING
  // ============================================================

  Future<void> deleteBooking(
    String bookingId,
  ) async {
    await _supabase
        .from('bookings')
        .delete()
        .eq(
          'id',
          bookingId,
        );
  }
}