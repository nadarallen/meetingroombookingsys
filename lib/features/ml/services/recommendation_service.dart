import 'dart:math';

import '../../../core/database/local_database.dart';
import '../../../core/database/models/booking.dart';
import '../../../core/database/models/room.dart';

class RecommendationService {
  RecommendationService({required LocalDatabase localDatabase})
      : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  /// Get top recommended rooms for a user based on their booking history
  /// Returns list of RoomScore objects sorted by score (highest first)
  Future<List<RoomScore>> getRecommendedRooms(String userId) async {
    final rooms = await _localDatabase.getRooms();
    final bookings = await _localDatabase.getBookings();

    // Filter user's past bookings
    final userBookings = bookings
        .where((b) =>
            b.userId == userId &&
            b.startTime.isBefore(DateTime.now()) &&
            b.status == BookingStatus.confirmed)
        .toList();

    // If no booking history, return empty
    if (userBookings.isEmpty) {
      return [];
    }

    final scores = <RoomScore>[];

    for (final room in rooms.where((r) => r.isActive)) {
      if (room.latitude == null || room.longitude == null) continue;

      final score = _calculateRoomScore(room, userBookings, bookings);
      scores.add(RoomScore(
          room: room, score: score, reasons: _getReasons(room, userBookings)));
    }

    // Sort by score (descending) and return top 3
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(3).toList();
  }

  double _calculateRoomScore(
      Room room, List<Booking> userBookings, List<Booking> allBookings) {
    double score = 0.0;

    // Factor 1: Historical usage (40% weight)
    final userRoomBookings =
        userBookings.where((b) => b.roomId == room.id).length;
    final totalUserBookings = userBookings.length;
    final usageScore =
        totalUserBookings > 0 ? (userRoomBookings / totalUserBookings) * 40 : 0;
    score += usageScore;

    // Factor 2: Time-of-day preference (20% weight)
    final preferredHours = _extractPreferredHours(userBookings);
    final currentHour = DateTime.now().hour;
    final hourMatchScore = preferredHours.contains(currentHour) ? 20 : 0;
    score += hourMatchScore;

    // Factor 3: Average meeting duration match (20% weight)
    final avgDuration = _calculateAverageDuration(userRoomBookings > 0
        ? userBookings.where((b) => b.roomId == room.id).toList()
        : userBookings);
    final durationScore = _evaluateDurationMatch(room, avgDuration);
    score += durationScore * 20;

    // Factor 4: Capacity appropriateness (10% weight)
    final capacityScore = _evaluateCapacity(room, userBookings);
    score += capacityScore * 10;

    // Factor 5: Popularity indicator (10% weight)
    final allRoomBookings =
        allBookings.where((b) => b.roomId == room.id).length;
    final popularityScore =
        (allRoomBookings / max(allBookings.length, 1)) * 100;
    score += popularityScore * 0.1;

    return score;
  }

  List<int> _extractPreferredHours(List<Booking> bookings) {
    final hourCounts = <int, int>{};

    for (final booking in bookings) {
      final hour = booking.startTime.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    // Get top 3 most frequent hours
    final sortedHours = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedHours.take(3).map((e) => e.key).toList();
  }

  double _calculateAverageDuration(List<Booking> bookings) {
    if (bookings.isEmpty) return 0.0;

    final totalDuration = bookings.fold(
      0,
      (sum, booking) =>
          sum + booking.endTime.difference(booking.startTime).inMinutes,
    );

    return totalDuration / bookings.length;
  }

  double _evaluateDurationMatch(Room room, double avgDuration) {
    // Match based on room capacity and typical meeting duration
    // Larger rooms for longer meetings
    final capacity = room.capacity;
    final idealDurationForCapacity = capacity * 15.0; // Rough heuristic

    final diff = (avgDuration - idealDurationForCapacity).abs();
    final maxDiff = idealDurationForCapacity * 2;

    return 1.0 - (diff / maxDiff).clamp(0.0, 1.0);
  }

  double _evaluateCapacity(Room room, List<Booking> userBookings) {
    // Calculate ideal capacity based on user's typical group size
    // For simplicity, assume they need rooms with reasonable capacity
    if (userBookings.isEmpty) return 0.5;

    // Return a score based on room capacity
    // Assuming typical meetings need 2-8 people
    if (room.capacity >= 2 && room.capacity <= 8) return 1.0;
    if (room.capacity >= 9 && room.capacity <= 20) return 0.7;
    return 0.3;
  }

  List<String> _getReasons(Room room, List<Booking> userBookings) {
    final reasons = <String>[];

    final userRoomBookings =
        userBookings.where((b) => b.roomId == room.id).length;
    if (userRoomBookings > 0) {
      final percentage = (userRoomBookings / userBookings.length * 100).round();
      reasons.add(
          'You\'ve booked this room $userRoomBookings times ($percentage% of your bookings)');
    }

    if (room.location != null && room.location!.isNotEmpty) {
      reasons.add('Located at ${room.location}');
    }

    if (room.capacity <= 10) {
      reasons.add('Perfect size for small to medium meetings');
    }

    return reasons;
  }
}

class RoomScore {
  RoomScore({
    required this.room,
    required this.score,
    required this.reasons,
  });

  final Room room;
  final double score;
  final List<String> reasons;
}
