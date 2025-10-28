import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'local_database.dart';
import 'models/amenity.dart';
import 'models/app_user.dart';
import 'models/booking.dart';
import 'models/room.dart';

class DatabaseSyncManager {
  DatabaseSyncManager({
    required this.localDatabase,
    required this.remoteService,
  });

  final LocalDatabase localDatabase;
  final FirestoreService remoteService;

  StreamSubscription<List<Booking>>? _bookingSubscription;
  StreamSubscription<List<Room>>? _roomSubscription;
  bool _initialised = false;

  Future<void> initialize({bool enableListeners = true}) async {
    if (_initialised) return;
    await syncFromCloud();
    if (enableListeners) {
      _listenToRemoteChanges();
    }
    _initialised = true;
  }

  Future<void> dispose() async {
    await _bookingSubscription?.cancel();
    await _roomSubscription?.cancel();
  }

  void _listenToRemoteChanges() {
    _bookingSubscription = remoteService.listenToBookings().listen(
      (bookings) async {
        final sanitized = bookings
            .map((booking) => booking.copyWith(syncStatus: SyncStatus.synced))
            .toList();
        await localDatabase.upsertBookings(sanitized);
      },
      onError: (Object error) {
        // Let caller decide how to surface this. For now it's a silent log.
      },
    );

    _roomSubscription = remoteService.listenToRooms().listen(
      (rooms) async {
        await localDatabase.upsertRooms(rooms);
      },
      onError: (Object error) {},
    );
  }

  Future<void> syncFromCloud() async {
    final rooms = await remoteService.fetchRooms();
    final amenities = await remoteService.fetchAmenities();
    final users = await remoteService.fetchUsers();
    final bookings = await remoteService.fetchBookings();

    await localDatabase.upsertRooms(rooms);
    await localDatabase.upsertAmenities(amenities);
    await localDatabase.upsertUsers(users);
    await localDatabase.upsertBookings(
      bookings.map((b) => b.copyWith(syncStatus: SyncStatus.synced)).toList(),
    );
  }

  Future<void> pushPendingChanges() async {
    final pendingBookings = await localDatabase.getPendingBookings();
    for (final booking in pendingBookings) {
      try {
        await remoteService.createBookingWithConflictCheck(
          booking.copyWith(syncStatus: SyncStatus.synced),
        );
        await localDatabase.markBookingSynced(booking.id);
      } on BookingConflictException {
        // mark as failed conflict to surface to UI
        await localDatabase.upsertBooking(
          booking.copyWith(syncStatus: SyncStatus.failed),
        );
      } on FirebaseException {
        // Remain pending until connectivity returns
        rethrow;
      }
    }
  }

  Future<void> upsertRoom(Room room) async {
    // Always save locally first for offline support
    await localDatabase.upsertRoom(room);

    try {
      // Try to save to remote, but don't fail if it doesn't work
      await remoteService.upsertRoom(room);
    } catch (e) {
      // Log the error but don't throw - room is saved locally
      // TODO: Replace with proper logging in production
      debugPrint('Failed to sync room to cloud: $e');
      // The room will be synced later when connectivity is restored
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await remoteService.deleteRoom(roomId);
    } on FirebaseException {
      rethrow;
    }
    await localDatabase.deleteBookingsForRoom(roomId);
    await localDatabase.deleteRoom(roomId);
  }

  Future<void> upsertAmenity(Amenity amenity) async {
    await localDatabase.upsertAmenity(amenity);
    await remoteService.upsertAmenity(amenity);
  }

  Future<void> upsertUser(AppUser user) async {
    await localDatabase.upsertUser(user);
    await remoteService.upsertUser(user);
  }

  Future<void> createBooking(Booking booking) async {
    debugPrint(
        'DatabaseSyncManager.createBooking called with booking: ${booking.id}');

    // Check for local conflicts first
    debugPrint(
        'DatabaseSyncManager.createBooking: Checking for local conflicts');
    final hasLocalConflict = await localDatabase.hasBookingConflict(booking);
    if (hasLocalConflict) {
      debugPrint('DatabaseSyncManager.createBooking: Local conflict detected');
      throw BookingConflictException(
          'Room already booked for the selected slot.');
    }

    final pending = booking.copyWith(
      syncStatus: SyncStatus.pendingUp,
      updatedAt: DateTime.now(),
    );

    debugPrint('DatabaseSyncManager.createBooking: Saving locally first');
    await localDatabase.upsertBooking(pending);

    try {
      debugPrint('DatabaseSyncManager.createBooking: Attempting remote save');
      await remoteService.createBookingWithConflictCheck(
        pending.copyWith(syncStatus: SyncStatus.synced),
      );
      debugPrint('DatabaseSyncManager.createBooking: Remote save successful');
      await localDatabase.markBookingSynced(pending.id);
    } on BookingConflictException catch (e) {
      debugPrint(
          'DatabaseSyncManager.createBooking: BookingConflictException - ${e.message}');
      await localDatabase.upsertBooking(
        pending.copyWith(syncStatus: SyncStatus.failed),
      );
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint(
          'DatabaseSyncManager.createBooking: FirebaseException - ${e.message}');
      // Keep as pending for retry.
      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
          'DatabaseSyncManager.createBooking: Unexpected exception - $e');
      debugPrint('DatabaseSyncManager.createBooking: StackTrace - $stackTrace');
      rethrow;
    }
  }

  Future<void> updateBooking(Booking booking) async {
    debugPrint(
        'DatabaseSyncManager.updateBooking called with booking: ${booking.id}');

    // Check for local conflicts first (excluding the current booking)
    debugPrint(
        'DatabaseSyncManager.updateBooking: Checking for local conflicts');
    final hasLocalConflict = await localDatabase.hasBookingConflict(booking,
        excludeBookingId: booking.id);
    if (hasLocalConflict) {
      debugPrint('DatabaseSyncManager.updateBooking: Local conflict detected');
      throw BookingConflictException(
          'Room already booked for the selected slot.');
    }

    final pending = booking.copyWith(
      syncStatus: SyncStatus.pendingUp,
      updatedAt: DateTime.now(),
    );

    debugPrint('DatabaseSyncManager.updateBooking: Saving locally first');
    await localDatabase.upsertBooking(pending);

    try {
      debugPrint('DatabaseSyncManager.updateBooking: Attempting remote save');
      await remoteService.updateBookingWithConflictCheck(
        pending.copyWith(syncStatus: SyncStatus.synced),
      );
      debugPrint('DatabaseSyncManager.updateBooking: Remote save successful');
      await localDatabase.markBookingSynced(pending.id);
    } on BookingConflictException catch (e) {
      debugPrint(
          'DatabaseSyncManager.updateBooking: BookingConflictException - ${e.message}');
      await localDatabase.upsertBooking(
        pending.copyWith(syncStatus: SyncStatus.failed),
      );
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint(
          'DatabaseSyncManager.updateBooking: FirebaseException - ${e.message}');
      // Keep as pending for retry.
      rethrow;
    } catch (e, stackTrace) {
      debugPrint(
          'DatabaseSyncManager.updateBooking: Unexpected exception - $e');
      debugPrint('DatabaseSyncManager.updateBooking: StackTrace - $stackTrace');
      rethrow;
    }
  }

  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    final booking = await _findBookingLocally(bookingId);
    if (booking == null) {
      return;
    }

    final updatedBooking = booking.copyWith(
      status: status,
      syncStatus: SyncStatus.pendingUp,
      updatedAt: DateTime.now(),
    );
    await localDatabase.upsertBooking(updatedBooking);

    try {
      await remoteService.updateBookingStatus(bookingId, status);
      await localDatabase.markBookingSynced(bookingId);
    } on FirebaseException {
      rethrow;
    }
  }

  Future<void> deleteBooking(String id) async {
    final booking = await _findBookingLocally(id);
    if (booking == null) return;

    await localDatabase.deleteBooking(id);
    try {
      await remoteService.deleteBooking(id);
    } on FirebaseException {
      // Requeue deletion by storing a tombstone entry.
      final tombstone = booking.copyWith(
        syncStatus: SyncStatus.pendingDelete,
        updatedAt: DateTime.now(),
      );
      await localDatabase.upsertBooking(tombstone);
      rethrow;
    }
  }

  Future<Booking?> _findBookingLocally(String id) async {
    return await localDatabase.getBookingById(id);
  }
}
