class BroadcastTargets {
  const BroadcastTargets({
    required this.departments,
    required this.activeUsers,
    required this.activeAdmins,
    required this.departmentCounts,
  });

  final List<String> departments;
  final int activeUsers;
  final int activeAdmins;
  final Map<String, int> departmentCounts;
}
