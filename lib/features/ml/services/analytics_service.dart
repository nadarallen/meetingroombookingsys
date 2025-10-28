import 'dart:math';

import '../../../core/database/local_database.dart';
import '../../../core/database/models/booking.dart';
import '../../../core/database/models/room.dart';

class AnalyticsService {
  AnalyticsService({required LocalDatabase localDatabase})
      : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  /// Calculate room utilization percentage
  Future<Map<String, double>> getRoomUtilization({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final rooms = await _localDatabase.getRooms();
    final bookings = await _localDatabase.getBookings();

    final utilization = <String, double>{};

    for (final room in rooms) {
      final roomBookings = bookings
          .where((b) =>
              b.roomId == room.id &&
              b.startTime.isAfter(startDate) &&
              b.endTime.isBefore(endDate) &&
              b.status == BookingStatus.confirmed)
          .toList();

      // Calculate total booked minutes
      double totalBookedMinutes = 0;
      for (final booking in roomBookings) {
        totalBookedMinutes +=
            booking.endTime.difference(booking.startTime).inMinutes;
      }

      // Calculate total available minutes
      final totalAvailableMinutes =
          endDate.difference(startDate).inMinutes.toDouble();

      final utilizationPercent = totalAvailableMinutes > 0
          ? (totalBookedMinutes / totalAvailableMinutes * 100).clamp(0, 100)
          : 0.0;

      utilization[room.name] = utilizationPercent;
    }

    return utilization;
  }

  /// Predict availability for the next 7 days
  Future<AvailabilityPrediction> predictNextWeekAvailability() async {
    final rooms = await _localDatabase.getRooms();
    final bookings = await _localDatabase.getBookings();

    final now = DateTime.now();
    final next7Days = List.generate(7, (i) => now.add(Duration(days: i)));

    final predictions = <DateAvailability>[];

    for (final day in next7Days) {
      final dayStart = DateTime(day.year, day.month, day.day, 0, 0);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59);

      // Get bookings for this day
      final dayBookings = bookings
          .where((b) =>
              b.startTime.isAfter(dayStart) &&
              b.endTime.isBefore(dayEnd) &&
              b.status == BookingStatus.confirmed)
          .toList();

      // Calculate hourly availability
      final hourlyAvailability = <int, int>{};
      for (int hour = 9; hour < 18; hour++) {
        final hourStart = DateTime(day.year, day.month, day.day, hour, 0);
        final hourEnd = DateTime(day.year, day.month, day.day, hour + 1, 0);

        // Count booked rooms at this hour
        final bookedCount = dayBookings
            .where((b) =>
                (b.startTime.isBefore(hourEnd) && b.endTime.isAfter(hourStart)))
            .length;

        final availableRooms =
            rooms.where((r) => r.isActive).length - bookedCount;
        hourlyAvailability[hour] = availableRooms;
      }

      predictions.add(DateAvailability(
        date: day,
        hourlyAvailability: hourlyAvailability,
        totalBookings: dayBookings.length,
        peakHour: _findPeakHour(dayBookings),
      ));
    }

    // Calculate confidence level based on historical data
    final confidence = _calculateConfidence(bookings);

    return AvailabilityPrediction(
      predictions: predictions,
      confidence: confidence,
      averageUtilization: _calculateAverageUtilization(bookings, rooms),
    );
  }

  /// Get peak hours heatmap data
  Future<Map<int, double>> getPeakHoursHeatmap() async {
    final bookings = await _localDatabase.getBookings();
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    final hourlyCounts = <int, int>{};

    for (final booking in bookings) {
      if (booking.startTime.isAfter(threeMonthsAgo) &&
          booking.startTime.isBefore(now) &&
          booking.status == BookingStatus.confirmed) {
        final hour = booking.startTime.hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }

    if (hourlyCounts.isEmpty) {
      return {};
    }

    final maxCount = hourlyCounts.values.reduce(max);

    return hourlyCounts.map(
        (hour, count) => MapEntry(hour, (count / maxCount).clamp(0.0, 1.0)));
  }

  /// Predict peak usage times with confidence levels
  Future<List<PeakHourPrediction>> predictPeakHours() async {
    final bookings = await _localDatabase.getBookings();
    final now = DateTime.now();
    final last30Days = DateTime(now.year, now.month, now.day - 30);

    final hourlyCounts = <int, int>{};

    // Count bookings by hour for last 30 days
    for (final booking in bookings) {
      if (booking.startTime.isAfter(last30Days) &&
          booking.startTime.isBefore(now) &&
          booking.status == BookingStatus.confirmed) {
        final hour = booking.startTime.hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }

    if (hourlyCounts.isEmpty) {
      return [];
    }

    // Calculate averages and trends
    final predictions = hourlyCounts.entries.map((entry) {
      final hour = entry.key;
      final count = entry.value;
      final avgDailyBookings = count / 30.0;

      String confidence;
      if (avgDailyBookings >= 5) {
        confidence = 'HIGH';
      } else if (avgDailyBookings >= 2) {
        confidence = 'MEDIUM';
      } else {
        confidence = 'LOW';
      }

      return PeakHourPrediction(
        hour: hour,
        expectedBookings: avgDailyBookings,
        confidence: confidence,
      );
    }).toList();

    predictions
        .sort((a, b) => b.expectedBookings.compareTo(a.expectedBookings));

    return predictions;
  }

  int _findPeakHour(List<Booking> dayBookings) {
    if (dayBookings.isEmpty) return 12; // Default to noon

    final hourlyCounts = <int, int>{};
    for (final booking in dayBookings) {
      final hour = booking.startTime.hour;
      hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
    }

    final peakHourEntry =
        hourlyCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    return peakHourEntry.key;
  }

  double _calculateConfidence(List<Booking> bookings) {
    // Calculate confidence based on amount of historical data
    final totalBookings = bookings.length;

    if (totalBookings > 100) return 0.9;
    if (totalBookings > 50) return 0.75;
    if (totalBookings > 20) return 0.6;
    if (totalBookings > 10) return 0.4;
    return 0.2;
  }

  double _calculateAverageUtilization(
      List<Booking> bookings, List<Room> rooms) {
    if (bookings.isEmpty || rooms.isEmpty) return 0.0;

    // Simplified utilization calculation
    final activeRooms = rooms.where((r) => r.isActive).length;
    final totalBookings = bookings.length;

    return (totalBookings / activeRooms).clamp(0.0, 100.0);
  }
}

class AvailabilityPrediction {
  AvailabilityPrediction({
    required this.predictions,
    required this.confidence,
    required this.averageUtilization,
  });

  final List<DateAvailability> predictions;
  final double confidence; // 0.0 to 1.0
  final double averageUtilization; // 0-100 percentage
}

class DateAvailability {
  DateAvailability({
    required this.date,
    required this.hourlyAvailability,
    required this.totalBookings,
    required this.peakHour,
  });

  final DateTime date;
  final Map<int, int> hourlyAvailability; // hour -> available rooms count
  final int totalBookings;
  final int peakHour;
}

class PeakHourPrediction {
  PeakHourPrediction({
    required this.hour,
    required this.expectedBookings,
    required this.confidence,
  });

  final int hour;
  final double expectedBookings;
  final String confidence; // HIGH, MEDIUM, LOW
}
