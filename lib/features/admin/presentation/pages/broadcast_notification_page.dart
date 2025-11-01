import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../shared/services/notification_service.dart';
import '../../domain/entities/broadcast_targets.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/get_broadcast_targets.dart';
import '../../domain/usecases/save_admin_broadcast.dart';
import '../viewmodels/broadcast_notification_view_model.dart';

class BroadcastNotificationPage extends StatefulWidget {
  const BroadcastNotificationPage({super.key});

  @override
  State<BroadcastNotificationPage> createState() =>
      _BroadcastNotificationPageState();
}

class _BroadcastNotificationPageState extends State<BroadcastNotificationPage> {
  final _messageController = TextEditingController();
  final _titleController = TextEditingController();
  BroadcastAudience _audience = BroadcastAudience.all;
  String? _selectedDepartment;
  DateTime? _scheduledTime;
  bool _isScheduled = false;

  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AdminRepository>();

    return ChangeNotifierProvider(
      create: (_) => BroadcastNotificationViewModel(
        getBroadcastTargets: GetBroadcastTargets(repository),
        saveAdminBroadcast: SaveAdminBroadcast(repository),
      )..loadTargets(),
      child: Consumer<BroadcastNotificationViewModel>(
        builder: (context, viewModel, _) {
          final auth = context.watch<AuthViewModel>();
          final targets = viewModel.targets;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Broadcast Notification'),
              actions: [
                IconButton(
                  onPressed: viewModel.isSending
                      ? null
                      : () => _onSend(context, viewModel, auth),
                  icon: viewModel.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
            body: viewModel.isLoadingTargets && targets == null
                ? const Center(child: CircularProgressIndicator())
                : targets == null
                    ? _BroadcastErrorState(
                        error: viewModel.error ?? 'Unable to load user segments',
                        onRetry: viewModel.loadTargets,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTargetSelection(viewModel, targets),
                            const SizedBox(height: 24),
                            _buildMessageForm(),
                            const SizedBox(height: 24),
                            _buildSchedulingOptions(context),
                            const SizedBox(height: 24),
                            _buildPreview(viewModel, targets),
                          ],
                        ),
                      ),
          );
        },
      ),
    );
  }

  Future<void> _onSend(
    BuildContext context,
    BroadcastNotificationViewModel viewModel,
    AuthViewModel auth,
  ) async {
    if (_audience == BroadcastAudience.department &&
        (_selectedDepartment == null || _selectedDepartment!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department to target.')),
      );
      return;
    }

    try {
      await viewModel.sendBroadcast(
        authViewModel: auth,
        notificationService: NotificationService.instance,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        audience: _audience,
        department: _audience == BroadcastAudience.department
            ? _selectedDepartment
            : null,
        scheduledAt: _isScheduled ? _scheduledTime : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isScheduled
                ? 'Broadcast scheduled successfully'
                : 'Broadcast sent successfully',
          ),
        ),
      );
      _messageController.clear();
      _titleController.clear();
      setState(() {
        _audience = BroadcastAudience.all;
        _selectedDepartment = null;
        _isScheduled = false;
        _scheduledTime = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send broadcast: $error')),
      );
    }
  }

  Widget _buildTargetSelection(
    BroadcastNotificationViewModel viewModel,
    BroadcastTargets targets,
  ) {
    final departments = targets.departments;
    if (departments.isNotEmpty) {
      _selectedDepartment ??= departments.first;
    } else {
      _selectedDepartment = null;
    }

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
            RadioListTile<BroadcastAudience>(
              title: const Text('All Users'),
              subtitle: Text('${targets.activeUsers} active users'),
              value: BroadcastAudience.all,
              groupValue: _audience,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _audience = value);
                }
              },
            ),
            RadioListTile<BroadcastAudience>(
              title: const Text('Specific Department'),
              subtitle: Text(
                departments.isEmpty
                    ? 'No departments available'
                    : '${viewModel.audienceCount(BroadcastAudience.department, department: _selectedDepartment)} users',
              ),
              value: BroadcastAudience.department,
              groupValue: _audience,
              onChanged: departments.isEmpty
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _audience = value);
                      }
                    },
            ),
            if (_audience == BroadcastAudience.department)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  items: departments
                      .map(
                        (dept) => DropdownMenuItem(
                          value: dept,
                          child: Text(dept),
                        ),
                      )
                      .toList(),
                  onChanged: departments.isEmpty
                      ? null
                      : (value) {
                          setState(() => _selectedDepartment = value);
                        },
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            RadioListTile<BroadcastAudience>(
              title: const Text('Admins Only'),
              subtitle: Text('${targets.activeAdmins} admin users'),
              value: BroadcastAudience.admin,
              groupValue: _audience,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _audience = value);
                }
              },
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
                hintText: 'Write your announcement',
              ),
              maxLines: 6,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingOptions(BuildContext context) {
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
              subtitle: const Text('Send at a specific date and time'),
              value: _isScheduled,
              onChanged: (value) {
                setState(() {
                  _isScheduled = value;
                  if (!value) {
                    _scheduledTime = null;
                  }
                });
              },
            ),
            if (_isScheduled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _scheduledTime == null
                      ? 'Select date and time'
                      : _scheduledTime!.toLocal().toString(),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 180)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time == null) return;

                    setState(() {
                      _scheduledTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                  child: const Text('Select'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(
    BroadcastNotificationViewModel viewModel,
    BroadcastTargets targets,
  ) {
    final audienceDescription = () {
      switch (_audience) {
        case BroadcastAudience.all:
          return '${targets.activeUsers} active users';
        case BroadcastAudience.department:
          final department = _selectedDepartment;
          if (department == null) {
            return 'No departments available';
          }
          final count = viewModel.audienceCount(
            BroadcastAudience.department,
            department: department,
          );
          return '$count users in $department';
        case BroadcastAudience.admin:
          return '${targets.activeAdmins} admins';
      }
    }();

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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group),
              title: const Text('Audience'),
              subtitle: Text(audienceDescription),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.title),
              title: const Text('Title'),
              subtitle: Text(
                _titleController.text.isEmpty
                    ? 'No title yet'
                    : _titleController.text,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.message),
              title: const Text('Message'),
              subtitle: Text(
                _messageController.text.isEmpty
                    ? 'Your message preview will appear here'
                    : _messageController.text,
              ),
            ),
            if (_isScheduled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_send),
                title: const Text('Scheduled'),
                subtitle: Text(
                  _scheduledTime == null
                      ? 'No time selected'
                      : MaterialLocalizations.of(context)
                          .formatFullDate(_scheduledTime!) +
                          ' · ' +
                          MaterialLocalizations.of(context)
                              .formatTimeOfDay(
                                TimeOfDay.fromDateTime(_scheduledTime!),
                              ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastErrorState extends StatelessWidget {
  const _BroadcastErrorState({required this.error, required this.onRetry});

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
              'Unable to load recipients',
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
