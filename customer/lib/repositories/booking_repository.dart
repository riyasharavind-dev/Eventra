import '../models/service_model.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingRepository {
  BookingRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get _supabase => client ?? Supabase.instance.client;
  List<String> lastBookingIds = const [];
  Future<void> bookCart({
    Map<String, int> quantities = const {},
    required List<ServiceModel> services,
    required DateTime date,
    required int guests,
    required String eventTime,
    required String location,
    required String requestId,
  }) async {
    final result = await _supabase.rpc(
      'customer_book_services',
      params: {
        'p_items': [
          for (final s in services)
            {
              'id': s.id,
              'price': s.price,
              'quantity': quantities[s.id] ?? 1,
              ...s.pricing.toMap(),
            },
        ],
        'p_event_date': date.toIso8601String().split('T').first,
        'p_guest_count': guests,
        'p_event_time': eventTime,
        'p_location': location,
        'p_request_id': requestId,
      },
    );
    lastBookingIds = (result['booking_ids'] as List)
        .map((id) => id.toString())
        .toList();
  }

  Future<void> acknowledgeCompletion(String id) async {
    await _supabase.rpc(
      'customer_acknowledge_completion',
      params: {'p_booking_id': id},
    );
  }

  static const _select =
      '*,services(id,name,gallery),vendors(id,name,email),event_types(id,name)';

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
        .select(_select)
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
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Please sign in to view your bookings.');
    final response = await _supabase
        .from('bookings')
        .select(_select)
        .eq('customer_id', user.id)
        .eq('id', bookingId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return BookingModel.fromMap(Map<String, dynamic>.from(response));
  }
}
