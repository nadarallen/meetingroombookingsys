class AppUser {
  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.department,
    this.photoUrl,
    this.role = 'member',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String email;
  final String? displayName;
  final String? department;
  final String? photoUrl;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? department,
    String? photoUrl,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'department': department,
      'photo_url': photoUrl,
      'role': role,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory AppUser.fromLocalMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String?,
      department: map['department'] as String?,
      photoUrl: map['photo_url'] as String?,
      role: map['role'] as String? ?? 'member',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
      isActive: (map['is_active'] as num?)?.toInt() == 1,
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'email': email,
      'displayName': displayName,
      'department': department,
      'photoUrl': photoUrl,
      'role': role,
      'createdAt': createdAt.toUtc(),
      'updatedAt': updatedAt.toUtc(),
      'isActive': isActive,
    };
  }

  factory AppUser.fromCloudMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      department: map['department'] as String?,
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? 'member',
      createdAt: _fromTimestamp(map['createdAt']),
      updatedAt: _fromTimestamp(map['updatedAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static DateTime _fromTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }
}
