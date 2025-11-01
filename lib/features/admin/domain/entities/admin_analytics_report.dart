import 'admin_top_performer.dart';

enum AdminAnalyticsPeriod {
  sevenDays,
  thirtyDays,
  threeMonths,
  sixMonths,
  oneYear,
}

class AdminAnalyticsReport {
  const AdminAnalyticsReport({
    required this.period,
    required this.bookingTrends,
    required this.roomUtilization,
    required this.peakHours,
    required this.departmentUsage,
    required this.topRooms,
    required this.topUsers,
    required this.totalBookings,
    required this.totalRooms,
    required this.totalUsers,
  });

  final AdminAnalyticsPeriod period;
  final Map<DateTime, int> bookingTrends;
  final Map<String, double> roomUtilization;
  final List<int> peakHours;
  final Map<String, int> departmentUsage;
  final List<AdminTopPerformer> topRooms;
  final List<AdminTopPerformer> topUsers;
  final int totalBookings;
  final int totalRooms;
  final int totalUsers;
}
