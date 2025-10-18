import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/theme_notifier.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

enum _HomeMenu { profile, logout }

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? 'Welcome, ${user.fullName}' : AppStrings.appName),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: const Text(AppStrings.rooms),
              subtitle: const Text('View and manage meeting rooms'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/rooms'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text(AppStrings.bookings),
              subtitle: const Text('Browse and create bookings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/bookings'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              subtitle: const Text('Review and edit your information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/profile'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Manage meeting spaces, schedule bookings, and stay on top of your workspace logistics.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          auth.clearMessages();
        }
        break;
    }
  }
}
