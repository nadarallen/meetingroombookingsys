import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/app_user.dart';
import '../../../../core/database/database_sync_manager.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  String _selectedRole = 'All';
  bool _showInactiveOnly = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final localDatabase = context.read<LocalDatabase>();
      final users = await localDatabase.getUsers();
      setState(() {
        _users = users;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user.displayName
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);

        final matchesDepartment = _selectedDepartment == 'All' ||
            user.department == _selectedDepartment;

        final matchesRole =
            _selectedRole == 'All' || user.role == _selectedRole;

        final matchesStatus = !_showInactiveOnly || !user.isActive;

        return matchesSearch &&
            matchesDepartment &&
            matchesRole &&
            matchesStatus;
      }).toList();
    });
  }

  List<String> get _departments {
    final departments = _users
        .map((u) => u.department)
        .where((d) => d != null)
        .cast<String>()
        .toSet()
        .toList();
    departments.sort();
    return ['All', ...departments];
  }

  List<String> get _roles {
    final roles = _users.map((u) => u.role).toSet().toList();
    roles.sort();
    return ['All', ...roles];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No users found'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _UserCard(
                            user: user,
                            onToggleAdmin: () => _toggleAdmin(user),
                            onToggleActive: () => _toggleActive(user),
                            onViewDetails: () => _viewUserDetails(user),
                          );
                        },
                      ),
          ),
        ],
      ),
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
              hintText: 'Search users...',
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
                  value: _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _departments
                      .map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedDepartment = value!);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: _roles
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedRole = value!);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _showInactiveOnly,
                onChanged: (value) {
                  setState(() => _showInactiveOnly = value ?? false);
                  _applyFilters();
                },
              ),
              const Text('Show inactive users only'),
              const Spacer(),
              Text('${_filteredUsers.length} users'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAdmin(AppUser user) async {
    try {
      final syncManager = context.read<DatabaseSyncManager>();
      final updatedUser = user.copyWith(isAdmin: !user.isAdmin);
      await syncManager.upsertUser(updatedUser);
      await _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.displayName ?? user.email} ${updatedUser.isAdmin ? 'granted' : 'revoked'} admin privileges',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user: $e')),
        );
      }
    }
  }

  Future<void> _toggleActive(AppUser user) async {
    try {
      final syncManager = context.read<DatabaseSyncManager>();
      final updatedUser = user.copyWith(isActive: !user.isActive);
      await syncManager.upsertUser(updatedUser);
      await _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.displayName ?? user.email} ${updatedUser.isActive ? 'activated' : 'deactivated'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user: $e')),
        );
      }
    }
  }

  void _viewUserDetails(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailsDialog(user: user),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggleAdmin,
    required this.onToggleActive,
    required this.onViewDetails,
  });

  final AppUser user;
  final VoidCallback onToggleAdmin;
  final VoidCallback onToggleActive;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.blue : Colors.grey,
          child: Text(
            (user.displayName?.isNotEmpty == true
                    ? user.displayName![0]
                    : user.email[0])
                .toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.displayName ?? user.email),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            if (user.department != null) Text('Department: ${user.department}'),
            Row(
              children: [
                Chip(
                  label: Text(user.role),
                  backgroundColor:
                      user.role == 'admin' ? Colors.red[100] : Colors.blue[100],
                ),
                if (user.isAdmin) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('Admin'),
                    backgroundColor: Colors.red,
                    labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
                if (!user.isActive) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('Inactive'),
                    backgroundColor: Colors.grey,
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
              case 'admin':
                onToggleAdmin();
                break;
              case 'active':
                onToggleActive();
                break;
              case 'details':
                onViewDetails();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(
                      user.isAdmin ? Icons.admin_panel_settings : Icons.person),
                  const SizedBox(width: 8),
                  Text(user.isAdmin ? 'Remove Admin' : 'Make Admin'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'active',
              child: Row(
                children: [
                  Icon(user.isActive ? Icons.person_off : Icons.person),
                  const SizedBox(width: 8),
                  Text(user.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDetailsDialog extends StatelessWidget {
  const _UserDetailsDialog({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(user.displayName ?? user.email),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Email', user.email),
          if (user.displayName != null)
            _DetailRow('Display Name', user.displayName!),
          if (user.department != null)
            _DetailRow('Department', user.department!),
          _DetailRow('Role', user.role),
          _DetailRow('Admin', user.isAdmin ? 'Yes' : 'No'),
          _DetailRow('Active', user.isActive ? 'Yes' : 'No'),
          _DetailRow('Created', _formatDate(user.createdAt)),
          _DetailRow('Last Updated', _formatDate(user.updatedAt)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
