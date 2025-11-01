import '../../domain/entities/admin_analytics_report.dart';
import '../../domain/entities/admin_audit_log.dart';
import '../../domain/entities/admin_broadcast.dart';
import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/entities/broadcast_targets.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_local_datasource.dart';
import '../models/admin_audit_log_model.dart';
import '../models/admin_broadcast_model.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({required AdminLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final AdminLocalDataSource _localDataSource;

  @override
  Future<AdminDashboardMetrics> getDashboardMetrics({
    DateTime? referenceDate,
  }) {
    return _localDataSource.fetchDashboardMetrics(
      referenceDate: referenceDate,
    );
  }

  @override
  Future<AdminAnalyticsReport> getAnalyticsReport(
      AdminAnalyticsPeriod period) {
    return _localDataSource.fetchAnalyticsReport(period);
  }

  @override
  Future<BroadcastTargets> getBroadcastTargets() {
    return _localDataSource.fetchBroadcastTargets();
  }

  @override
  Future<List<AdminBroadcast>> getBroadcastHistory({int limit = 50}) async {
    final records = await _localDataSource.fetchBroadcastHistory(limit: limit);
    return records.map(AdminBroadcastModel.fromRecord).toList();
  }

  @override
  Future<void> saveBroadcast(AdminBroadcast broadcast) {
    final model = AdminBroadcastModel(
      id: broadcast.id,
      title: broadcast.title,
      message: broadcast.message,
      targetType: broadcast.targetType,
      targetValue: broadcast.targetValue,
      status: broadcast.status,
      scheduledAt: broadcast.scheduledAt,
      sentAt: broadcast.sentAt,
      createdAt: broadcast.createdAt,
      createdBy: broadcast.createdBy,
    );

    final record = model.toRecord();
    return _localDataSource.saveBroadcast(record);
  }

  @override
  Future<void> recordAuditLog(AdminAuditLog log) {
    final model = AdminAuditLogModel(
      id: log.id,
      actorId: log.actorId,
      actionType: log.actionType,
      entityType: log.entityType,
      entityId: log.entityId,
      payload: log.payload,
      createdAt: log.createdAt,
    );

    final record = model.toRecord();
    return _localDataSource.saveAuditLog(record);
  }
}
