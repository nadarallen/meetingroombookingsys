class Booking {
  final String id;
  final String roomId;
  final String title;
  final DateTime start;
  final DateTime end;

  const Booking({
    required this.id,
    required this.roomId,
    required this.title,
    required this.start,
    required this.end,
  });
}

