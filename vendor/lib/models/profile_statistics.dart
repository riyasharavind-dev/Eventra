class ProfileStatistics {
  final int completedEvents, reviewCount;
  final double? rating;
  final bool verified;
  const ProfileStatistics({
    required this.completedEvents,
    required this.reviewCount,
    this.rating,
    this.verified = false,
  });
}
