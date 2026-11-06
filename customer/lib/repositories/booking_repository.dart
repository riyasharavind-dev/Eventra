import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  BookingRepository();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // CREATE BOOKING
  // ============================================================

  Future<BookingModel> createBooking({
    required String customerId,
    required String vendorId,
    required String serviceId,
    String? eventTypeId,
    required DateTime eventDate,
    int? guestCount,

    // Event location
    String location = '',
    double? latitude,
    double? longitude,

    String? requirement,
    required double price,
  }) async {
    // ----------------------------------------------------------
    // LOCATION VALIDATION
    // ----------------------------------------------------------

    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw Exception('Invalid latitude.');
    }

    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw Exception('Invalid longitude.');
    }

    // ----------------------------------------------------------
    // CREATE BOOKING
    // ----------------------------------------------------------

    final response = await _supabase
        .from('bookings')
        .insert({
          'customer_id': customerId,
          'vendor_id': vendorId,
          'service_id': serviceId,

          'event_type_id': eventTypeId,

          'event_date': eventDate.toIso8601String().split('T').first,

          'guest_count': guestCount,

          // Event/service delivery location
          'location': location.trim(),
          'latitude': latitude,
          'longitude': longitude,

          'requirement': requirement?.trim().isEmpty == true
              ? null
              : requirement?.trim(),

          'price': price,

          'status': 'pending',
        })
        .select()
        .single();

    return BookingModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // GET CUSTOMER BOOKINGS
  // ============================================================

  Future<List<BookingModel>> getMyBookings() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    final response = await _supabase
        .from('bookings')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => BookingModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // GET SINGLE BOOKING
  // ============================================================

  Future<BookingModel?> getBookingById(String bookingId) async {
    final response = await _supabase
        .from('bookings')
        .select()
        .eq('id', bookingId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return BookingModel.fromMap(Map<String, dynamic>.from(response));
  }
}
