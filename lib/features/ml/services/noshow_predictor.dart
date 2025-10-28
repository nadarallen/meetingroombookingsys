import '../../../core/database/local_database.dart';
import '../../../core/database/models/booking.dart';
import '../../../core/database/models/app_user.dart';

class NoShowPredictor {
  NoShowPredictor({required LocalDatabase localDatabase})
      : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  /// Predict the no-show risk for a booking (0-100 scale)
  /// Higher score = higher risk of no-show
  Future<NoShowRisk> predictRisk(Booking booking) async {
    final user = await _localDatabase.getUserById(booking.userId);

    if (user == null) {
      return NoShowRisk(
        riskScore: 50,
        factors: ['User information not available'],
        recommendation: 'Use standard reminders',
      );
    }

    final riskFactors = <String>[];
    int totalScore = 0;

    // Factor 1: User's historical no-show rate (0-40 points)
    final noShowRate = await _getHistoricalNoShowRate(booking.userId);
    final noShowScore = (noShowRate * 40).round();
    totalScore += noShowScore;
    if (noShowRate > 0.3) {
      riskFactors.add(
          'High historical no-show rate (${(noShowRate * 100).toStringAsFixed(1)}%)');
    }

    // Factor 2: Advance booking time (0-20 points)
    final advanceHours = booking.startTime.difference(DateTime.now()).inHours;
    int advanceScore = 0;
    if (advanceHours > 168) {
      // > 7 days
      advanceScore = 20;
      riskFactors.add('Booked far in advance (${advanceHours ~/ 24} days)');
    } else if (advanceHours > 24) {
      // 1-7 days
      advanceScore = 10;
      riskFactors.add('Booked well in advance (${advanceHours ~/ 24} days)');
    } else if (advanceHours < 4) {
      // < 4 hours
      advanceScore = 5;
      riskFactors.add('Last-minute booking (${advanceHours}h in advance)');
    } else {
      advanceScore = 0;
    }
    totalScore += advanceScore;

    // Factor 3: Time of day (0-15 points)
    final hour = booking.startTime.hour;
    int timeScore = 0;
    if (hour >= 9 && hour <= 11) {
      timeScore = 0; // Morning meetings have lower risk
    } else if (hour >= 12 && hour <= 14) {
      timeScore = 8;
      riskFactors.add('Lunch time slot');
    } else if (hour >= 14 && hour <= 17) {
      timeScore = 5;
    } else if (hour >= 17) {
      timeScore = 15;
      riskFactors.add('Late day time slot');
    } else {
      timeScore = 10; // Very early morning
      riskFactors.add('Early morning time slot');
    }
    totalScore += timeScore;

    // Factor 4: Day of week (0-15 points)
    final weekday = booking.startTime.weekday;
    int dayScore = 0;
    if (weekday == DateTime.friday) {
      dayScore = 15;
      riskFactors.add('Friday booking');
    } else if (weekday == DateTime.monday) {
      dayScore = 5;
      riskFactors.add('Monday booking');
    } else if (weekday >= DateTime.saturday) {
      dayScore = 10;
      riskFactors.add('Weekend booking');
    }
    totalScore += dayScore;

    // Factor 5: Booking duration (0-10 points)
    final durationMinutes =
        booking.endTime.difference(booking.startTime).inMinutes;
    int durationScore = 0;
    if (durationMinutes > 180) {
      // > 3 hours
      durationScore = 10;
      riskFactors.add('Long duration meeting (${durationMinutes ~/ 60}h)');
    } else if (durationMinutes < 30) {
      // < 30 minutes
      durationScore = 5;
      riskFactors.add('Very short meeting (${durationMinutes}m)');
    }
    totalScore += durationScore;

    // Ensure score is within 0-100 range
    final finalScore = totalScore.clamp(0, 100);

    return NoShowRisk(
      riskScore: finalScore,
      factors: riskFactors.isEmpty ? ['Low risk booking'] : riskFactors,
      recommendation: _getRecommendation(finalScore),
    );
  }

  /// Get historical no-show rate for a user
  Future<double> _getHistoricalNoShowRate(String userId) async {
    final bookings = await _localDatabase.getBookings();

    final userBookings = bookings
        .where(
            (b) => b.userId == userId && b.startTime.isBefore(DateTime.now()))
        .toList();

    if (userBookings.isEmpty) return 0.0;

    int totalBookings = 0;
    int noShows = 0;

    for (final booking in userBookings) {
      totalBookings++;

      // Check if this was a no-show
      // A booking is considered no-show if:
      // 1. Status is confirmed but no actual usage occurred
      // 2. Status is cancelled close to start time
      if (booking.status == BookingStatus.confirmed) {
        // If booking ended and no check-in, it's a no-show
        // For now, use a heuristic based on metadata
        if (booking.metadata['checkedIn'] == null ||
            booking.metadata['checkedIn'] == false) {
          noShows++;
        }
      }
    }

    return totalBookings > 0 ? noShows / totalBookings : 0.0;
  }

  String _getRecommendation(int riskScore) {
    if (riskScore >= 70) {
      return 'HIGH RISK - Send multiple reminders: 2 hours, 30 minutes, and 15 minutes before';
    } else if (riskScore >= 50) {
      return 'MEDIUM RISK - Send reminders at 30 minutes and 15 minutes before';
    } else {
      return 'LOW RISK - Standard reminder at 15 minutes before';
    }
  }

  /// Check if a booking is at high risk for no-show
  bool isHighRisk(int riskScore) => riskScore >= 60;
}

class NoShowRisk {
  NoShowRisk({
    required this.riskScore,
    required this.factors,
    required this.recommendation,
  });

  final int riskScore; // 0-100
  final List<String> factors;
  final String recommendation;

  String get riskLevel {
    if (riskScore >= 70) return 'HIGH';
    if (riskScore >= 50) return 'MEDIUM';
    if (riskScore >= 30) return 'LOW';
    return 'VERY LOW';
  }

  bool get isHighRisk => riskScore >= 60;
}
