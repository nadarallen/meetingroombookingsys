class MeetingRoom {
  final String id;
  final String name;
  final int capacity;

  const MeetingRoom({required this.id, required this.name, required this.capacity});

  MeetingRoom copyWith({String? id, String? name, int? capacity}) =>
      MeetingRoom(id: id ?? this.id, name: name ?? this.name, capacity: capacity ?? this.capacity);
}

