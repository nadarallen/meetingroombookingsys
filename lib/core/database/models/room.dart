import 'dart:convert';

class Room {
  Room({
    required this.id,
    required this.name,
    required this.capacity,
    required this.location,
    this.description,
    this.imageUrl,
    this.amenityIds = const [],
    this.latitude,
    this.longitude,
    this.isActive = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final int capacity;
  final String location;
  final String? description;
  final String? imageUrl;
  final List<String> amenityIds;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime updatedAt;

  Room copyWith({
    String? id,
    String? name,
    int? capacity,
    String? location,
    String? description,
    String? imageUrl,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      amenityIds: amenityIds ?? this.amenityIds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
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
      'image_url': imageUrl,
      'amenity_ids': jsonEncode(amenityIds),
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive ? 1 : 0,
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
      imageUrl: map['image_url'] as String?,
      amenityIds: rawAmenities == null || rawAmenities.isEmpty
          ? const []
          : List<String>.from(jsonDecode(rawAmenities) as List),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isActive: (map['is_active'] as num?)?.toInt() == 1,
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
      'imageUrl': imageUrl,
      'amenityIds': amenityIds,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
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
      imageUrl: map['imageUrl'] as String?,
      amenityIds: (map['amenityIds'] as List<dynamic>? ?? [])
          .map((dynamic item) => item as String)
          .toList(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isActive: map['isActive'] as bool? ?? true,
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  @override
  String toString() {
    return 'Room(id: $id, name: $name, capacity: $capacity, location: $location, lat: $latitude, lng: $longitude)';
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      capacity.hashCode ^
      location.hashCode ^
      description.hashCode ^
      imageUrl.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      amenityIds.hashCode ^
      isActive.hashCode ^
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
        imageUrl == other.imageUrl &&
        _listEquals(amenityIds, other.amenityIds) &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        isActive == other.isActive &&
        updatedAt == other.updatedAt;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();

    // Handle Firestore Timestamp
    if (value.runtimeType.toString().contains('Timestamp')) {
      try {
        // Use reflection to call toDate() method on Firestore Timestamp
        return value.toDate() as DateTime;
      } catch (e) {
        // Fallback to string parsing
        return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
      }
    }

    // Handle DateTime directly
    if (value is DateTime) return value.toLocal();

    // Handle string representation
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }

    // Handle numeric timestamp (milliseconds)
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }

    return DateTime.now();
  }
}
