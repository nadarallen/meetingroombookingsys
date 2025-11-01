class AdminBroadcast {
  const AdminBroadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.targetType,
    this.targetValue,
    required this.status,
    this.scheduledAt,
    this.sentAt,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String message;
  final String targetType;
  final String? targetValue;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;
  final String createdBy;
}
