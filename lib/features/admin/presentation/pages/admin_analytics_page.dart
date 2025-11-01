import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/admin_analytics_report.dart';
import '../../domain/entities/admin_top_performer.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/get_admin_analytics_report.dart';
import '../viewmodels/admin_analytics_view_model.dart';

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AdminRepository>();
    return ChangeNotifierProvider(
      create: (_) => AdminAnalyticsViewModel(
        getAdminAnalyticsReport: GetAdminAnalyticsReport(repository),
      )..load(),
      child: const _AdminAnalyticsView(),
    );
  }
}

class _AdminAnalyticsView extends StatelessWidget {
  const _AdminAnalyticsView();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAnalyticsViewModel>(
      builder: (context, viewModel, _) {
        final report = viewModel.report;
        final isLoading = viewModel.isLoading && report == null;
        final hasError = viewModel.error != null && report == null;

        return Scaffold(
          body: Column(
            children: [
              _AnalyticsPeriodSelector(
                selectedPeriod: viewModel.period,
                onChanged: (period) => viewModel.load(period: period, forceRefresh: true),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasError
                        ? _DashboardErrorState(
                            error: viewModel.error ?? 'Unknown error',
                            onRetry: () => viewModel.load(forceRefresh: true),
                          )
                        : report == null
                            ? const SizedBox.shrink()
                            : RefreshIndicator(
                                onRefresh: () => viewModel.load(forceRefresh: true),
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _AnalyticsSummaryCards(report: report),
                                      const SizedBox(height: 24),
                                      _BookingTrendsChart(report: report),
                                      const SizedBox(height: 24),
                                      _RoomUtilizationChart(report: report),
                                      const SizedBox(height: 24),
                                      _PeakHoursHeatmap(report: report),
                                      const SizedBox(height: 24),
                                      _DepartmentDistributionChart(report: report),
                                      const SizedBox(height: 24),
                                      _TopPerformersCard(
                                        title: 'Top 5 Most Booked Rooms',
                                        performers: report.topRooms,
                                        accentColor: Colors.blue,
                                      ),
                                      const SizedBox(height: 24),
                                      _TopPerformersCard(
                                        title: 'Top 5 Most Active Users',
                                        performers: report.topUsers,
                                        accentColor: Colors.green,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsPeriodSelector extends StatelessWidget {
  const _AnalyticsPeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final AdminAnalyticsPeriod selectedPeriod;
  final ValueChanged<AdminAnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <AdminAnalyticsPeriod, String>{
      AdminAnalyticsPeriod.sevenDays: 'Last 7 days',
      AdminAnalyticsPeriod.thirtyDays: 'Last 30 days',
      AdminAnalyticsPeriod.threeMonths: 'Last 3 months',
      AdminAnalyticsPeriod.sixMonths: 'Last 6 months',
      AdminAnalyticsPeriod.oneYear: 'Last 12 months',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timeline),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<AdminAnalyticsPeriod>(
              value: selectedPeriod,
              items: options.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Analytics window',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummaryCards extends StatelessWidget {
  const _AnalyticsSummaryCards({required this.report});

  final AdminAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _resolveCardWidth(constraints.maxWidth);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Total Bookings',
                value: report.totalBookings.toString(),
                icon: Icons.event_available,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Rooms Tracked',
                value: report.totalRooms.toString(),
                icon: Icons.meeting_room,
                color: Colors.purple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Active Users',
                value: report.totalUsers.toString(),
                icon: Icons.people_alt,
                color: Colors.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  double _resolveCardWidth(double maxWidth) {
    if (maxWidth <= 360) {
      return maxWidth;
    }
    final columns = math.max(1, math.min(3, (maxWidth / 260).floor()));
    final totalSpacing = 16.0 * (columns - 1);
    return (maxWidth - totalSpacing) / columns;
  }
}

class _BookingTrendsChart extends StatelessWidget {
  const _BookingTrendsChart({required this.report});

  final AdminAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final entries = report.bookingTrends.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return const _EmptyChart('No booking data available');
    }

    final spots = entries
        .map(
          (entry) => FlSpot(
            entry.key.millisecondsSinceEpoch.toDouble(),
            entry.value.toDouble(),
          ),
        )
        .toList();

    final dateFormatter = MaterialLocalizations.of(context);

    return _ChartCard(
      title: 'Booking Trends',
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: spots.length > 6
                    ? (spots.length / 6).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, meta) {
                  final date =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}\n${dateFormatter.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: false)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomUtilizationChart extends StatelessWidget {
  const _RoomUtilizationChart({required this.report});

  final AdminAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final entries = report.roomUtilization.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const _EmptyChart('No room utilization data available');
    }

    return _ChartCard(
      title: 'Room Utilization (%)',
      child: SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 100,
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 42),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final label = entries[index].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        label.length > 10 ? '${label.substring(0, 10)}…' : label,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: entries.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value.clamp(0, 100),
                    color: Colors.green,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _PeakHoursHeatmap extends StatelessWidget {
  const _PeakHoursHeatmap({required this.report});

  final AdminAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final peakHours = report.peakHours;
    if (peakHours.isEmpty) {
      return const _EmptyChart('No peak hours data available');
    }

    final maxBookings = peakHours.reduce(math.max).clamp(1, double.infinity).toDouble();

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
          final color = Color.lerp(Colors.green[200], Colors.red[600], intensity);
          final textColor = intensity > 0.5 ? Colors.white : Colors.black87;
          return Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$index:00', style: TextStyle(fontSize: 10, color: textColor)),
                const SizedBox(height: 4),
                Text(
                  '${peakHours[index]}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DepartmentDistributionChart extends StatelessWidget {
  const _DepartmentDistributionChart({required this.report});

  final AdminAnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final data = report.departmentUsage;
    if (data.isEmpty) {
      return const _EmptyChart('No department distribution data available');
    }

    final total = data.values.fold<int>(0, (previousValue, element) => previousValue + element);
    final palette = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.indigo,
    ];

    return _ChartCard(
      title: 'Department Usage Distribution',
      child: SizedBox(
        height: 320,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: data.entries.toList().asMap().entries.map((entry) {
              final color = palette[entry.key % palette.length];
              final percentage = (entry.value.value / total * 100).toStringAsFixed(1);
              return PieChartSectionData(
                value: entry.value.value.toDouble(),
                color: color,
                title: '${entry.value.key}\n$percentage%',
                radius: 80,
                titleStyle: const TextStyle(fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TopPerformersCard extends StatelessWidget {
  const _TopPerformersCard({
    required this.title,
    required this.performers,
    required this.accentColor,
  });

  final String title;
  final List<AdminTopPerformer> performers;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (performers.isEmpty) {
      return _EmptyChart('No data available for $title');
    }

    return _ChartCard(
      title: title,
      child: Column(
        children: performers.asMap().entries.map((entry) {
          final performer = entry.value;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: accentColor,
              child: Text('${entry.key + 1}'),
            ),
            title: Text(performer.label.isEmpty ? performer.id : performer.label),
            subtitle: Text('ID: ${performer.id}'),
            trailing: Text('${performer.count} bookings'),
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
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
    return _ChartCard(
      title: 'Insufficient Data',
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Unable to load analytics',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
