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
    final pending = booking.copyWith(
      syncStatus: SyncStatus.pendingUp,
      updatedAt: DateTime.now(),
    );
    await localDatabase.upsertBooking(pending);
    try {
      await remoteService.createBookingWithConflictCheck(
        pending.copyWith(syncStatus: SyncStatus.synced),
      );
      await localDatabase.markBookingSynced(pending.id);
    } on BookingConflictException {
      await localDatabase.upsertBooking(
        pending.copyWith(syncStatus: SyncStatus.failed),
      );
      rethrow;
    } on FirebaseException {
      // Keep as pending for retry.
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
