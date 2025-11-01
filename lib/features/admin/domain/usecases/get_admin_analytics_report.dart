import '../entities/admin_analytics_report.dart';
import '../repositories/admin_repository.dart';

class GetAdminAnalyticsReport {
  const GetAdminAnalyticsReport(this._repository);

  final AdminRepository _repository;

  Future<AdminAnalyticsReport> call(AdminAnalyticsPeriod period) {
    return _repository.getAnalyticsReport(period);
  }
}
