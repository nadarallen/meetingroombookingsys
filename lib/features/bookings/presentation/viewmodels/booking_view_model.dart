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
    debugPrint(
        'BookingViewModel.createBooking called with: roomId=$roomId, start=$start, end=$end, title=$title');

    final userId = _currentUserId();
    if (userId == null) {
      debugPrint('BookingViewModel.createBooking failed: User not signed in');
      _error = 'You must be signed in to create a booking.';
      notifyListeners();
      return false;
    }

    debugPrint('BookingViewModel.createBooking: userId=$userId');

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

    debugPrint(
        'BookingViewModel.createBooking: Created booking with id=${booking.id}');

    try {
      _error = null;
      debugPrint(
          'BookingViewModel.createBooking: Calling syncManager.createBooking');
      await _syncManager.createBooking(booking);
      debugPrint(
          'BookingViewModel.createBooking: Successfully created booking');
      await load(roomId: _activeRoomId ?? roomId);
      return true;
    } on BookingConflictException catch (e) {
      debugPrint(
          'BookingViewModel.createBooking: BookingConflictException - ${e.message}');
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('BookingViewModel.createBooking: Exception - $e');
      debugPrint('BookingViewModel.createBooking: StackTrace - $stackTrace');
      _error = 'Unable to create booking. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBooking({
    required String bookingId,
    required String roomId,
    required DateTime start,
    required DateTime end,
    String? title,
    String? notes,
  }) async {
    debugPrint(
        'BookingViewModel.updateBooking called with: bookingId=$bookingId, roomId=$roomId, start=$start, end=$end, title=$title');

    final userId = _currentUserId();
    if (userId == null) {
      debugPrint('BookingViewModel.updateBooking failed: User not signed in');
      _error = 'You must be signed in to update a booking.';
      notifyListeners();
      return false;
    }

    // Find the existing booking
    final existingBooking = _bookings.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => throw Exception('Booking not found'),
    );

    final updatedBooking = existingBooking.copyWith(
      roomId: roomId,
      startTime: start,
      endTime: end,
      title: title,
      notes: notes,
      status: db.BookingStatus.pending,
      syncStatus: db.SyncStatus.pendingUp,
      updatedAt: DateTime.now(),
    );

    debugPrint(
        'BookingViewModel.updateBooking: Created updated booking with id=${updatedBooking.id}');

    try {
      _error = null;
      debugPrint(
          'BookingViewModel.updateBooking: Calling syncManager.updateBooking');
      await _syncManager.updateBooking(updatedBooking);
      debugPrint(
          'BookingViewModel.updateBooking: Successfully updated booking');
      await load(roomId: _activeRoomId ?? roomId);
      return true;
    } on BookingConflictException catch (e) {
      debugPrint(
          'BookingViewModel.updateBooking: BookingConflictException - ${e.message}');
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('BookingViewModel.updateBooking: Exception - $e');
      debugPrint('BookingViewModel.updateBooking: StackTrace - $stackTrace');
      _error = 'Unable to update booking. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    debugPrint(
        'BookingViewModel.cancelBooking called with: bookingId=$bookingId');

    try {
      _error = null;
      await _syncManager.updateBookingStatus(
          bookingId, db.BookingStatus.cancelled);
      debugPrint(
          'BookingViewModel.cancelBooking: Successfully cancelled booking');
      await load(roomId: _activeRoomId);
      return true;
    } catch (e, stackTrace) {
      debugPrint('BookingViewModel.cancelBooking: Exception - $e');
      debugPrint('BookingViewModel.cancelBooking: StackTrace - $stackTrace');
      _error = 'Unable to cancel booking. Please try again.';
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
