import 'dart:convert';

class AdminAuditLogRecord {
  const AdminAuditLogRecord({
    required this.id,
    required this.actorId,
    required this.actionType,
    required this.entityType,
    this.entityId,
    this.payload,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final String actionType;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  factory AdminAuditLogRecord.fromMap(Map<String, dynamic> map) {
    return AdminAuditLogRecord(
      id: map['id'] as String,
      actorId: map['actor_id'] as String,
      actionType: map['action_type'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      payload: map['payload'] != null
          ? jsonDecode(map['payload'] as String) as Map<String, dynamic>
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actor_id': actorId,
      'action_type': actionType,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
