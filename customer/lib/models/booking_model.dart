class BookingModel {
  final int quantity, quoteVersion;
  final double? unitPrice, quoteAmount;
  final String pricingType;
  final String? pricingUnit;
  final DateTime? quoteApprovedAt;

  final DateTime? vendorCompletedAt, customerCompletedAt;
  bool get awaitingCompletion =>
      status == 'accepted' &&
      vendorCompletedAt != null &&
      customerCompletedAt == null;
  final String id, customerId, vendorId, serviceId;
  final String? eventTypeId;
  final DateTime eventDate;
  final DateTime? eventEndDate, createdAt, updatedAt;
  final String? eventStartTime, eventEndTime, statusReason;
  final String eventTimezone;
  final int? guestCount;
  final String location;
  final double? latitude, longitude;
  final String? requirement;
  final double price;
  final String status, serviceName, vendorName, vendorEmail;
  final String? eventTypeName;
  final List<String> serviceGallery;
  const BookingModel({
    this.quantity = 1,
    this.quoteVersion = 0,
    this.unitPrice,
    this.quoteAmount,
    this.pricingType = 'fixed',
    this.pricingUnit,
    this.quoteApprovedAt,

    this.vendorCompletedAt,
    this.customerCompletedAt,
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    this.eventTypeId,
    required this.eventDate,
    this.eventEndDate,
    this.eventStartTime,
    this.eventEndTime,
    this.eventTimezone = 'Asia/Kolkata',
    this.guestCount,
    required this.location,
    this.latitude,
    this.longitude,
    this.requirement,
    required this.price,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.statusReason,
    this.serviceName = 'Service',
    this.vendorName = 'Vendor',
    this.vendorEmail = '',
    this.eventTypeName,
    this.serviceGallery = const [],
  });
  factory BookingModel.fromMap(Map<String, dynamic> map) {
    final service = map['services'] is Map ? map['services'] as Map : const {};
    final vendor = map['vendors'] is Map ? map['vendors'] as Map : const {};
    final type = map['event_types'] is Map
        ? map['event_types'] as Map
        : const {};
    return BookingModel(
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      quoteVersion: (map['quote_version'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      quoteAmount: (map['quote_amount'] as num?)?.toDouble(),
      pricingType: map['pricing_type']?.toString() ?? 'fixed',
      pricingUnit: map['pricing_unit']?.toString(),
      quoteApprovedAt: DateTime.tryParse(
        map['quote_approved_at']?.toString() ?? '',
      ),
      vendorCompletedAt: DateTime.tryParse(
        map['vendor_completed_at']?.toString() ?? '',
      ),
      customerCompletedAt: DateTime.tryParse(
        map['customer_completed_at']?.toString() ?? '',
      ),
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      serviceId: map['service_id']?.toString() ?? '',
      eventTypeId: map['event_type_id']?.toString(),
      eventDate: DateTime.parse(map['event_date'].toString()),
      eventEndDate: DateTime.tryParse(map['event_end_date']?.toString() ?? ''),
      eventStartTime: map['event_start_time']?.toString(),
      eventEndTime: map['event_end_time']?.toString(),
      eventTimezone: map['event_timezone']?.toString() ?? 'Asia/Kolkata',
      guestCount: int.tryParse(map['guest_count']?.toString() ?? ''),
      location: map['location']?.toString() ?? '',
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
      requirement: map['requirement']?.toString(),
      price: double.tryParse(map['price']?.toString() ?? '') ?? 0,
      status: map['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      statusReason: map['status_reason']?.toString(),
      serviceName: service['name']?.toString() ?? 'Service',
      vendorName: vendor['name']?.toString() ?? 'Vendor',
      vendorEmail: vendor['email']?.toString() ?? '',
      eventTypeName: type['name']?.toString(),
      serviceGallery: service['gallery'] is List
          ? (service['gallery'] as List).whereType<String>().toList()
          : const [],
    );
  }
  Map<String, dynamic> toMap() => {
    'id': id,
    'quantity': quantity,
    'unit_price': unitPrice,
    'pricing_type': pricingType,
    'pricing_unit': pricingUnit,
    'quote_amount': quoteAmount,
    'quote_version': quoteVersion,
    'quote_approved_at': quoteApprovedAt?.toIso8601String(),
    'customer_id': customerId,
    'vendor_id': vendorId,
    'service_id': serviceId,
    'event_type_id': eventTypeId,
    'event_date': eventDate.toIso8601String().split('T').first,
    if (eventEndDate != null)
      'event_end_date': eventEndDate!.toIso8601String().split('T').first,
    if (eventStartTime != null) 'event_start_time': eventStartTime,
    if (eventEndTime != null) 'event_end_time': eventEndTime,
    'guest_count': guestCount,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'requirement': requirement,
    'price': price,
    'status': status,
    'vendor_completed_at': vendorCompletedAt?.toUtc().toIso8601String(),
    'customer_completed_at': customerCompletedAt?.toUtc().toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
  };
}
