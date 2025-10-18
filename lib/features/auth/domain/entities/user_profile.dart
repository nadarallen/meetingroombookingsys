class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String employeeId;
  final String department;
  final String role;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.department,
    this.role = 'member',
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? employeeId,
    String? department,
    String? role,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      role: role ?? this.role,
    );
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map, {String? email}) {
    final rawRole = map['role'];
    final normalizedRole = rawRole is String && rawRole.trim().isNotEmpty
        ? rawRole.trim().toLowerCase()
        : 'member';
    return UserProfile(
      uid: uid,
      fullName: (map['fullName'] as String?)?.trim() ?? '',
      email: email ?? (map['email'] as String?)?.trim() ?? '',
      employeeId: (map['employeeId'] as String?)?.trim() ?? '',
      department: (map['department'] as String?)?.trim() ?? '',
      role: normalizedRole,
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'email': email,
        'employeeId': employeeId,
        'department': department,
        'role': role,
      };
}
