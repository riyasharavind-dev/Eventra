class AboutEventorFeature {
  const AboutEventorFeature({required this.title, required this.description});

  final String title;
  final String description;

  factory AboutEventorFeature.fromMap(Map<String, dynamic> map) {
    return AboutEventorFeature(
      title: map['title'] as String,
      description: map['description'] as String,
    );
  }
}

class AboutEventorModel {
  const AboutEventorModel({
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
  final List<AboutEventorFeature> features;

  factory AboutEventorModel.fromMap(Map<String, dynamic> map) {
    return AboutEventorModel(
      id: map['id'] as String,
      title: map['title'] as String,
      tagline: map['tagline'] as String,
      introduction: map['introduction'] as String,
      features: List.unmodifiable(
        (map['features'] as List).map(
          (item) => AboutEventorFeature.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}
