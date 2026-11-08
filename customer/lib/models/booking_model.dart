class BookingModel {
  final String id;

  final String customerId;
  final String vendorId;
  final String serviceId;
  final String? eventTypeId;

  final DateTime eventDate;
  final int? guestCount;

  // Event / service delivery location
  final String location;
  final double? latitude;
  final double? longitude;

  final String? requirement;

  final double price;
  final String status;
  final DateTime? createdAt;

  const BookingModel({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    this.eventTypeId,
    required this.eventDate,
    this.guestCount,
    required this.location,
    this.latitude,
    this.longitude,
    this.requirement,
    required this.price,
    required this.status,
    this.createdAt,
  });

  factory BookingModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return BookingModel(
      id: map['id']?.toString() ?? '',

      customerId:
          map['customer_id']?.toString() ?? '',

      vendorId:
          map['vendor_id']?.toString() ?? '',

      serviceId:
          map['service_id']?.toString() ?? '',

      eventTypeId:
          map['event_type_id']?.toString(),

      eventDate: DateTime.parse(
        map['event_date'].toString(),
      ),

      guestCount:
          map['guest_count'] == null
              ? null
              : int.tryParse(
                  map['guest_count'].toString(),
                ),

      location:
          map['location']?.toString() ?? '',

      latitude:
          map['latitude'] == null
              ? null
              : (map['latitude'] as num).toDouble(),

      longitude:
          map['longitude'] == null
              ? null
              : (map['longitude'] as num).toDouble(),

      requirement:
          map['requirement']?.toString(),

      price:
          double.tryParse(
                map['price'].toString(),
              ) ??
              0,

      status:
          map['status']?.toString() ??
          'pending',

      createdAt:
          map['created_at'] == null
              ? null
              : DateTime.tryParse(
                  map['created_at'].toString(),
                ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'vendor_id': vendorId,
      'service_id': serviceId,
      'event_type_id': eventTypeId,
      'event_date':
          eventDate.toIso8601String().split('T').first,
      'guest_count': guestCount,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'requirement': requirement,
      'price': price,
      'status': status,
      'created_at':
          createdAt?.toIso8601String(),
    };
  }
}