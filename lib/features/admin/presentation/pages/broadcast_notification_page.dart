import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/app_user.dart';
import '../../../../shared/services/notification_service.dart';

class BroadcastNotificationPage extends StatefulWidget {
  const BroadcastNotificationPage({super.key});

  @override
  State<BroadcastNotificationPage> createState() =>
      _BroadcastNotificationPageState();
}

class _BroadcastNotificationPageState extends State<BroadcastNotificationPage> {
  final _messageController = TextEditingController();
  final _titleController = TextEditingController();
  String _selectedTarget = 'all';
  String _selectedDepartment = 'All';
  DateTime? _scheduledTime;
  bool _isScheduled = false;
  bool _sending = false;

  List<String> _departments = ['All'];
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final localDatabase = context.read<LocalDatabase>();
      final users = await localDatabase.getUsers();
      setState(() {
        _users = users;
        _departments = [
          'All',
          ...users
              .map((u) => u.department)
              .where((d) => d != null)
              .cast<String>()
              .toSet()
              .toList()
        ];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  List<AppUser> get _targetUsers {
    switch (_selectedTarget) {
      case 'all':
        return _users.where((u) => u.isActive).toList();
      case 'department':
        return _users
            .where((u) => u.isActive && u.department == _selectedDepartment)
            .toList();
      case 'admin':
        return _users.where((u) => u.isActive && u.isAdmin).toList();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Notification'),
        actions: [
          IconButton(
            onPressed: _sending ? null : _sendNotification,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTargetSelection(),
            const SizedBox(height: 24),
            _buildMessageForm(),
            const SizedBox(height: 24),
            _buildSchedulingOptions(),
            const SizedBox(height: 24),
            _buildPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Target Audience',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('All Users'),
              subtitle: Text(
                  '${_users.where((u) => u.isActive).length} active users'),
              value: 'all',
              groupValue: _selectedTarget,
              onChanged: (value) => setState(() => _selectedTarget = value!),
            ),
            RadioListTile<String>(
              title: const Text('Specific Department'),
              subtitle: Text('${_targetUsers.length} users'),
              value: 'department',
              groupValue: _selectedTarget,
              onChanged: (value) => setState(() => _selectedTarget = value!),
            ),
            if (_selectedTarget == 'department') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
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
                onChanged: (value) =>
                    setState(() => _selectedDepartment = value!),
              ),
            ],
            RadioListTile<String>(
              title: const Text('Admins Only'),
              subtitle: Text(
                  '${_users.where((u) => u.isActive && u.isAdmin).length} admin users'),
              value: 'admin',
              groupValue: _selectedTarget,
              onChanged: (value) => setState(() => _selectedTarget = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message Content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                hintText: 'Enter notification title',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Enter your message here...',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 500,
            ),
            const SizedBox(height: 8),
            Text(
              '${_messageController.text.length}/500 characters',
              style: TextStyle(
                color: _messageController.text.length > 500
                    ? Colors.red
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scheduling',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Schedule for later'),
              subtitle: const Text('Send notification at a specific time'),
              value: _isScheduled,
              onChanged: (value) => setState(() => _isScheduled = value),
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(_scheduledTime != null
                    ? 'Scheduled for ${_formatDateTime(_scheduledTime!)}'
                    : 'Select date and time'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectScheduledTime,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text.isEmpty
                        ? 'Notification Title'
                        : _titleController.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _messageController.text.isEmpty
                        ? 'Your message will appear here...'
                        : _messageController.text,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To: ${_getTargetDescription()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_isScheduled && _scheduledTime != null)
                    Text(
                      'Scheduled: ${_formatDateTime(_scheduledTime!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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

  String _getTargetDescription() {
    switch (_selectedTarget) {
      case 'all':
        return 'All Users (${_users.where((u) => u.isActive).length})';
      case 'department':
        return '${_selectedDepartment} Department (${_targetUsers.length})';
      case 'admin':
        return 'Admins Only (${_users.where((u) => u.isActive && u.isAdmin).length})';
      default:
        return 'Unknown';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectScheduledTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _scheduledTime != null
            ? TimeOfDay.fromDateTime(_scheduledTime!)
            : TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    if (_isScheduled && _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scheduled time')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final notificationService = NotificationService.instance;

      if (_isScheduled && _scheduledTime != null) {
        // Schedule notification for later
        await _scheduleNotification(notificationService);
      } else {
        // Send immediately
        await _sendImmediateNotification(notificationService);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isScheduled
                  ? 'Notification scheduled successfully'
                  : 'Notification sent successfully',
            ),
          ),
        );

        // Clear form
        _titleController.clear();
        _messageController.clear();
        setState(() {
          _isScheduled = false;
          _scheduledTime = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending notification: $e')),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendImmediateNotification(
      NotificationService notificationService) async {
    // In a real implementation, you would:
    // 1. Get FCM tokens for target users
    // 2. Send push notifications via FCM
    // 3. Store notification in database for history

    // For now, we'll simulate the notification
    await Future.delayed(const Duration(seconds: 1));

    // Simulate sending to each target user
    for (final user in _targetUsers) {
      // In real implementation: await notificationService.sendToUser(user.id, ...)
      debugPrint('Sending notification to ${user.email}');
    }
  }

  Future<void> _scheduleNotification(
      NotificationService notificationService) async {
    // In a real implementation, you would:
    // 1. Store scheduled notification in database
    // 2. Use Cloud Functions or local scheduling to send at the specified time

    // For now, we'll just simulate scheduling
    await Future.delayed(const Duration(seconds: 1));
    debugPrint(
        'Scheduled notification for ${_formatDateTime(_scheduledTime!)}');
  }
}
