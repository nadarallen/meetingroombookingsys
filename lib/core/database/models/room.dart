import 'dart:convert';

class Room {
  Room({
    required this.id,
    required this.name,
    required this.capacity,
    required this.location,
    this.description,
    this.amenityIds = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final int capacity;
  final String location;
  final String? description;
  final List<String> amenityIds;
  final DateTime updatedAt;

  Room copyWith({
    String? id,
    String? name,
    int? capacity,
    String? location,
    String? description,
    List<String>? amenityIds,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      description: description ?? this.description,
      amenityIds: amenityIds ?? this.amenityIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'location': location,
      'description': description,
      'amenity_ids': jsonEncode(amenityIds),
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Room.fromLocalMap(Map<String, dynamic> map) {
    final rawAmenities = map['amenity_ids'] as String?;
    return Room(
      id: map['id'] as String,
      name: map['name'] as String,
      capacity: (map['capacity'] as num).toInt(),
      location: map['location'] as String,
      description: map['description'] as String?,
      amenityIds: rawAmenities == null || rawAmenities.isEmpty
          ? const []
          : List<String>.from(jsonDecode(rawAmenities) as List),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'name': name,
      'capacity': capacity,
      'location': location,
      'description': description,
      'amenityIds': amenityIds,
      'updatedAt': updatedAt.toUtc(),
    };
  }

  factory Room.fromCloudMap(String id, Map<String, dynamic> map) {
    return Room(
      id: id,
      name: map['name'] as String,
      capacity: (map['capacity'] as num).toInt(),
      location: map['location'] as String,
      description: map['description'] as String?,
      amenityIds: (map['amenityIds'] as List<dynamic>? ?? [])
          .map((dynamic item) => item as String)
          .toList(),
      updatedAt: (map['updatedAt'] as DateTime?) ??
          DateTime.tryParse(map['updatedAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Room(id: $id, name: $name, capacity: $capacity, location: $location)';
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      capacity.hashCode ^
      location.hashCode ^
      description.hashCode ^
      amenityIds.hashCode ^
      updatedAt.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Room) return false;
    return id == other.id &&
        name == other.name &&
        capacity == other.capacity &&
        location == other.location &&
        description == other.description &&
        _listEquals(amenityIds, other.amenityIds) &&
        updatedAt == other.updatedAt;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
