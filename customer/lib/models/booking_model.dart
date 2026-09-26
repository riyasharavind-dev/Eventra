class BookingModel {
  final String id;
  final String customerId;
  final String vendorId;
  final String serviceId;
  final String? eventTypeId;

  final DateTime eventDate;
  final int? guestCount;

  final String location;
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

      guestCount: map['guest_count'] == null
          ? null
          : int.tryParse(
              map['guest_count'].toString(),
            ),

      location:
          map['location']?.toString() ?? '',

      requirement:
          map['requirement']?.toString(),

      price: double.tryParse(
            map['price'].toString(),
          ) ??
          0,

      status:
          map['status']?.toString() ?? 'pending',

      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(
              map['created_at'].toString(),
            ),
    );
  }
}