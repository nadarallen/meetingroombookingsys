import 'package:flutter/foundation.dart';

import '../../domain/entities/admin_analytics_report.dart';
import '../../domain/usecases/get_admin_analytics_report.dart';

class AdminAnalyticsViewModel extends ChangeNotifier {
  AdminAnalyticsViewModel({
    required GetAdminAnalyticsReport getAdminAnalyticsReport,
  }) : _getAdminAnalyticsReport = getAdminAnalyticsReport;

  final GetAdminAnalyticsReport _getAdminAnalyticsReport;

  AdminAnalyticsReport? _report;
  bool _loading = false;
  String? _error;
  AdminAnalyticsPeriod _period = AdminAnalyticsPeriod.thirtyDays;

  AdminAnalyticsReport? get report => _report;
  bool get isLoading => _loading;
  String? get error => _error;
  AdminAnalyticsPeriod get period => _period;

  Future<void> load({AdminAnalyticsPeriod? period, bool forceRefresh = false}) async {
    if (_loading) return;
    final requestedPeriod = period ?? _period;
    if (!forceRefresh && _report != null && requestedPeriod == _period) {
      return;
    }

    _loading = true;
    _error = null;
    if (requestedPeriod != _period) {
      _period = requestedPeriod;
    }
    notifyListeners();

    try {
      final result = await _getAdminAnalyticsReport(_period);
      _report = result;
    } catch (error, stackTrace) {
      debugPrint('Failed to load analytics report: $error\n$stackTrace');
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
