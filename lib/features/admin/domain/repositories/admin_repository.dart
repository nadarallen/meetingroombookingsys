import '../entities/admin_analytics_report.dart';
import '../entities/admin_audit_log.dart';
import '../entities/admin_broadcast.dart';
import '../entities/admin_dashboard_metrics.dart';
import '../entities/broadcast_targets.dart';

abstract class AdminRepository {
  Future<AdminDashboardMetrics> getDashboardMetrics({DateTime? referenceDate});

  Future<AdminAnalyticsReport> getAnalyticsReport(AdminAnalyticsPeriod period);

  Future<BroadcastTargets> getBroadcastTargets();

  Future<List<AdminBroadcast>> getBroadcastHistory({int limit = 50});

  Future<void> saveBroadcast(AdminBroadcast broadcast);

  Future<void> recordAuditLog(AdminAuditLog log);
}
