import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  BookingRepository();

  final SupabaseClient _supabase =
      Supabase.instance.client;

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
    required String location,
    String? requirement,
    required double price,
  }) async {
    final response = await _supabase
        .from('bookings')
        .insert({
      'customer_id': customerId,
      'vendor_id': vendorId,
      'service_id': serviceId,
      'event_type_id': eventTypeId,
      'event_date':
          eventDate.toIso8601String().split('T').first,
      'guest_count': guestCount,
      'location': location,
      'requirement': requirement,
      'price': price,
      'status': 'pending',
    })
        .select()
        .single();

    return BookingModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // GET CUSTOMER BOOKINGS
  // ============================================================

  Future<List<BookingModel>>
      getMyBookings() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You are not logged in.',
      );
    }

    final response = await _supabase
        .from('bookings')
        .select()
        .eq('customer_id', user.id)
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) =>
              BookingModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}