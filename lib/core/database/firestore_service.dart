import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/amenity.dart';
import 'models/app_user.dart';
import 'models/booking.dart';
import 'models/room.dart';

class BookingConflictException implements Exception {
  BookingConflictException(this.message);
  final String message;

  @override
  String toString() => 'BookingConflictException(message: $message)';
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _roomsCollection =>
      _firestore.collection('rooms');
  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _amenitiesCollection =>
      _firestore.collection('amenities');

  // ---- Fetchers ----
  Future<List<Room>> fetchRooms() async {
    final snapshot = await _roomsCollection.get();
    return snapshot.docs
        .map((doc) => Room.fromCloudMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Amenity>> fetchAmenities() async {
    final snapshot = await _amenitiesCollection.get();
    return snapshot.docs
        .map((doc) => Amenity.fromCloudMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<AppUser>> fetchUsers() async {
    final snapshot = await _usersCollection.get();
    return snapshot.docs
        .map((doc) => AppUser.fromCloudMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Booking>> fetchBookings({String? roomId}) async {
    Query<Map<String, dynamic>> query = _bookingsCollection;
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Booking.fromCloudMap(doc.id, doc.data()))
        .toList();
  }

  // ---- Upserts ----
  Future<void> upsertRoom(Room room) async {
    await _roomsCollection
        .doc(room.id)
        .set(room.toCloudMap(), SetOptions(merge: true));
  }

  Future<void> deleteRoom(String id) async {
    await _roomsCollection.doc(id).delete();
  }

  Future<void> upsertAmenity(Amenity amenity) async {
    await _amenitiesCollection
        .doc(amenity.id)
        .set(amenity.toCloudMap(), SetOptions(merge: true));
  }

  Future<void> upsertUser(AppUser user) async {
    await _usersCollection
        .doc(user.id)
        .set(user.toCloudMap(), SetOptions(merge: true));
  }

  Future<void> upsertBooking(Booking booking) async {
    await _bookingsCollection
        .doc(booking.id)
        .set(booking.toCloudMap(), SetOptions(merge: true));
  }

  /// Creates a booking ensuring that there is no overlapping booking for the same room.
  Future<void> createBookingWithConflictCheck(Booking booking) async {
    final bookingRef = _bookingsCollection.doc(booking.id);
    await _firestore.runTransaction((transaction) async {
      final overlappingQuery = _bookingsCollection
          .where('roomId', isEqualTo: booking.roomId)
          .where('startTime', isLessThan: booking.endTime.toUtc())
          .where('endTime', isGreaterThan: booking.startTime.toUtc());

      final overlappingSnapshot = await overlappingQuery.get();
      final hasConflict = overlappingSnapshot.docs.any(
        (doc) => doc.id != booking.id && doc['status'] != 'cancelled',
      );

      if (hasConflict) {
        throw BookingConflictException(
            'Room already booked for the selected slot.');
      }

      transaction.set(
          bookingRef, booking.toCloudMap(), SetOptions(merge: true));
    });
  }

  Future<void> updateBookingWithConflictCheck(Booking booking) async {
    await _firestore.runTransaction((transaction) async {
      final bookingRef = _bookingsCollection.doc(booking.id);

      // Check for conflicts with other bookings
      final overlappingQuery = _bookingsCollection
          .where('roomId', isEqualTo: booking.roomId)
          .where('startTime', isLessThan: booking.endTime)
          .where('endTime', isGreaterThan: booking.startTime);

      final overlappingSnapshot = await overlappingQuery.get();
      final hasConflict = overlappingSnapshot.docs.any(
        (doc) => doc.id != booking.id && doc['status'] != 'cancelled',
      );

      if (hasConflict) {
        throw BookingConflictException(
            'Room already booked for the selected slot.');
      }

      transaction.set(
          bookingRef, booking.toCloudMap(), SetOptions(merge: true));
    });
  }

  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    DateTime? updatedAt,
  }) async {
    await _bookingsCollection.doc(bookingId).update({
      'status': status.name,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc(),
    });
  }

  Future<void> deleteBooking(String id) async {
    await _bookingsCollection.doc(id).delete();
  }

  Future<void> sendNotification({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    await _notificationsCollection.doc(id).set(payload);
  }

  Stream<List<Booking>> listenToBookings({String? roomId}) {
    Query<Map<String, dynamic>> query = _bookingsCollection;
    if (roomId != null) {
      query = query.where('roomId', isEqualTo: roomId);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Booking.fromCloudMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Room>> listenToRooms() {
    return _roomsCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Room.fromCloudMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
