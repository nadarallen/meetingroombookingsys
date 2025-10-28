import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/booking.dart';
import '../../../../core/database/models/room.dart';
import '../../../../core/database/models/app_user.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  String _selectedPeriod = '30 days';
  bool _loading = false;
  Map<String, dynamic> _analyticsData = {};

  final List<String> _periods = [
    '7 days',
    '30 days',
    '3 months',
    '6 months',
    '1 year',
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final localDatabase = context.read<LocalDatabase>();
      final now = DateTime.now();
      final startDate = _getStartDate(now, _selectedPeriod);

      final bookings = await localDatabase.getBookings();
      final rooms = await localDatabase.getRooms();
      final users = await localDatabase.getUsers();

      // Filter bookings by period
      final filteredBookings = bookings
          .where((b) =>
              b.startTime.isAfter(startDate) && b.startTime.isBefore(now))
          .toList();

      setState(() {
        _analyticsData = _calculateAnalytics(filteredBookings, rooms, users);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime _getStartDate(DateTime now, String period) {
    switch (period) {
      case '7 days':
        return now.subtract(const Duration(days: 7));
      case '30 days':
        return now.subtract(const Duration(days: 30));
      case '3 months':
        return now.subtract(const Duration(days: 90));
      case '6 months':
        return now.subtract(const Duration(days: 180));
      case '1 year':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  Map<String, dynamic> _calculateAnalytics(
    List<Booking> bookings,
    List<Room> rooms,
    List<AppUser> users,
  ) {
    // Booking trends (daily data for line chart)
    final bookingTrends = <String, int>{};
    for (final booking in bookings) {
      final dateKey =
          '${booking.startTime.year}-${booking.startTime.month.toString().padLeft(2, '0')}-${booking.startTime.day.toString().padLeft(2, '0')}';
      bookingTrends[dateKey] = (bookingTrends[dateKey] ?? 0) + 1;
    }

    // Room utilization
    final roomUtilization = <String, double>{};
    for (final room in rooms) {
      final roomBookings = bookings.where((b) => b.roomId == room.id).length;
      final daysInPeriod = _getStartDate(DateTime.now(), _selectedPeriod)
          .difference(DateTime.now())
          .inDays
          .abs();
      roomUtilization[room.name] =
          daysInPeriod > 0 ? (roomBookings / daysInPeriod * 100) : 0;
    }

    // Peak hours heatmap (24-hour grid)
    final peakHours = List.generate(24, (hour) => 0);
    for (final booking in bookings) {
      peakHours[booking.startTime.hour]++;
    }

    // Department distribution
    final departmentUsage = <String, int>{};
    for (final booking in bookings) {
      final user = users.firstWhere((u) => u.id == booking.userId,
          orElse: () => AppUser(id: '', email: ''));
      final dept = user.department ?? 'Unknown';
      departmentUsage[dept] = (departmentUsage[dept] ?? 0) + 1;
    }

    // Top rooms and users
    final roomBookings = <String, int>{};
    final userBookings = <String, int>{};

    for (final booking in bookings) {
      roomBookings[booking.roomId] = (roomBookings[booking.roomId] ?? 0) + 1;
      userBookings[booking.userId] = (userBookings[booking.userId] ?? 0) + 1;
    }

    final topRooms = roomBookings.entries
        .map((e) => {'roomId': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final topUsers = userBookings.entries
        .map((e) => {'userId': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'bookingTrends': bookingTrends,
      'roomUtilization': roomUtilization,
      'peakHours': peakHours,
      'departmentUsage': departmentUsage,
      'topRooms': topRooms.take(5).toList(),
      'topUsers': topUsers.take(5).toList(),
      'totalBookings': bookings.length,
      'totalRooms': rooms.length,
      'totalUsers': users.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 24),
                        _buildBookingTrendsChart(),
                        const SizedBox(height: 24),
                        _buildRoomUtilizationChart(),
                        const SizedBox(height: 24),
                        _buildPeakHoursHeatmap(),
                        const SizedBox(height: 24),
                        _buildDepartmentDistributionChart(),
                        const SizedBox(height: 24),
                        _buildTopRoomsTable(),
                        const SizedBox(height: 24),
                        _buildTopUsersTable(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('Period:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _periods
                  .map((period) => DropdownMenuItem(
                        value: period,
                        child: Text(period),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedPeriod = value!);
                _loadAnalytics();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Bookings',
            value: '${_analyticsData['totalBookings'] ?? 0}',
            icon: Icons.event_note,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Active Rooms',
            value: '${_analyticsData['totalRooms'] ?? 0}',
            icon: Icons.meeting_room,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Active Users',
            value: '${_analyticsData['totalUsers'] ?? 0}',
            icon: Icons.people,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingTrendsChart() {
    final trends = _analyticsData['bookingTrends'] as Map<String, int>? ?? {};
    if (trends.isEmpty) {
      return const _EmptyChart('No booking data available');
    }

    final spots = trends.entries.map((e) {
      final date = DateTime.parse(e.key);
      return FlSpot(date.millisecondsSinceEpoch.toDouble(), e.value.toDouble());
    }).toList();

    spots.sort((a, b) => a.x.compareTo(b.x));

    return _ChartCard(
      title: 'Booking Trends',
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Text('${date.day}/${date.month}');
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomUtilizationChart() {
    final utilization =
        _analyticsData['roomUtilization'] as Map<String, double>? ?? {};
    if (utilization.isEmpty) {
      return const _EmptyChart('No room utilization data available');
    }

    final sortedRooms = utilization.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: 'Room Utilization',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}%'),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < sortedRooms.length) {
                    final roomName = sortedRooms[index].key;
                    return Text(
                      roomName.length > 8
                          ? '${roomName.substring(0, 8)}...'
                          : roomName,
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          barGroups: sortedRooms.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: Colors.green,
                  width: 20,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeakHoursHeatmap() {
    final peakHours = _analyticsData['peakHours'] as List<int>? ?? [];
    if (peakHours.isEmpty) {
      return const _EmptyChart('No peak hours data available');
    }

    final maxBookings =
        peakHours.isNotEmpty ? peakHours.reduce((a, b) => a > b ? a : b) : 1;

    return _ChartCard(
      title: 'Peak Booking Hours',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 1,
        ),
        itemCount: 24,
        itemBuilder: (context, index) {
          final intensity = peakHours[index] / maxBookings;
          final color =
              Color.lerp(Colors.green[100], Colors.red[600], intensity);
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: intensity > 0.5 ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepartmentDistributionChart() {
    final departmentUsage =
        _analyticsData['departmentUsage'] as Map<String, int>? ?? {};
    if (departmentUsage.isEmpty) {
      return const _EmptyChart('No department data available');
    }

    final total = departmentUsage.values.fold(0, (a, b) => a + b);
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red
    ];

    return _ChartCard(
      title: 'Department Usage Distribution',
      child: PieChart(
        PieChartData(
          sections: departmentUsage.entries.map((e) {
            final index = departmentUsage.keys.toList().indexOf(e.key);
            return PieChartSectionData(
              value: e.value.toDouble(),
              title: '${e.key}\n${(e.value / total * 100).toStringAsFixed(1)}%',
              color: colors[index % colors.length],
              radius: 80,
              titleStyle: const TextStyle(fontSize: 10),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopRoomsTable() {
    final topRooms =
        _analyticsData['topRooms'] as List<Map<String, dynamic>>? ?? [];
    if (topRooms.isEmpty) {
      return const _EmptyChart('No room data available');
    }

    return _ChartCard(
      title: 'Top 5 Most Booked Rooms',
      child: Column(
        children: topRooms.map((room) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text('${topRooms.indexOf(room) + 1}'),
            ),
            title: Text('Room ${room['roomId']}'),
            trailing: Text('${room['count']} bookings'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopUsersTable() {
    final topUsers =
        _analyticsData['topUsers'] as List<Map<String, dynamic>>? ?? [];
    if (topUsers.isEmpty) {
      return const _EmptyChart('No user data available');
    }

    return _ChartCard(
      title: 'Top 5 Most Active Users',
      child: Column(
        children: topUsers.map((user) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text('${topUsers.indexOf(user) + 1}'),
            ),
            title: Text('User ${user['userId']}'),
            trailing: Text('${user['count']} bookings'),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
