import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../viewmodels/booking_view_model.dart';

class NewBookingPage extends StatefulWidget {
  const NewBookingPage({super.key});

  @override
  State<NewBookingPage> createState() => _NewBookingPageState();
}

class _NewBookingPageState extends State<NewBookingPage> {
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
    Future.microtask(_loadRooms);
  }

  Future<void> _loadRooms() async {
    final db = context.read<LocalDatabase>();
    final rooms = await db.getRooms();
    final now = DateTime.now();
    final defaultStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      0,
    ).add(const Duration(hours: 1));

    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _selectedRoom = rooms.isNotEmpty ? rooms.first : null;
      _start = defaultStart;
      _end = defaultStart.add(const Duration(hours: 1));
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
      appBar: AppBar(title: const Text('New Booking')),
      body: _loadingRooms
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(child: Text('Please add rooms before creating bookings.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<Room>(
                          initialValue: _selectedRoom,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            border: OutlineInputBorder(),
                          ),
                          items: _rooms
                              .map(
                                (room) => DropdownMenuItem<Room>(
                                  value: room,
                                  child: Text('${room.name} • Capacity ${room.capacity}'),
                                ),
                              )
                              .toList(),
                          onChanged: (room) => setState(() => _selectedRoom = room),
                          validator: (value) => value == null ? 'Select a room' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Provide a title' : null,
                        ),
                        const SizedBox(height: 16),
                        _DateTimeField(
                          label: 'Start',
                          value: _start,
                          onTap: () async {
                            final picked = await _pickDateTime(context, _start ?? DateTime.now());
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
                        _DateTimeField(
                          label: 'End',
                          value: _end,
                          onTap: () async {
                            final picked =
                                await _pickDateTime(context, _end ?? (_start ?? DateTime.now()));
                            if (picked != null) {
                              setState(() => _end = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _submit(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Create Booking'),
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
    final success = await vm.createBooking(
      roomId: room.id,
      start: start,
      end: end,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (!context.mounted) return;

    if (success) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Booking created.')));
      navigator.pop(true);
    } else {
      final message = vm.error ?? 'Unable to create booking.';
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
      vm.clearError();
    }
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
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
