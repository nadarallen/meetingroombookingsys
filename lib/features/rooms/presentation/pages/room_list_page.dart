import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../../../../shared/widgets/app_error.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/services/storage_service.dart';
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
        storageService: context.read<StorageService>(),
      )..load(),
      child: const _RoomListView(),
    );
  }
}

class _RoomListView extends StatefulWidget {
  const _RoomListView();

  @override
  State<_RoomListView> createState() => _RoomListViewState();
}

class _RoomListViewState extends State<_RoomListView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // Listen to search controller changes and update view model
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Prevent rebuilds during dispose
    if (!mounted) return;

    final vm = context.read<RoomListViewModel>();
    if (_searchController.text != vm.searchQuery) {
      vm.setSearchQuery(_searchController.text);
    }
  }

  void _syncSearchController(RoomListViewModel vm) {
    // Sync controller text with view model when needed
    if (_searchController.text != vm.searchQuery) {
      _searchController.removeListener(_onSearchChanged);
      _searchController.text = vm.searchQuery;
      _searchController.addListener(_onSearchChanged);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    // The listener will automatically update the view model
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomListViewModel>();
    final auth = context.watch<AuthViewModel>();
    final isAdmin = auth.user?.isAdmin ?? false;

    // Keep search controller in sync with view model
    _syncSearchController(vm);

    debugPrint(
        'RoomListPage - User: ${auth.user?.email}, isAdmin: $isAdmin, rooms: ${vm.rooms.length}');

    if (vm.loading) return const AppLoading(message: 'Loading rooms...');
    if (vm.error != null) {
      return AppError(message: vm.error!, onRetry: vm.refresh);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Rooms'),
        actions: [
          IconButton(
            tooltip: 'View map',
            onPressed: () => context.push('/rooms/map'),
            icon: const Icon(Icons.map_outlined),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) => _handleAdminAction(context, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_sample',
                  child: Row(
                    children: [
                      Icon(Icons.data_object, size: 20),
                      SizedBox(width: 8),
                      Text('Add Sample Rooms'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_db',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear Database',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search rooms by name, location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: vm.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    // TODO: Implement filter functionality
                  },
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter rooms',
                ),
              ],
            ),
          ),
          // Room List
          Expanded(
            child: vm.rooms.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vm.rooms.length,
                    itemBuilder: (context, index) {
                      final room = vm.rooms[index];
                      final deleting = vm.isDeleting(room.id);
                      return _buildRoomCard(context, room, deleting, isAdmin);
                    },
                  ),
          ),
        ],
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _clearDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text(
          'Are you sure you want to clear all local data? This will remove all rooms, bookings, users, and amenities from the local database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Database'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final localDatabase = context.read<LocalDatabase>();

      // Clear all tables
      await localDatabase.clearRooms();
      await localDatabase.clearBookings();
      await localDatabase.clearUsers();
      await localDatabase.clearAmenities();

      // Refresh the room list
      final vm = context.read<RoomListViewModel>();
      await vm.load();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addSampleRooms(BuildContext context) async {
    final vm = context.read<RoomListViewModel>();

    // Sample rooms data - Tech Campus Layout
    final sampleRooms = [
      // Main Building - Conference Rooms
      {
        'name': 'Executive Boardroom',
        'capacity': 20,
        'location': 'Main Building - Floor 5',
        'description':
            'Premium executive boardroom with 4K displays, advanced AV system, and city views',
        'imageUrl':
            'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400&h=300&fit=crop',
        'latitude': 37.4220,
        'longitude': -122.0841,
      },
      {
        'name': 'Innovation Hub',
        'capacity': 16,
        'location': 'Main Building - Floor 3',
        'description':
            'Modern conference room with interactive whiteboard and wireless presentation',
        'imageUrl':
            'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=400&h=300&fit=crop',
        'latitude': 37.4218,
        'longitude': -122.0843,
      },
      {
        'name': 'Collaboration Central',
        'capacity': 12,
        'location': 'Main Building - Floor 3',
        'description':
            'Open collaboration space with moveable furniture and multiple screens',
        'imageUrl':
            'https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&h=300&fit=crop',
        'latitude': 37.4216,
        'longitude': -122.0845,
      },

      // Tech Building - Development Areas
      {
        'name': 'Dev Team War Room',
        'capacity': 8,
        'location': 'Tech Building - Floor 2',
        'description':
            'Dedicated development team space with multiple monitors and standing desks',
        'imageUrl':
            'https://images.unsplash.com/photo-1556761175-4b46a572b786?w=400&h=300&fit=crop',
        'latitude': 37.4225,
        'longitude': -122.0835,
      },
      {
        'name': 'Code Review Room',
        'capacity': 6,
        'location': 'Tech Building - Floor 2',
        'description':
            'Intimate space for code reviews and technical discussions',
        'latitude': 37.4227,
        'longitude': -122.0837,
      },
      {
        'name': 'Agile Planning Space',
        'capacity': 10,
        'location': 'Tech Building - Floor 1',
        'description':
            'Scrum and planning room with kanban boards and sticky wall surfaces',
        'imageUrl':
            'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=400&h=300&fit=crop',
        'latitude': 37.4229,
        'longitude': -122.0839,
      },

      // Creative Building - Design Areas
      {
        'name': 'Design Studio Alpha',
        'capacity': 12,
        'location': 'Creative Building - Floor 2',
        'description':
            'Creative workspace with design monitors, drawing tablets, and natural lighting',
        'imageUrl':
            'https://images.unsplash.com/photo-1497366858526-0766cadbe8fa?w=400&h=300&fit=crop',
        'latitude': 37.4215,
        'longitude': -122.0850,
      },
      {
        'name': 'UX Research Lab',
        'capacity': 8,
        'location': 'Creative Building - Floor 1',
        'description':
            'User research facility with recording equipment and observation room',
        'latitude': 37.4213,
        'longitude': -122.0852,
      },

      // Training Center
      {
        'name': 'Main Training Hall',
        'capacity': 40,
        'location': 'Training Center - Ground Floor',
        'description':
            'Large training facility with tiered seating and professional AV setup',
        'imageUrl':
            'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=400&h=300&fit=crop',
        'latitude': 37.4210,
        'longitude': -122.0855,
      },
      {
        'name': 'Workshop Room Beta',
        'capacity': 15,
        'location': 'Training Center - Floor 2',
        'description': 'Hands-on workshop space with workbenches and tools',
        'latitude': 37.4208,
        'longitude': -122.0857,
      },

      // Focus Areas
      {
        'name': 'Zen Focus Pod',
        'capacity': 2,
        'location': 'Main Building - Floor 1',
        'description': 'Quiet meditation and focus space with sound dampening',
        'imageUrl':
            'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=400&h=300&fit=crop',
        'latitude': 37.4222,
        'longitude': -122.0848,
      },
      {
        'name': 'Phone Booth Alpha',
        'capacity': 1,
        'location': 'Main Building - Floor 2',
        'description': 'Private phone booth for confidential calls',
        'latitude': 37.4224,
        'longitude': -122.0846,
      },
    ];

    int successCount = 0;
    int errorCount = 0;

    for (final roomData in sampleRooms) {
      final error = await vm.createRoom(
        name: roomData['name']! as String,
        capacity: roomData['capacity']! as int,
        location: roomData['location']! as String,
        description: roomData['description']! as String,
        imageUrl: roomData['imageUrl'] as String?,
        latitude: (roomData['latitude'] as num?)?.toDouble(),
        longitude: (roomData['longitude'] as num?)?.toDouble(),
      );

      if (error == null) {
        successCount++;
      } else {
        errorCount++;
        debugPrint('Failed to add ${roomData['name']}: $error');
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Added $successCount sample rooms${errorCount > 0 ? ' ($errorCount failed)' : ''}'),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
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

  Future<void> _handleAdminAction(BuildContext context, String action) async {
    switch (action) {
      case 'add_sample':
        await _addSampleRooms(context);
        break;
      case 'clear_db':
        await _clearDatabase(context);
        break;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No rooms available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some rooms to get started',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
      BuildContext context, Room room, bool deleting, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to room details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                        ? Image.network(
                            room.imageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildRoomImagePlaceholder(context);
                            },
                          )
                        : _buildRoomImagePlaceholder(context),
                  ),
                  const SizedBox(width: 16),
                  // Room Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                room.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (isAdmin)
                              PopupMenuButton<String>(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  if (!deleting)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditRoomDialog(context, room);
                                  } else if (value == 'delete') {
                                    _confirmDelete(context, room);
                                  }
                                },
                                child: deleting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.more_vert),
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${room.capacity} people',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                room.location,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (room.description != null &&
                            room.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            room.description!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[700],
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Room Status and Actions
              Row(
                children: [
                  _buildStatusChip(context, room),
                  const Spacer(),
                  if (room.latitude != null && room.longitude != null)
                    IconButton(
                      onPressed: () {
                        // TODO: Open in maps
                      },
                      icon: const Icon(Icons.directions),
                      tooltip: 'Get directions',
                    ),
                  IconButton(
                    onPressed: () {
                      // TODO: Book room
                    },
                    icon: const Icon(Icons.event_available),
                    tooltip: 'Book room',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomImagePlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.meeting_room_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, Room room) {
    // TODO: Implement actual availability checking
    final isAvailable = true; // Placeholder
    final statusColor = isAvailable ? Colors.green : Colors.red;
    final statusText = isAvailable ? 'Available' : 'Occupied';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditRoomDialog(BuildContext context, Room room) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: context.read<RoomListViewModel>(),
        child: _EditRoomDialog(room: room),
      ),
    );
  }
}

class _AddRoomDialog extends StatefulWidget {
  const _AddRoomDialog({required this.vm});

  final RoomListViewModel vm;

  @override
  State<_AddRoomDialog> createState() => _AddRoomDialogState();
}

class _EditRoomDialog extends StatefulWidget {
  const _EditRoomDialog({required this.room});

  final Room room;

  @override
  State<_EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends State<_EditRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _capacityController =
        TextEditingController(text: widget.room.capacity.toString());
    _locationController = TextEditingController(text: widget.room.location);
    _descriptionController =
        TextEditingController(text: widget.room.description ?? '');
    _imageUrlController =
        TextEditingController(text: widget.room.imageUrl ?? '');
    _latitudeController =
        TextEditingController(text: widget.room.latitude?.toString() ?? '');
    _longitudeController =
        TextEditingController(text: widget.room.longitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Room'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Capacity is required';
                  if (int.tryParse(value!) == null || int.parse(value) <= 0) {
                    return 'Enter a valid capacity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Location is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(
                  labelText: 'Latitude (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(
                  labelText: 'Longitude (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateRoom,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final vm = context.read<RoomListViewModel>();
    final error = await vm.updateRoom(
      roomId: widget.room.id,
      name: _nameController.text.trim(),
      capacity: int.parse(_capacityController.text.trim()),
      location: _locationController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      latitude: _latitudeController.text.trim().isEmpty
          ? null
          : double.tryParse(_latitudeController.text.trim()),
      longitude: _longitudeController.text.trim().isEmpty
          ? null
          : double.tryParse(_longitudeController.text.trim()),
    );

    if (!context.mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _AddRoomDialogState extends State<_AddRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _imageStatus;

  static const int _kMaxUploadBytes = 1024 * 1024; // 1 MB
  static const int _kMaxDimension = 1600;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Capacity is required';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid capacity';
                  }
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude (optional)',
                        hintText: 'e.g. 37.4220',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed < -90 || parsed > 90) {
                          return 'Enter a valid latitude (-90 to 90)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude (optional)',
                        hintText: 'e.g. -122.0841',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed < -180 || parsed > 180) {
                          return 'Enter a valid longitude (-180 to 180)';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upload Image (optional)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose file'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _imageFileName ?? 'No file selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_imageBytes != null)
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: _submitting
                          ? null
                          : () {
                              setState(() {
                                _imageBytes = null;
                                _imageFileName = null;
                                _imageStatus = null;
                              });
                            },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              if (_imageStatus != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _imageStatus!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _imageBytes!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  hintText: 'https://example.com/image.jpg',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null ||
                        (!uri.hasScheme || (!uri.scheme.startsWith('http')))) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
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

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read selected file. Please try again.'),
          ),
        );
        return;
      }

      final processed = await _processSelectedImage(bytes, file.name);

      if (!mounted) return;
      setState(() {
        _imageBytes = processed.bytes;
        _imageFileName = processed.fileName;
        _imageStatus = processed.info;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<_ImageProcessingResult> _processSelectedImage(
    Uint8List bytes,
    String? originalName,
  ) async {
    final displayName = (originalName?.trim().isNotEmpty ?? false)
        ? originalName!.trim()
        : 'room_image.jpg';

    if (bytes.length <= _kMaxUploadBytes) {
      return _ImageProcessingResult(
        bytes: bytes,
        fileName: displayName,
        info: 'Selected image (${_formatBytes(bytes.length)})',
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _ImageProcessingResult(
        bytes: bytes,
        fileName: displayName,
        info: 'Selected image (${_formatBytes(bytes.length)})',
      );
    }

    final resized = _resizeImage(decoded);

    var quality = 85;
    Uint8List encoded =
        Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    while (encoded.length > _kMaxUploadBytes && quality > 55) {
      quality -= 10;
      encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    final compressedName =
        p.setExtension(p.basenameWithoutExtension(displayName), '.jpg');

    return _ImageProcessingResult(
      bytes: encoded,
      fileName: compressedName,
      info:
          'Compressed ${_formatBytes(bytes.length)} -> ${_formatBytes(encoded.length)}',
    );
  }

  img.Image _resizeImage(img.Image image) {
    if (image.width <= _kMaxDimension && image.height <= _kMaxDimension) {
      return image;
    }

    if (image.width >= image.height) {
      return img.copyResize(
        image,
        width: _kMaxDimension,
        interpolation: img.Interpolation.linear,
      );
    }

    return img.copyResize(
      image,
      height: _kMaxDimension,
      interpolation: img.Interpolation.linear,
    );
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * kb;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
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

    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();
    final latitude = latText.isEmpty ? null : double.tryParse(latText);
    final longitude = lngText.isEmpty ? null : double.tryParse(lngText);

    debugPrint(
        'Calling createRoom with: name=${_nameController.text}, capacity=${_capacityController.text}, location=${_locationController.text}, latitude=$latitude, longitude=$longitude, imageUrl=${_imageUrlController.text}, imageFileName=$_imageFileName');

    final error = await widget.vm.createRoom(
      name: _nameController.text,
      capacity: int.parse(_capacityController.text.trim()),
      location: _locationController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      imageUrl:
          _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
      latitude: latitude,
      longitude: longitude,
      imageBytes: _imageBytes,
      imageFileName: _imageFileName,
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

class _ImageProcessingResult {
  const _ImageProcessingResult({
    required this.bytes,
    required this.fileName,
    required this.info,
  });

  final Uint8List bytes;
  final String fileName;
  final String info;
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
