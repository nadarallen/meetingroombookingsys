import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';

class RoomListViewModel extends ChangeNotifier {
  RoomListViewModel({
    required LocalDatabase localDatabase,
    required DatabaseSyncManager syncManager,
  })  : _localDatabase = localDatabase,
        _syncManager = syncManager;

  final LocalDatabase _localDatabase;
  final DatabaseSyncManager _syncManager;
  final Random _random = Random();

  final List<Room> _rooms = <Room>[];
  bool _loading = false;
  String? _error;
  bool _creating = false;
  final Set<String> _deleting = <String>{};

  List<Room> get rooms => List.unmodifiable(_rooms);
  bool get loading => _loading;
  String? get error => _error;
  bool get creating => _creating;
  bool isDeleting(String id) => _deleting.contains(id);

  Future<void> load() async {
    debugPrint('Loading rooms...');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await _localDatabase.getRooms();
      debugPrint('Loaded ${results.length} rooms from database');
      _rooms
        ..clear()
        ..addAll(results)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      debugPrint('Rooms after sorting: ${_rooms.map((r) => r.name).toList()}');
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      _error = 'Failed to fetch rooms';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      await _syncManager.syncFromCloud();
    } finally {
      await load();
    }
  }

  Future<String?> createRoom({
    required String name,
    required int capacity,
    required String location,
    String? description,
  }) async {
    if (_creating) return 'Please wait for the current operation to finish.';

    debugPrint(
        'Creating room: name=$name, capacity=$capacity, location=$location');

    _creating = true;
    notifyListeners();
    try {
      final room = Room(
        id: _generateRoomId(),
        name: name.trim(),
        capacity: capacity,
        location: location.trim(),
        description: description?.trim(),
      );

      debugPrint('Room object created: ${room.toString()}');

      await _syncManager.upsertRoom(room);
      debugPrint('Room saved to database');

      // Reload rooms from database to ensure consistency
      await load();
      debugPrint('Rooms reloaded, count: ${_rooms.length}');
      return null;
    } catch (e) {
      // TODO: Replace with proper logging in production
      debugPrint('Error creating room: $e');
      return 'Unable to create room: ${e.toString()}';
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  String _generateRoomId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return 'room_$timestamp$suffix';
  }

  Future<String?> deleteRoom(String roomId) async {
    if (_deleting.contains(roomId)) {
      return 'Delete already in progress.';
    }

    _deleting.add(roomId);
    notifyListeners();
    try {
      await _syncManager.deleteRoom(roomId);
      _rooms.removeWhere((room) => room.id == roomId);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Unable to delete room. Please try again.';
    } finally {
      final removed = _deleting.remove(roomId);
      if (removed) {
        notifyListeners();
      }
    }
  }
}
