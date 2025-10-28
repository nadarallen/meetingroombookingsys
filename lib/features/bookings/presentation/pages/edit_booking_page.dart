import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/booking.dart' as db;
import '../../../../core/database/models/room.dart';
import '../viewmodels/booking_view_model.dart';

class EditBookingPage extends StatefulWidget {
  const EditBookingPage({super.key, required this.booking});

  final db.Booking booking;

  @override
  State<EditBookingPage> createState() => _EditBookingPageState();
}

class _EditBookingPageState extends State<EditBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  List<Room> _rooms = <Room>[];
  Room? _selectedRoom;
  DateTime? _start;
  DateTime? _end;
  bool _loadingRooms = true;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    Future.microtask(_loadRooms);
  }

  void _initializeForm() {
    _titleController.text = widget.booking.title ?? '';
    _notesController.text = widget.booking.notes ?? '';
    _start = widget.booking.startTime;
    _end = widget.booking.endTime;
  }

  Future<void> _loadRooms() async {
    final db = context.read<LocalDatabase>();
    final rooms = await db.getRooms();
    final bookingRoom = rooms.firstWhere(
      (room) => room.id == widget.booking.roomId,
      orElse: () =>
          rooms.isNotEmpty ? rooms.first : throw Exception('Room not found'),
    );

    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _selectedRoom = bookingRoom;
      _loadingRooms = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Booking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context),
            tooltip: 'Delete booking',
          ),
        ],
      ),
      body: _loadingRooms
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(child: Text('No rooms available.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Booking Status Card
                        Card(
                          color: _getStatusColor(widget.booking.status),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  _getStatusIcon(widget.booking.status),
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Status: ${widget.booking.status.name.toUpperCase()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Sync: ${widget.booking.syncStatus.toString().toUpperCase()}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Room Selection
                        DropdownButtonFormField<Room>(
                          initialValue: _selectedRoom,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.meeting_room),
                          ),
                          items: _rooms
                              .map(
                                (room) => DropdownMenuItem<Room>(
                                  value: room,
                                  child: Text(
                                      '${room.name} • Capacity ${room.capacity}'),
                                ),
                              )
                              .toList(),
                          onChanged: (room) =>
                              setState(() => _selectedRoom = room),
                          validator: (value) =>
                              value == null ? 'Select a room' : null,
                        ),
                        const SizedBox(height: 16),

                        // Title Field
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Provide a title'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Start Time
                        _DateTimeField(
                          label: 'Start Time',
                          value: _start,
                          onTap: () async {
                            final picked = await _pickDateTime(
                                context, _start ?? DateTime.now());
                            if (picked != null) {
                              setState(() {
                                _start = picked;
                                if (_end == null || !_end!.isAfter(picked)) {
                                  _end = picked.add(const Duration(hours: 1));
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // End Time
                        _DateTimeField(
                          label: 'End Time',
                          value: _end,
                          onTap: () async {
                            final picked = await _pickDateTime(
                                context, _end ?? (_start ?? DateTime.now()));
                            if (picked != null) {
                              setState(() => _end = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Notes Field
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.cancel),
                                label: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _submit(context),
                                icon: const Icon(Icons.save),
                                label: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final room = _selectedRoom;
    final start = _start;
    final end = _end;
    if (room == null || start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final vm = context.read<BookingViewModel>();
    final success = await vm.updateBooking(
      bookingId: widget.booking.id,
      roomId: room.id,
      start: start,
      end: end,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!context.mounted) return;

    if (success) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Booking updated successfully.')));
      navigator.pop(true);
    } else {
      final message = vm.error ?? 'Unable to update booking.';
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
      vm.clearError();
    }
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text(
            'Are you sure you want to delete this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vm = context.read<BookingViewModel>();
      final success = await vm.cancelBooking(widget.booking.id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully.')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.error ?? 'Unable to cancel booking.')),
          );
          vm.clearError();
        }
      }
    }
  }

  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!context.mounted) return null;
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Color _getStatusColor(db.BookingStatus status) {
    switch (status) {
      case db.BookingStatus.pending:
        return Colors.orange;
      case db.BookingStatus.confirmed:
        return Colors.green;
      case db.BookingStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(db.BookingStatus status) {
    switch (status) {
      case db.BookingStatus.pending:
        return Icons.schedule;
      case db.BookingStatus.confirmed:
        return Icons.check_circle;
      case db.BookingStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.schedule),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          value == null ? 'Select $label'.toLowerCase() : _formatDate(value!),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
