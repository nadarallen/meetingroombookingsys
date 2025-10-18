import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/room_list_view_model.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoomListViewModel>(
      create: (_) => RoomListViewModel(
        localDatabase: context.read<LocalDatabase>(),
        syncManager: context.read<DatabaseSyncManager>(),
      )..load(),
      child: const _RoomListView(),
    );
  }
}

class _RoomListView extends StatelessWidget {
  const _RoomListView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomListViewModel>();
    final auth = context.watch<AuthViewModel>();
    final isAdmin = auth.user?.isAdmin ?? false;

    debugPrint(
        'RoomListPage - User: ${auth.user?.email}, isAdmin: $isAdmin, rooms: ${vm.rooms.length}');

    if (vm.loading) return const AppLoading(message: 'Loading rooms...');
    if (vm.error != null)
      return AppError(message: vm.error!, onRetry: vm.refresh);

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Rooms')),
      body: ListView.separated(
        itemCount: vm.rooms.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final room = vm.rooms[index];
          final deleting = vm.isDeleting(room.id);
          return ListTile(
            title: Text(room.name),
            subtitle: Text('Capacity: ${room.capacity}'),
            leading: const Icon(Icons.meeting_room_outlined),
            trailing: isAdmin
                ? deleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'Delete room',
                        onPressed: () => _confirmDelete(context, room),
                        icon: const Icon(Icons.delete_outline),
                        color: Theme.of(context).colorScheme.error,
                      )
                : null,
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: vm.creating ? null : () => _showAddRoomDialog(context),
              icon: vm.creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(vm.creating ? 'Saving...' : 'Add Room'),
            )
          : null,
    );
  }

  Future<void> _showAddRoomDialog(BuildContext context) async {
    final vm = context.read<RoomListViewModel>();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) => _AddRoomDialog(vm: vm),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room added successfully.')),
      );
    }
  }
}

class _AddRoomDialog extends StatefulWidget {
  const _AddRoomDialog({required this.vm});

  final RoomListViewModel vm;

  @override
  State<_AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<_AddRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Room'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Room name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Capacity is required';
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0)
                    return 'Enter a valid capacity';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Location is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
                minLines: 2,
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    debugPrint('_submit() called');
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    debugPrint(
        'Calling createRoom with: name=${_nameController.text}, capacity=${_capacityController.text}, location=${_locationController.text}');

    final error = await widget.vm.createRoom(
      name: _nameController.text,
      capacity: int.parse(_capacityController.text.trim()),
      location: _locationController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );

    debugPrint('createRoom result: error=$error');

    if (!mounted) return;

    if (error == null) {
      // Success - close dialog and return true
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Error - stay in dialog and show error
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }
}

Future<void> _confirmDelete(BuildContext context, Room room) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete room'),
      content: Text(
        'Are you sure you want to delete "${room.name}"? '
        'All local data for this room, including bookings, will be removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final vm = context.read<RoomListViewModel>();
  final error = await vm.deleteRoom(room.id);

  if (!context.mounted) return;

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${room.name}.')),
    );
  }
}
