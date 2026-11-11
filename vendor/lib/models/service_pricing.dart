enum ServicePricingType {
  fixed('fixed', 'Fixed price'),
  startingFrom('starting_from', 'Starting from'),
  perUnit('per_unit', 'Per unit'),
  perDuration('per_duration', 'Per duration');

  const ServicePricingType(this.value, this.label);
  final String value, label;
  static ServicePricingType parse(dynamic value) =>
      values.firstWhere((type) => type.value == value, orElse: () => fixed);
}

class ServicePricing {
  const ServicePricing({this.type = ServicePricingType.fixed, this.unit});
  final ServicePricingType type;
  final String? unit;
  static const durationUnits = ['hour', 'day', 'week', 'month'];
  factory ServicePricing.fromMap(Map<String, dynamic> map) => ServicePricing(
    type: ServicePricingType.parse(map['pricing_type']),
    unit: map['pricing_unit']?.toString(),
  );
  bool get needsUnit =>
      type == ServicePricingType.perUnit ||
      type == ServicePricingType.perDuration;
  Map<String, dynamic> toMap() => {
    'pricing_type': type.value,
    'pricing_unit': needsUnit ? unit?.trim() : null,
  };
  void validate(double price) {
    if (!price.isFinite || price < 0) {
      throw ArgumentError('Enter a valid price.');
    }
    if (needsUnit &&
        (unit == null || unit!.trim().isEmpty || unit!.trim().length > 40)) {
      throw ArgumentError('Enter a unit (maximum 40 characters).');
    }
    if (type == ServicePricingType.perDuration &&
        !durationUnits.contains(unit)) {
      throw ArgumentError('Choose hour, day, week or month.');
    }
  }

  String format(
    double price, {
    bool tamil = false,
    String Function(String)? translate,
  }) {
    final text = translate ?? (String value) => value;
    final amount =
        '₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';
    final unitLabel = unit == null
        ? text('unit')
        : type == ServicePricingType.perDuration
        ? text(unit!)
        : unit!;
    final suffix = needsUnit ? ' / $unitLabel' : '';
    return type == ServicePricingType.startingFrom
        ? '${text('Starting from')} $amount'
        : '$amount$suffix';
  }
}
