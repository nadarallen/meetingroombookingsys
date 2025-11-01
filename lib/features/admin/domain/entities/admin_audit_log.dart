class AdminAuditLog {
  const AdminAuditLog({
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
}
