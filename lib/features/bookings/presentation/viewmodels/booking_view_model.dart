import 'package:flutter/foundation.dart';

import '../../../../core/database/database_sync_manager.dart';
import '../../../../core/database/firestore_service.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/database/models/booking.dart' as db;

class BookingViewModel extends ChangeNotifier {
  BookingViewModel({
    required DatabaseSyncManager syncManager,
    required LocalDatabase localDatabase,
    required String? Function() currentUserId,
  })  : _syncManager = syncManager,
        _localDatabase = localDatabase,
        _currentUserId = currentUserId;

  final DatabaseSyncManager _syncManager;
  final LocalDatabase _localDatabase;
  final String? Function() _currentUserId;

  final List<db.Booking> _bookings = <db.Booking>[];
  bool _loading = false;
  String? _error;
  String? _activeRoomId;

  List<db.Booking> get bookings => List.unmodifiable(_bookings);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({String? roomId}) async {
    _loading = true;
    _error = null;
    _activeRoomId = roomId;
    notifyListeners();
    try {
      final results = await _localDatabase.getBookings(roomId: roomId);
      _bookings
        ..clear()
        ..addAll(results)
        ..sort(
          (a, b) => a.startTime.compareTo(b.startTime),
        );
    } catch (_) {
      _error = 'Failed to load bookings.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load(roomId: _activeRoomId);
  }

  Future<bool> createBooking({
    required String roomId,
    required DateTime start,
    required DateTime end,
    String? title,
    String? notes,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      _error = 'You must be signed in to create a booking.';
      notifyListeners();
      return false;
    }

    final booking = db.Booking(
      id: _generateId(),
      roomId: roomId,
      userId: userId,
      startTime: start,
      endTime: end,
      title: title,
      notes: notes,
      status: db.BookingStatus.pending,
      metadata: const {},
      syncStatus: db.SyncStatus.pendingUp,
    );

    try {
      _error = null;
      await _syncManager.createBooking(booking);
      await load(roomId: _activeRoomId ?? roomId);
      return true;
    } on BookingConflictException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Unable to create booking. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}
