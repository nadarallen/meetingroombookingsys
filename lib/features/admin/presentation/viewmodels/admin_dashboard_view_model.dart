import 'package:flutter/foundation.dart';

import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/usecases/get_admin_dashboard_metrics.dart';

class AdminDashboardViewModel extends ChangeNotifier {
  AdminDashboardViewModel({
    required GetAdminDashboardMetrics getAdminDashboardMetrics,
  }) : _getAdminDashboardMetrics = getAdminDashboardMetrics;

  final GetAdminDashboardMetrics _getAdminDashboardMetrics;

  AdminDashboardMetrics? _metrics;
  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;

  AdminDashboardMetrics? get metrics => _metrics;
  bool get isLoading => _loading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  Future<void> load({bool forceRefresh = false}) async {
    if (_loading) return;
    if (!forceRefresh && _metrics != null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _getAdminDashboardMetrics();
      _metrics = result;
      _lastUpdated = DateTime.now();
    } catch (error, stackTrace) {
      debugPrint('Failed to load admin metrics: $error\n$stackTrace');
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    _metrics = null;
    return load(forceRefresh: true);
  }
}
