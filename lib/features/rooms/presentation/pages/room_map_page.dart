import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';
import '../viewmodels/room_map_view_model.dart';

class RoomMapPage extends StatelessWidget {
  const RoomMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoomMapViewModel>(
      create: (_) => RoomMapViewModel(
        localDatabase: context.read<LocalDatabase>(),
        syncManager: context.read<DatabaseSyncManager>(),
      )..load(refreshRemote: true),
      child: const _RoomMapView(),
    );
  }
}

class _RoomMapView extends StatefulWidget {
  const _RoomMapView();

  @override
  State<_RoomMapView> createState() => _RoomMapViewState();
}

class _RoomMapViewState extends State<_RoomMapView> {
  GoogleMapController? _mapController;
  Room? _selectedRoom;
  Set<Marker> _markers = {};

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoomMapViewModel>();
    final rooms = vm.roomsWithCoordinates;

    if (vm.loading && rooms.isEmpty) {
      return const Scaffold(
        appBar: _RoomMapAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (rooms.isEmpty) {
      return Scaffold(
        appBar: const _RoomMapAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No rooms with map coordinates yet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add latitude and longitude when creating rooms to see them on the map.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      vm.loading ? null : () => vm.load(refreshRemote: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Update markers when rooms change
    if (rooms.isNotEmpty) {
      _updateMarkers(rooms);
    }

    final initialRoom = _selectedRoom ?? rooms.first;
    final initialCamera = CameraPosition(
      target: LatLng(initialRoom.latitude!, initialRoom.longitude!),
      zoom: 14,
    );

    return Scaffold(
      appBar: const _RoomMapAppBar(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCamera,
            markers: _markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            mapType: MapType.normal,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (_) => setState(() => _selectedRoom = null),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'refresh_map',
                  onPressed:
                      vm.loading ? null : () => vm.load(refreshRemote: true),
                  child: vm.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'recenter_map',
                  onPressed: () => _recenter(initialRoom),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          if (_selectedRoom != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _RoomDetailsCard(
                  room: _selectedRoom!,
                  onNavigate: () => _openNavigation(_selectedRoom!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateMarkers(List<Room> rooms) {
    final newMarkers = rooms
        .where((room) => room.latitude != null && room.longitude != null)
        .map((room) {
      final now = DateTime.now();
      final vm = context.read<RoomMapViewModel>();

      // Check if room is currently booked
      final isBooked = vm.bookings.any((booking) =>
          booking.roomId == room.id &&
          booking.startTime.isBefore(now) &&
          booking.endTime.isAfter(now));

      // Determine marker color
      final isBookedMarker = isBooked;
      final icon = isBookedMarker
          ? BitmapDescriptor.defaultMarker
          : BitmapDescriptor.defaultMarkerWithHue(1.0); // Green hue

      return Marker(
        markerId: MarkerId(room.id),
        position: LatLng(room.latitude!, room.longitude!),
        infoWindow: InfoWindow(
          title: room.name,
          snippet: '${room.capacity} capacity • ${room.location}',
          onTap: () => _openNavigation(room),
        ),
        icon: icon,
        onTap: () => setState(() => _selectedRoom = room),
      );
    }).toSet();

    if (newMarkers.length != _markers.length) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Future<void> _recenter(Room room) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(room.latitude!, room.longitude!),
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _openNavigation(Room room) async {
    final lat = room.latitude;
    final lng = room.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to launch Maps for navigation.'),
        ),
      );
    }
  }
}

class _RoomMapAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _RoomMapAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Rooms Map'),
    );
  }
}

class _RoomDetailsCard extends StatelessWidget {
  const _RoomDetailsCard({
    required this.room,
    required this.onNavigate,
  });

  final Room room;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(room.location),
            if (room.description != null && room.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                room.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
