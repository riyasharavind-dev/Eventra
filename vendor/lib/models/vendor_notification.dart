class VendorNotification {
  const VendorNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.targetType = 'message',
    this.targetId,
    this.imageUrl,
    this.data = const {},
  });
  final String id, kind, title, body, targetType;
  final String? targetId, imageUrl;
  String? get thumbnailUrl {
    final value = imageUrl ?? data['image_url']?.toString();
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri.toString()
        : null;
  }

  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;
  bool get unread => readAt == null;
  VendorNotification asRead(DateTime at) => VendorNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: at,
    targetType: targetType,
    targetId: targetId,
    imageUrl: imageUrl,
    data: data,
  );
  factory VendorNotification.fromMap(Map<String, dynamic> row) =>
      VendorNotification(
        id: row['id'] as String,
        kind: row['kind'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        targetType: row['target_type'] as String? ?? 'message',
        targetId: row['target_id'] as String?,
        imageUrl: row['image_url'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] == null
            ? null
            : DateTime.parse(row['read_at'] as String),
        data: Map<String, dynamic>.from(row['data'] as Map? ?? {}),
      );
}

String notificationDateGroup(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(
    date.toLocal().year,
    date.toLocal().month,
    date.toLocal().day,
  );
  if (!day.isBefore(today)) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  if (!day.isBefore(DateTime(today.year, today.month, today.day - 6))) {
    return 'This week';
  }
  return 'Earlier';
}
