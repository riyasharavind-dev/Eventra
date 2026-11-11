class BookingModel {
  final int quantity, quoteVersion;
  final double? unitPrice, quoteAmount;
  final String pricingType;
  final String? pricingUnit;
  final DateTime? quoteApprovedAt;

  final String? businessId, businessName, customerPhone, customerAddress;
  final String? eventStartTime, eventEndTime, statusReason;
  final String eventTimezone, vendorNote;
  final DateTime? eventEndDate;
  final double? latitude, longitude;
  final int noteVersion;
  final List<String> serviceGallery;
  final DateTime? vendorCompletedAt, customerCompletedAt;
  bool get awaitingCompletion =>
      status == 'accepted' &&
      vendorCompletedAt != null &&
      customerCompletedAt == null;
  final String id;

  final String customerId;
  final String vendorId;
  final String serviceId;

  final String? eventTypeId;

  final DateTime? eventDate;

  final int? guestCount;

  final String location;

  final String? requirement;

  final double price;

  final String status;

  final DateTime? createdAt;

  final String customerName;
  final String customerEmail;

  final String vendorName;
  final String vendorEmail;

  final String serviceName;

  final String? eventTypeName;

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
    this.businessId,
    this.businessName,
    this.customerPhone,
    this.customerAddress,
    this.eventStartTime,
    this.eventEndTime,
    this.statusReason,
    this.eventTimezone = 'Asia/Kolkata',
    this.vendorNote = '',
    this.eventEndDate,
    this.latitude,
    this.longitude,
    this.noteVersion = 0,
    this.serviceGallery = const [],
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    this.eventTypeId,
    this.eventDate,
    this.guestCount,
    required this.location,
    this.requirement,
    required this.price,
    required this.status,
    this.createdAt,
    required this.customerName,
    required this.customerEmail,
    required this.vendorName,
    required this.vendorEmail,
    required this.serviceName,
    this.eventTypeName,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    final dynamic customer = map['customers'];

    final dynamic vendor = map['vendors'];

    final dynamic service = map['services'];

    final dynamic eventType = map['event_types'];

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
      businessId: map['business_id']?.toString(),
      businessName: map['business_name']?.toString(),
      customerAddress: map['customer_address']?.toString(),
      customerPhone: customer is Map ? customer['phone']?.toString() : null,
      eventStartTime: map['event_start_time']?.toString(),
      eventEndTime: map['event_end_time']?.toString(),
      eventEndDate: _parseDate(map['event_end_date']),
      eventTimezone: map['event_timezone']?.toString() ?? 'Asia/Kolkata',
      statusReason: map['status_reason']?.toString(),
      vendorNote: map['vendor_note']?.toString() ?? '',
      noteVersion: _parseInt(map['note_version']) ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      serviceGallery: service is Map && service['gallery'] is List
          ? (service['gallery'] as List).whereType<String>().toList()
          : const [],
      id: map['id']?.toString() ?? '',

      customerId: map['customer_id']?.toString() ?? '',

      vendorId: map['vendor_id']?.toString() ?? '',

      serviceId: map['service_id']?.toString() ?? '',

      eventTypeId: map['event_type_id']?.toString(),

      eventDate: _parseDate(map['event_date']),

      guestCount: _parseInt(map['guest_count']),

      location: map['location']?.toString() ?? '',

      requirement: map['requirement']?.toString(),

      price: _parseDouble(map['price']),

      status: map['status']?.toString() ?? 'pending',

      createdAt: _parseDate(map['created_at']),

      customerName: customer is Map
          ? customer['name']?.toString() ?? 'Customer'
          : 'Customer',

      customerEmail: customer is Map ? customer['email']?.toString() ?? '' : '',

      vendorName: vendor is Map
          ? vendor['name']?.toString() ?? 'Vendor'
          : 'Vendor',

      vendorEmail: vendor is Map ? vendor['email']?.toString() ?? '' : '',

      serviceName: service is Map
          ? service['name']?.toString() ?? 'Service'
          : 'Service',

      eventTypeName: eventType is Map ? eventType['name']?.toString() : null,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
