class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.todaysBookings,
    required this.weekBookings,
    required this.monthBookings,
    required this.activeUsers,
    required this.roomUtilization,
    required this.pendingApprovals,
    required this.checkInsToday,
    required this.cancellationsThisWeek,
    required this.queuedBroadcasts,
  });

  final int todaysBookings;
  final int weekBookings;
  final int monthBookings;
  final int activeUsers;
  final double roomUtilization;
  final int pendingApprovals;
  final int checkInsToday;
  final int cancellationsThisWeek;
  final int queuedBroadcasts;

  AdminDashboardMetrics copyWith({
    int? todaysBookings,
    int? weekBookings,
    int? monthBookings,
    int? activeUsers,
    double? roomUtilization,
    int? pendingApprovals,
    int? checkInsToday,
    int? cancellationsThisWeek,
    int? queuedBroadcasts,
  }) {
    return AdminDashboardMetrics(
      todaysBookings: todaysBookings ?? this.todaysBookings,
      weekBookings: weekBookings ?? this.weekBookings,
      monthBookings: monthBookings ?? this.monthBookings,
      activeUsers: activeUsers ?? this.activeUsers,
      roomUtilization: roomUtilization ?? this.roomUtilization,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      checkInsToday: checkInsToday ?? this.checkInsToday,
      cancellationsThisWeek:
          cancellationsThisWeek ?? this.cancellationsThisWeek,
      queuedBroadcasts: queuedBroadcasts ?? this.queuedBroadcasts,
    );
  }
}
