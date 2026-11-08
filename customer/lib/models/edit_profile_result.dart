class EditProfileResult {
  final bool saved;
  final String name;
  final String phone;

  const EditProfileResult({
    this.saved = false,
    this.name = '',
    this.phone = '',
  });
}
