import 'package:flutter/foundation.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/room.dart';

class RoomMapViewModel extends ChangeNotifier {
  RoomMapViewModel({
    required LocalDatabase localDatabase,
    required DatabaseSyncManager syncManager,
  })  : _localDatabase = localDatabase,
        _syncManager = syncManager;

  final LocalDatabase _localDatabase;
  final DatabaseSyncManager _syncManager;

  final List<Room> _rooms = <Room>[];
  final List<dynamic> _bookings = <dynamic>[];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  List<Room> get rooms => List.unmodifiable(_rooms);
  List<dynamic> get bookings => List.unmodifiable(_bookings);

  List<Room> get roomsWithCoordinates => _rooms
      .where((room) => room.latitude != null && room.longitude != null)
      .toList();

  Future<void> load({bool refreshRemote = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      if (refreshRemote) {
        await _syncManager.syncFromCloud();
      }
      final rooms = await _localDatabase.getRooms();
      final bookings = await _localDatabase.getBookings();

      _rooms
        ..clear()
        ..addAll(rooms);
      _bookings
        ..clear()
        ..addAll(bookings);
    } catch (error, stackTrace) {
      debugPrint('RoomMapViewModel.load error: $error');
      debugPrint('$stackTrace');
      _error = 'Unable to load rooms for map view.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
