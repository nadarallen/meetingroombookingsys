import 'dart:convert';

class SyncStatus {
  static const synced = 'synced';
  static const pendingUp = 'pending_up';
  static const pendingDelete = 'pending_delete';
  static const failed = 'failed';
}

enum BookingStatus { pending, confirmed, cancelled }

BookingStatus bookingStatusFromString(String value) {
  return BookingStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => BookingStatus.pending,
  );
}

class Booking {
  Booking({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    this.status = BookingStatus.pending,
    this.title,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata = const {},
    this.syncStatus = SyncStatus.synced,
    this.noShowRiskScore,
    this.checkedIn,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String roomId;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final String? title;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;
  final String syncStatus;
  final int? noShowRiskScore;
  final bool? checkedIn;

  Booking copyWith({
    String? id,
    String? roomId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    BookingStatus? status,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    String? syncStatus,
    int? noShowRiskScore,
    bool? checkedIn,
  }) {
    return Booking(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      syncStatus: syncStatus ?? this.syncStatus,
      noShowRiskScore: noShowRiskScore ?? this.noShowRiskScore,
      checkedIn: checkedIn ?? this.checkedIn,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'status': status.name,
      'title': title,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'metadata': jsonEncode(metadata),
      'sync_status': syncStatus,
      'no_show_risk_score': noShowRiskScore,
      'checked_in': checkedIn == true ? 1 : 0,
    };
  }

  factory Booking.fromLocalMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (map['start_time'] as num).toInt(),
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (map['end_time'] as num).toInt(),
      ),
      status: bookingStatusFromString(map['status'] as String),
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
      metadata: _decodeMetadata(map['metadata'] as String?),
      syncStatus: map['sync_status'] as String? ?? SyncStatus.synced,
      noShowRiskScore: map['no_show_risk_score'] as int?,
      checkedIn: (map['checked_in'] as num?)?.toInt() == 1,
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'startTime': startTime.toUtc(),
      'endTime': endTime.toUtc(),
      'status': status.name,
      'title': title,
      'notes': notes,
      'createdAt': createdAt.toUtc(),
      'updatedAt': updatedAt.toUtc(),
      'metadata': metadata,
      'syncStatus': syncStatus,
      'noShowRiskScore': noShowRiskScore,
      'checkedIn': checkedIn,
    };
  }

  factory Booking.fromCloudMap(String id, Map<String, dynamic> map) {
    return Booking(
      id: id,
      roomId: map['roomId'] as String,
      userId: map['userId'] as String,
      startTime: _fromTimestamp(map['startTime']),
      endTime: _fromTimestamp(map['endTime']),
      status: bookingStatusFromString(map['status'] as String? ?? 'pending'),
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      createdAt: _fromTimestamp(map['createdAt']),
      updatedAt: _fromTimestamp(map['updatedAt']),
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? const {},
      syncStatus: map['syncStatus'] as String? ?? SyncStatus.synced,
      noShowRiskScore: map['noShowRiskScore'] as int?,
      checkedIn: map['checkedIn'] as bool?,
    );
  }

  static Map<String, dynamic> _decodeMetadata(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  static DateTime _fromTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }
}
