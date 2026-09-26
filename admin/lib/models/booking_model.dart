class BookingModel {
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
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    required this.eventTypeId,
    required this.eventDate,
    required this.guestCount,
    required this.location,
    required this.requirement,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.customerEmail,
    required this.vendorName,
    required this.vendorEmail,
    required this.serviceName,
    required this.eventTypeName,
  });

  factory BookingModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final dynamic customer =
        map['customers'];

    final dynamic vendor =
        map['vendors'];

    final dynamic service =
        map['services'];

    final dynamic eventType =
        map['event_types'];

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

      eventDate:
          _parseDate(
        map['event_date'],
      ),

      guestCount:
          _parseInt(
        map['guest_count'],
      ),

      location:
          map['location']?.toString() ?? '',

      requirement:
          map['requirement']?.toString(),

      price:
          _parseDouble(
        map['price'],
      ),

      status:
          map['status']?.toString() ??
              'pending',

      createdAt:
          _parseDate(
        map['created_at'],
      ),

      customerName:
          customer is Map
              ? customer['name']
                      ?.toString() ??
                  'Customer'
              : 'Customer',

      customerEmail:
          customer is Map
              ? customer['email']
                      ?.toString() ??
                  ''
              : '',

      vendorName:
          vendor is Map
              ? vendor['name']
                      ?.toString() ??
                  'Vendor'
              : 'Vendor',

      vendorEmail:
          vendor is Map
              ? vendor['email']
                      ?.toString() ??
                  ''
              : '',

      serviceName:
          service is Map
              ? service['name']
                      ?.toString() ??
                  'Service'
              : 'Service',

      eventTypeName:
          eventType is Map
              ? eventType['name']
                      ?.toString()
              : null,
    );
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  static int? _parseInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static double _parseDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }
}