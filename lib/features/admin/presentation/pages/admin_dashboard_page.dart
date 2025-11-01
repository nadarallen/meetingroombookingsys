import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../../../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/entities/admin_dashboard_metrics.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/get_admin_dashboard_metrics.dart';
import '../viewmodels/admin_dashboard_view_model.dart';
import 'admin_analytics_page.dart';
import 'user_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user;

    // Check if user is admin
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You need admin privileges to access this page.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final adminRepository = context.read<AdminRepository>();

    return ChangeNotifierProvider(
      create: (_) => AdminDashboardViewModel(
        getAdminDashboardMetrics:
            GetAdminDashboardMetrics(adminRepository),
      )..load(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.meeting_room), text: 'Rooms'),
              Tab(icon: Icon(Icons.event_note), text: 'Bookings'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(onNavigateToTab: _tabController.animateTo),
            _RoomsTab(),
            _BookingsTab(),
            const UserManagementPage(),
            const AdminAnalyticsPage(),
            _SettingsTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminDashboardViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.metrics == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.error != null && viewModel.metrics == null) {
          return _DashboardErrorState(
            error: viewModel.error!,
            onRetry: () => viewModel.load(forceRefresh: true),
          );
        }

        final metrics = viewModel.metrics;
        if (metrics == null) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          onRefresh: () => viewModel.load(forceRefresh: true),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'System Overview',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (viewModel.lastUpdated != null)
                          Text(
                            'Updated ${_formatTimestamp(context, viewModel.lastUpdated!)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _MetricsWrap(
                      metrics: metrics,
                      maxWidth: constraints.maxWidth,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Quick Actions',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _QuickActions(onNavigateToTab: onNavigateToTab),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String _formatTimestamp(BuildContext context, DateTime dateTime) {
    final now = DateTime.now();
    if (now.difference(dateTime).inMinutes < 1) {
      return 'just now';
    }
    final localizations = MaterialLocalizations.of(context);
    final timeString =
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
    if (now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day) {
      return 'at $timeString';
    }
    return '${dateTime.month}/${dateTime.day} $timeString';
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
              'Something went wrong',
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

class _MetricsWrap extends StatelessWidget {
  const _MetricsWrap({
    required this.metrics,
    required this.maxWidth,
  });

  final AdminDashboardMetrics metrics;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricCard(
        title: "Today's Bookings",
        value: metrics.todaysBookings.toString(),
        icon: Icons.event,
        color: Colors.blue,
      ),
      _MetricCard(
        title: 'This Week',
        value: metrics.weekBookings.toString(),
        icon: Icons.calendar_view_week,
        color: Colors.green,
      ),
      _MetricCard(
        title: 'This Month',
        value: metrics.monthBookings.toString(),
        icon: Icons.calendar_month,
        color: Colors.orange,
      ),
      _MetricCard(
        title: 'Active Users',
        value: metrics.activeUsers.toString(),
        icon: Icons.people_alt,
        color: Colors.purple,
      ),
      _MetricCard(
        title: 'Room Utilization',
        value: '${metrics.roomUtilization.toStringAsFixed(1)}%',
        icon: Icons.meeting_room,
        color: Colors.teal,
      ),
      _MetricCard(
        title: 'Pending Approvals',
        value: metrics.pendingApprovals.toString(),
        icon: Icons.pending_actions,
        color: Colors.redAccent,
      ),
      _MetricCard(
        title: 'Check-ins Today',
        value: metrics.checkInsToday.toString(),
        icon: Icons.verified_user,
        color: Colors.indigo,
      ),
      _MetricCard(
        title: 'Weekly Cancellations',
        value: metrics.cancellationsThisWeek.toString(),
        icon: Icons.cancel_schedule_send,
        color: Colors.brown,
      ),
      _MetricCard(
        title: 'Queued Broadcasts',
        value: metrics.queuedBroadcasts.toString(),
        icon: Icons.notifications_active,
        color: Colors.deepOrange,
      ),
    ];

    final cardWidth = _resolveCardWidth(maxWidth);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: tiles
          .map(
            (tile) => SizedBox(
              width: cardWidth,
              child: tile,
            ),
          )
          .toList(),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 640;
        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => onNavigateToTab(4),
                icon: const Icon(Icons.analytics),
                label: const Text('View Analytics'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => onNavigateToTab(5),
                icon: const Icon(Icons.notifications_active),
                label: const Text('Broadcast'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onNavigateToTab(4),
                icon: const Icon(Icons.analytics),
                label: const Text('View Analytics'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onNavigateToTab(5),
                icon: const Icon(Icons.notifications_active),
                label: const Text('Broadcast'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomsTab extends StatefulWidget {
  @override
  State<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<_RoomsTab> {
  List<Room> _rooms = [];
  List<Room> _filteredRooms = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  Set<String> _selectedRooms = {};

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      final localDatabase = context.read<LocalDatabase>();
      final rooms = await localDatabase.getRooms();
      setState(() {
        _rooms = rooms;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rooms: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRooms = _rooms.where((room) {
        final matchesSearch = _searchQuery.isEmpty ||
            room.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (room.location
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);

        final matchesStatus = _selectedStatus == 'All' ||
            (_selectedStatus == 'Active' && room.isActive) ||
            (_selectedStatus == 'Inactive' && !room.isActive);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        if (_selectedRooms.isNotEmpty) _buildBulkActions(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredRooms.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.meeting_room_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No rooms found'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredRooms.length,
                      itemBuilder: (context, index) {
                        final room = _filteredRooms[index];
                        return _RoomCard(
                          room: room,
                          isSelected: _selectedRooms.contains(room.id),
                          onToggleSelection: () =>
                              _toggleRoomSelection(room.id),
                          onToggleActive: () => _toggleRoomActive(room),
                          onViewStats: () => _viewRoomStats(room),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
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
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search rooms...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['All', 'Active', 'Inactive']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Text('${_filteredRooms.length} rooms'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Row(
        children: [
          Text('${_selectedRooms.length} selected'),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectedRooms.isNotEmpty ? _activateSelected : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Activate'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _selectedRooms.isNotEmpty ? _deactivateSelected : null,
            icon: const Icon(Icons.cancel),
            label: const Text('Deactivate'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _selectedRooms.isNotEmpty ? _clearSelection : null,
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _toggleRoomSelection(String roomId) {
    setState(() {
      if (_selectedRooms.contains(roomId)) {
        _selectedRooms.remove(roomId);
      } else {
        _selectedRooms.add(roomId);
      }
    });
  }

  Future<void> _toggleRoomActive(Room room) async {
    try {
      final syncManager = context.read<DatabaseSyncManager>();
      final updatedRoom = room.copyWith(isActive: !room.isActive);
      await syncManager.upsertRoom(updatedRoom);
      await _loadRooms();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${room.name} ${updatedRoom.isActive ? 'activated' : 'deactivated'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating room: $e')),
        );
      }
    }
  }

  void _viewRoomStats(Room room) {
    showDialog(
      context: context,
      builder: (context) => _RoomStatsDialog(room: room),
    );
  }

  Future<void> _activateSelected() async {
    await _bulkUpdateStatus(true);
  }

  Future<void> _deactivateSelected() async {
    await _bulkUpdateStatus(false);
  }

  Future<void> _bulkUpdateStatus(bool isActive) async {
    try {
      final syncManager = context.read<DatabaseSyncManager>();
      for (final roomId in _selectedRooms) {
        final room = _rooms.firstWhere((r) => r.id == roomId);
        final updatedRoom = room.copyWith(isActive: isActive);
        await syncManager.upsertRoom(updatedRoom);
      }
      await _loadRooms();
      setState(() => _selectedRooms.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedRooms.length} rooms ${isActive ? 'activated' : 'deactivated'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating rooms: $e')),
        );
      }
    }
  }

  void _clearSelection() {
    setState(() => _selectedRooms.clear());
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onToggleActive,
    required this.onViewStats,
  });

  final Room room;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onToggleActive;
  final VoidCallback onViewStats;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => onToggleSelection(),
        ),
        title: Text(room.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (room.location.isNotEmpty) Text('Location: ${room.location}'),
            Text('Capacity: ${room.capacity}'),
            Row(
              children: [
                Chip(
                  label: Text(room.isActive ? 'Active' : 'Inactive'),
                  backgroundColor:
                      room.isActive ? Colors.green[100] : Colors.red[100],
                ),
                if (room.latitude != null && room.longitude != null) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('Mapped'),
                    backgroundColor: Colors.blue,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'active':
                onToggleActive();
                break;
              case 'stats':
                onViewStats();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(room.isActive ? Icons.cancel : Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(room.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'stats',
              child: Row(
                children: [
                  Icon(Icons.analytics),
                  SizedBox(width: 8),
                  Text('View Stats'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomStatsDialog extends StatelessWidget {
  const _RoomStatsDialog({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${room.name} Statistics'),
      content: FutureBuilder<Map<String, dynamic>>(
        future: _getRoomStats(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          final stats = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow('Total Bookings', '${stats['totalBookings']}'),
              _StatRow('This Month', '${stats['monthBookings']}'),
              _StatRow('Utilization Rate', '${stats['utilizationRate']}%'),
              _StatRow('Average Duration', '${stats['avgDuration']} min'),
              _StatRow('Peak Hour', '${stats['peakHour']}:00'),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getRoomStats(BuildContext context) async {
    final localDatabase = context.read<LocalDatabase>();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final allBookings = await localDatabase.getBookings();
    final roomBookings = allBookings.where((b) => b.roomId == room.id).toList();
    final monthBookings =
        roomBookings.where((b) => b.startTime.isAfter(monthStart)).length;

    final totalDuration = roomBookings.fold(
        0, (sum, b) => sum + b.endTime.difference(b.startTime).inMinutes);
    final avgDuration = roomBookings.isNotEmpty
        ? (totalDuration / roomBookings.length).round()
        : 0;

    // Calculate peak hour
    final hourCounts = List.generate(24, (hour) => 0);
    for (final booking in roomBookings) {
      hourCounts[booking.startTime.hour]++;
    }
    final peakHour =
        hourCounts.indexOf(hourCounts.reduce((a, b) => a > b ? a : b));

    // Calculate utilization (simplified)
    final daysInMonth = now.day;
    final utilizationRate =
        daysInMonth > 0 ? (monthBookings / daysInMonth * 100).round() : 0;

    return {
      'totalBookings': roomBookings.length,
      'monthBookings': monthBookings,
      'utilizationRate': utilizationRate,
      'avgDuration': avgDuration,
      'peakHour': peakHour,
    };
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Booking Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Advanced booking management features coming soon'),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'System Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('System configuration options coming soon'),
        ],
      ),
    );
  }
}
