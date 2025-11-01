import '../entities/admin_dashboard_metrics.dart';
import '../repositories/admin_repository.dart';

class GetAdminDashboardMetrics {
  const GetAdminDashboardMetrics(this._repository);

  final AdminRepository _repository;

  Future<AdminDashboardMetrics> call({DateTime? referenceDate}) {
    return _repository.getDashboardMetrics(referenceDate: referenceDate);
  }
}
