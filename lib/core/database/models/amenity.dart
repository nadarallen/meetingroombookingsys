import 'dart:convert';

class Amenity {
  Amenity({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  })  : metadata = metadata ?? const {},
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String? description;
  final String? icon;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Amenity copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Amenity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'metadata': jsonEncode(metadata),
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Amenity.fromLocalMap(Map<String, dynamic> map) {
    return Amenity(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      metadata: _decodeMetadata(map['metadata'] as String?),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'metadata': metadata,
      'updatedAt': updatedAt.toUtc(),
    };
  }

  factory Amenity.fromCloudMap(String id, Map<String, dynamic> map) {
    return Amenity(
      id: id,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? const {},
      updatedAt: (map['updatedAt'] as DateTime?) ??
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
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
}
