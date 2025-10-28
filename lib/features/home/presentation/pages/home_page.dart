import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../../../../core/theme/theme_notifier.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../ml/services/recommendation_service.dart';

enum _HomeMenu { profile, logout }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            user != null ? 'Welcome, ${user.fullName}' : AppStrings.appName),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => context.read<ThemeNotifier>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          PopupMenuButton<_HomeMenu>(
            onSelected: (value) => _handleMenu(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _HomeMenu.profile,
                child: Text('Profile'),
              ),
              PopupMenuItem(
                value: _HomeMenu.logout,
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null) ...[
            _RecommendedRoomsSection(userId: user.uid),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildMainSlide(context, user),
                _buildBookingSlide(context),
                _buildAdminSlide(context, user),
              ],
            ),
          ),
          _buildPageIndicator(context),
        ],
      ),
    );
  }

  Widget _buildMainSlide(BuildContext context, user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context: context,
            icon: Icons.meeting_room_outlined,
            title: AppStrings.rooms,
            subtitle: 'View and manage meeting rooms',
            color: Colors.blue,
            onTap: () => context.go('/rooms'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.map_outlined,
            title: 'Rooms Map',
            subtitle: 'Browse rooms on Google Maps',
            color: Colors.green,
            onTap: () => context.go('/rooms/map'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.chat_bubble_outline,
            title: 'AI Concierge',
            subtitle: 'Ask about rooms, bookings, and policies',
            color: Colors.purple,
            onTap: () => context.go('/chat'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Review and edit your information',
            color: Colors.orange,
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSlide(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context: context,
            icon: Icons.event_note_outlined,
            title: AppStrings.bookings,
            subtitle: 'View all your bookings',
            color: Colors.blue,
            onTap: () => context.go('/bookings'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.add_circle_outline,
            title: 'New Booking',
            subtitle: 'Create a new room booking',
            color: Colors.green,
            onTap: () => context.go('/bookings/new'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.schedule,
            title: 'Upcoming',
            subtitle: 'View your upcoming meetings',
            color: Colors.orange,
            onTap: () => context.go('/bookings?filter=upcoming'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.history,
            title: 'Booking History',
            subtitle: 'View past bookings',
            color: Colors.grey,
            onTap: () => context.go('/bookings?filter=history'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSlide(BuildContext context, user) {
    if (user?.isAdmin != true) {
      return const Center(
        child: Text('Admin features not available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Panel',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context: context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            subtitle: 'View system analytics and reports',
            color: Colors.blue,
            onTap: () => context.go('/admin'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.people,
            title: 'User Management',
            subtitle: 'Manage users and permissions',
            color: Colors.green,
            onTap: () => context.go('/admin/users'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.settings,
            title: 'System Settings',
            subtitle: 'Configure system preferences',
            color: Colors.orange,
            onTap: () => context.go('/admin/settings'),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.analytics,
            title: 'Analytics',
            subtitle: 'View usage statistics and reports',
            color: Colors.purple,
            onTap: () => context.go('/admin/analytics'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDot(0),
          const SizedBox(width: 8),
          _buildDot(1),
          const SizedBox(width: 8),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _currentPage == index ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: _currentPage == index ? Colors.blue : Colors.grey[300],
        ),
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, _HomeMenu selection) async {
    switch (selection) {
      case _HomeMenu.profile:
        if (context.mounted) context.go('/profile');
        break;
      case _HomeMenu.logout:
        final auth = context.read<AuthViewModel>();
        await auth.logout();
        if (!context.mounted) return;
        final message = auth.errorMessage ?? auth.infoMessage;
        if (message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
          auth.clearMessages();
        }
        break;
    }
  }
}

/// Widget that displays recommended rooms based on ML analysis
class _RecommendedRoomsSection extends StatefulWidget {
  const _RecommendedRoomsSection({required this.userId});

  final String userId;

  @override
  State<_RecommendedRoomsSection> createState() =>
      _RecommendedRoomsSectionState();
}

class _RecommendedRoomsSectionState extends State<_RecommendedRoomsSection> {
  bool _loading = false;
  List<RoomScore> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _loading = true);
    try {
      final localDatabase = context.read<LocalDatabase>();
      final service = RecommendationService(localDatabase: localDatabase);
      final recommendations = await service.getRecommendedRooms(widget.userId);

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ..._recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final recommendation = entry.value;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, index == _recommendations.length - 1 ? 16 : 8),
              child: _RecommendationCard(
                room: recommendation.room,
                score: recommendation.score,
                reasons: recommendation.reasons,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.room,
    required this.score,
    required this.reasons,
  });

  final Room room;
  final double score;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getScoreColor(score),
          child: Text(
            (score / 10).ceil().toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(room.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reasons.isNotEmpty) ...[
              Text(
                reasons.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${room.capacity} capacity',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () {
          // Navigate to room details or map
          context.go('/rooms');
        },
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
