String? customerContactPhone(String input) {
  final raw = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
  if (RegExp(r'^[1-9][0-9]{9}$').hasMatch(raw)) return '+91$raw';
  if (RegExp(r'^91[0-9]{10}$').hasMatch(raw)) return '+$raw';
  return RegExp(r'^\+[1-9][0-9]{9,14}$').hasMatch(raw) ? raw : null;
}
