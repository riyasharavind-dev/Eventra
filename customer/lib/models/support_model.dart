class SupportFaq {
  const SupportFaq({
    required this.category,
    required this.question,
    required this.answer,
  });
  final String category;
  final String question;
  final String answer;
  factory SupportFaq.fromMap(Map<String, dynamic> map) => SupportFaq(
    category: map['category'] as String,
    question: map['question'] as String,
    answer: map['answer'] as String,
  );
}

class SupportSettings {
  const SupportSettings({
    this.email,
    this.whatsappNumber,
    this.businessHours,
    this.responseTime,
  });
  final String? email;
  final String? whatsappNumber;
  final String? businessHours;
  final String? responseTime;
  factory SupportSettings.fromMap(Map<String, dynamic> map) => SupportSettings(
    email: map['email'] as String?,
    whatsappNumber: map['whatsapp_number'] as String?,
    businessHours: map['business_hours'] as String?,
    responseTime: map['response_time'] as String?,
  );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    this.screenshotPath,
  });
  final String id;
  final int number;
  final String category;
  final String subject;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? screenshotPath;
  String get reference => 'EV-$number';
  String get statusLabel => switch (status) {
    'in_progress' => 'In progress',
    'waiting_for_vendor' => 'Awaiting your reply',
    'resolved' => 'Resolved',
    'closed' => 'Closed',
    _ => 'Open',
  };
  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
    id: map['id'] as String,
    number: (map['ticket_number'] as num).toInt(),
    category: map['category'] as String,
    subject: map['subject'] as String,
    description: map['description'] as String,
    status: map['status'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    screenshotPath: map['screenshot_path'] as String?,
  );
}

class SupportMessage {
  const SupportMessage({
    required this.body,
    required this.fromSupport,
    required this.createdAt,
  });
  final String body;
  final bool fromSupport;
  final DateTime createdAt;
  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
    body: map['body'] as String,
    fromSupport: map['sender_role'] == 'support',
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
