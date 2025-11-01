class AdminBroadcastRecord {
  const AdminBroadcastRecord({
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

  factory AdminBroadcastRecord.fromMap(Map<String, dynamic> map) {
    return AdminBroadcastRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      targetType: map['target_type'] as String,
      targetValue: map['target_value'] as String?,
      status: map['status'] as String,
      scheduledAt: map['scheduled_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_at'] as int)
          : null,
      sentAt: map['sent_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['sent_at'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      createdBy: map['created_by'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'target_type': targetType,
      'target_value': targetValue,
      'status': status,
      'scheduled_at': scheduledAt?.millisecondsSinceEpoch,
      'sent_at': sentAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
    };
  }
}
