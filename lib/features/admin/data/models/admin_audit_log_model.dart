import '../../../../core/database/models/admin_audit_log_record.dart';
import '../../domain/entities/admin_audit_log.dart';

class AdminAuditLogModel extends AdminAuditLog {
  const AdminAuditLogModel({
    required super.id,
    required super.actorId,
    required super.actionType,
    required super.entityType,
    super.entityId,
    super.payload,
    required super.createdAt,
  });

  factory AdminAuditLogModel.fromRecord(AdminAuditLogRecord record) {
    return AdminAuditLogModel(
      id: record.id,
      actorId: record.actorId,
      actionType: record.actionType,
      entityType: record.entityType,
      entityId: record.entityId,
      payload: record.payload,
      createdAt: record.createdAt,
    );
  }

  AdminAuditLogRecord toRecord() {
    return AdminAuditLogRecord(
      id: id,
      actorId: actorId,
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      createdAt: createdAt,
    );
  }
}
