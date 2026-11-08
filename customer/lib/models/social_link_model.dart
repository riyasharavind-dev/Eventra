class SocialLinkModel {
  const SocialLinkModel({
    required this.id,
    required this.icon,
    required this.name,
    this.link,
    this.iconUrl,
  });

  final String id;
  final String icon;
  final String name;
  final String? link;
  final String? iconUrl;

  static Uri? httpsUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  Uri? get destination => httpsUri(link);
  Uri? get imageUri => httpsUri(iconUrl);

  Map<String, dynamic> toMap() => {
    'id': id,
    'icon': icon,
    'name': name,
    'link': link,
    'icon_url': iconUrl,
  };

  factory SocialLinkModel.fromMap(Map<String, dynamic> map) => SocialLinkModel(
    id: map['id'] as String,
    icon: map['icon'] as String,
    name: map['name'] as String,
    link: map['link'] as String?,
    iconUrl: map['icon_url'] as String?,
  );
}
