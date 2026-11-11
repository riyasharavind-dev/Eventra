class AddressRegion {
  const AddressRegion({required this.id, required this.name});
  final String id, name;
  factory AddressRegion.fromMap(Map<String, dynamic> m) =>
      AddressRegion(id: m['id'].toString(), name: m['name'].toString());
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.area,
    required this.fullAddress,
    required this.isActive,
    this.pin = '',
    this.state,
    this.district,
    this.subdistrict,
  });
  final String id, label, addressLine, area, pin, fullAddress;
  final bool isActive;
  final AddressRegion? state, district, subdistrict;
  factory CustomerAddress.fromMap(Map<String, dynamic> m) {
    AddressRegion? region(String key) => m['${key}_id'] == null
        ? null
        : AddressRegion(
            id: m['${key}_id'].toString(),
            name: m['${key}_name']?.toString() ?? '',
          );
    return CustomerAddress(
      id: m['id'].toString(),
      label: m['label']?.toString() ?? 'Home',
      addressLine: m['address_line']?.toString() ?? '',
      area: m['local_area']?.toString() ?? '',
      fullAddress: m['full_address']?.toString() ?? '',
      isActive: m['is_active'] == true,
      pin: m['pin_code']?.toString() ?? '',
      state: region('state'),
      district: region('district'),
      subdistrict: region('subdistrict'),
    );
  }
}
