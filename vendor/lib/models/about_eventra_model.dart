class AboutEventraFeature {
  const AboutEventraFeature({required this.title, required this.description});

  final String title;
  final String description;

  factory AboutEventraFeature.fromMap(Map<String, dynamic> map) {
    return AboutEventraFeature(
      title: map['title'] as String,
      description: map['description'] as String,
    );
  }
}

class AboutEventraModel {
  const AboutEventraModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.introduction,
    required this.features,
  });

  final String id;
  final String title;
  final String tagline;
  final String introduction;
  final List<AboutEventraFeature> features;

  factory AboutEventraModel.fromMap(Map<String, dynamic> map) {
    return AboutEventraModel(
      id: map['id'] as String,
      title: map['title'] as String,
      tagline: map['tagline'] as String,
      introduction: map['introduction'] as String,
      features: List.unmodifiable(
        (map['features'] as List).map(
          (item) => AboutEventraFeature.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}
