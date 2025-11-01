import '../../../../core/database/models/admin_broadcast_record.dart';
import '../../domain/entities/admin_broadcast.dart';

class AdminBroadcastModel extends AdminBroadcast {
  const AdminBroadcastModel({
    required super.id,
    required super.title,
    required super.message,
    required super.targetType,
    super.targetValue,
    required super.status,
    super.scheduledAt,
    super.sentAt,
    required super.createdAt,
    required super.createdBy,
  });

  factory AdminBroadcastModel.fromRecord(AdminBroadcastRecord record) {
    return AdminBroadcastModel(
      id: record.id,
      title: record.title,
      message: record.message,
      targetType: record.targetType,
      targetValue: record.targetValue,
      status: record.status,
      scheduledAt: record.scheduledAt,
      sentAt: record.sentAt,
      createdAt: record.createdAt,
      createdBy: record.createdBy,
    );
  }

  AdminBroadcastRecord toRecord() {
    return AdminBroadcastRecord(
      id: id,
      title: title,
      message: message,
      targetType: targetType,
      targetValue: targetValue,
      status: status,
      scheduledAt: scheduledAt,
      sentAt: sentAt,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}
