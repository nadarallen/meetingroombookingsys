import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/admin_audit_log_record.dart';
import '../../../../core/database/models/admin_broadcast_record.dart';
import '../../../../core/database/models/app_user.dart';
import '../../../../core/database/models/booking.dart';
import '../../../../core/database/models/room.dart';
import '../../domain/entities/admin_analytics_report.dart';
import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/entities/admin_top_performer.dart';
import '../../domain/entities/broadcast_targets.dart';

class AdminLocalDataSource {
  AdminLocalDataSource({required LocalDatabase localDatabase})
      : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  Future<AdminDashboardMetrics> fetchDashboardMetrics({
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final bookings = await _localDatabase.getBookings();
    final users = await _localDatabase.getUsers();
    final rooms = await _localDatabase.getRooms();
    final broadcasts = await _localDatabase.getAdminBroadcasts(limit: 20);

    final todaysBookings = bookings
        .where(
          (booking) => booking.startTime.isAfter(todayStart) &&
              booking.startTime.isBefore(todayStart.add(const Duration(days: 1))),
        )
        .length;

    final weekBookings = bookings
        .where(
          (booking) => booking.startTime.isAfter(weekStart) &&
              booking.startTime.isBefore(weekStart.add(const Duration(days: 7))),
        )
        .length;

    final monthBookings = bookings
        .where(
          (booking) => booking.startTime.isAfter(monthStart) &&
              booking.startTime.isBefore(monthStart.add(const Duration(days: 31))),
        )
        .length;

    final activeUsers = users.where((user) => user.isActive).length;

    final totalRooms = rooms.length;
    final utilizedRooms = rooms
        .where(
          (room) => bookings.any(
            (booking) => booking.roomId == room.id &&
                booking.startTime.isAfter(todayStart) &&
                booking.startTime.isBefore(
                  todayStart.add(const Duration(days: 1)),
                ),
          ),
        )
        .length;
    final roomUtilization = totalRooms > 0
        ? double.parse(((utilizedRooms / totalRooms) * 100).toStringAsFixed(1))
        : 0;

    final checkInsToday = bookings
        .where(
          (booking) => booking.checkedIn == 1 &&
              booking.startTime.isAfter(todayStart) &&
              booking.startTime.isBefore(todayStart.add(const Duration(days: 1))),
        )
        .length;

    final cancellationsThisWeek = bookings
        .where(
          (booking) => booking.status == 'cancelled' &&
              booking.updatedAt.isAfter(weekStart) &&
              booking.updatedAt.isBefore(weekStart.add(const Duration(days: 7))),
        )
        .length;

    final queuedBroadcasts = broadcasts
        .where((broadcast) => broadcast.status == 'scheduled')
        .length;

    return AdminDashboardMetrics(
      todaysBookings: todaysBookings,
      weekBookings: weekBookings,
      monthBookings: monthBookings,
      activeUsers: activeUsers,
      roomUtilization: roomUtilization,
      pendingApprovals: await _localDatabase.getPendingBookingsCount(),
      checkInsToday: checkInsToday,
      cancellationsThisWeek: cancellationsThisWeek,
      queuedBroadcasts: queuedBroadcasts,
    );
  }

  Future<AdminAnalyticsReport> fetchAnalyticsReport(
    AdminAnalyticsPeriod period,
  ) async {
    final now = DateTime.now();
    final startDate = _startDateForPeriod(now, period);

    final bookings = (await _localDatabase.getBookings())
        .where((booking) =>
            booking.startTime.isAfter(startDate) &&
            booking.startTime.isBefore(now))
        .toList();
    final rooms = await _localDatabase.getRooms();
    final users = await _localDatabase.getUsers();

    final bookingTrends = <DateTime, int>{};
    for (final booking in bookings) {
      final key = DateTime(booking.startTime.year, booking.startTime.month,
          booking.startTime.day);
      bookingTrends[key] = (bookingTrends[key] ?? 0) + 1;
    }

    final daysInPeriod = now.difference(startDate).inDays.clamp(1, 365);

    final roomUtilization = <String, double>{};
    for (final room in rooms) {
      final roomBookings = bookings.where((b) => b.roomId == room.id).length;
      roomUtilization[room.name] =
          double.parse(((roomBookings / daysInPeriod) * 100).toStringAsFixed(1));
    }

    final peakHours = List<int>.filled(24, 0);
    for (final booking in bookings) {
      peakHours[booking.startTime.hour]++;
    }

    final departmentUsage = <String, int>{};
    for (final booking in bookings) {
      final user = users.firstWhere(
        (user) => user.id == booking.userId,
        orElse: () => AppUser(id: '', email: ''),
      );
      final department = user.department ?? 'Unknown';
      departmentUsage[department] = (departmentUsage[department] ?? 0) + 1;
    }

    final topRooms = <AdminTopPerformer>[];
    final roomUsage = <String, int>{};
    for (final booking in bookings) {
      roomUsage[booking.roomId] = (roomUsage[booking.roomId] ?? 0) + 1;
    }
    final roomLookup = {for (final room in rooms) room.id: room.name};
    roomUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5).forEach(
        (entry) {
          topRooms.add(
            AdminTopPerformer(
              id: entry.key,
              label: roomLookup[entry.key] ?? 'Unknown',
              count: entry.value,
            ),
          );
        },
      );

    final topUsers = <AdminTopPerformer>[];
    final userUsage = <String, int>{};
    for (final booking in bookings) {
      userUsage[booking.userId] = (userUsage[booking.userId] ?? 0) + 1;
    }
    final userLookup = {for (final user in users) user.id: user.displayName ?? user.email};
    userUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5).forEach(
        (entry) {
          topUsers.add(
            AdminTopPerformer(
              id: entry.key,
              label: userLookup[entry.key] ?? 'Unknown',
              count: entry.value,
            ),
          );
        },
      );

    return AdminAnalyticsReport(
      period: period,
      bookingTrends: bookingTrends,
      roomUtilization: roomUtilization,
      peakHours: peakHours,
      departmentUsage: departmentUsage,
      topRooms: topRooms,
      topUsers: topUsers,
      totalBookings: bookings.length,
      totalRooms: rooms.length,
      totalUsers: users.length,
    );
  }

  Future<BroadcastTargets> fetchBroadcastTargets() async {
    final users = await _localDatabase.getUsers();
    final departments = users
        .map((user) => user.department)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final departmentCounts = <String, int>{};
    for (final user in users.where((user) => user.isActive)) {
      final department = user.department ?? 'Unknown';
      departmentCounts[department] = (departmentCounts[department] ?? 0) + 1;
    }

    return BroadcastTargets(
      departments: departments,
      activeUsers: users.where((user) => user.isActive).length,
      activeAdmins: users.where((user) => user.isActive && user.isAdmin).length,
      departmentCounts: departmentCounts,
    );
  }

  Future<List<AdminBroadcastRecord>> fetchBroadcastHistory({int limit = 50}) {
    return _localDatabase.getAdminBroadcasts(limit: limit);
  }

  Future<void> saveBroadcast(AdminBroadcastRecord record) {
    return _localDatabase.upsertAdminBroadcast(record);
  }

  Future<void> saveAuditLog(AdminAuditLogRecord record) {
    return _localDatabase.insertAdminAuditLog(record);
  }

  DateTime _startDateForPeriod(DateTime now, AdminAnalyticsPeriod period) {
    switch (period) {
      case AdminAnalyticsPeriod.sevenDays:
        return now.subtract(const Duration(days: 7));
      case AdminAnalyticsPeriod.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case AdminAnalyticsPeriod.threeMonths:
        return now.subtract(const Duration(days: 90));
      case AdminAnalyticsPeriod.sixMonths:
        return now.subtract(const Duration(days: 180));
      case AdminAnalyticsPeriod.oneYear:
        return now.subtract(const Duration(days: 365));
    }
  }
}
