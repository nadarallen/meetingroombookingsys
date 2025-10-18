import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/amenity.dart';
import 'models/app_user.dart';
import 'models/booking.dart';
import 'models/room.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _databaseName = 'meeting_room_booking.db';
  static const _schemaVersion = 1;

  static const _roomsTable = 'rooms';
  static const _bookingsTable = 'bookings';
  static const _usersTable = 'users';
  static const _amenitiesTable = 'amenities';

  Database? _database;
  Completer<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    if (_opening != null) {
      return _opening!.future;
    }

    final completer = Completer<Database>();
    _opening = completer;
    try {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, _databaseName);

      // Ensure base directory exists (primarily for desktop).
      await Directory(dbPath).create(recursive: true);

      _database = await openDatabase(
        fullPath,
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      completer.complete(_database!);
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _opening = null;
    }
    return completer.future;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_roomsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        location TEXT NOT NULL,
        description TEXT,
        amenity_ids TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_amenitiesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        metadata TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_usersTable (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT,
        department TEXT,
        photo_url TEXT,
        role TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE $_bookingsTable (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        status TEXT NOT NULL,
        title TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        metadata TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY(room_id) REFERENCES $_roomsTable(id) ON DELETE CASCADE,
        FOREIGN KEY(user_id) REFERENCES $_usersTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_bookings_room_time ON $_bookingsTable(room_id, start_time, end_time)',
    );
    await db.execute(
      'CREATE INDEX idx_bookings_user_time ON $_bookingsTable(user_id, start_time, end_time)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final migrations = <_Migration>[
      // Placeholder for future migrations.
    ];

    for (final migration in migrations) {
      if (migration.targetVersion > oldVersion &&
          migration.targetVersion <= newVersion) {
        await migration.run(db);
      }
    }
  }

  // ---- Room CRUD ----
  Future<void> upsertRoom(Room room) async {
    final db = await database;
    await db.insert(
      _roomsTable,
      room.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertRooms(List<Room> rooms) async {
    final db = await database;
    final batch = db.batch();
    for (final room in rooms) {
      batch.insert(
        _roomsTable,
        room.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Room>> getRooms() async {
    final db = await database;
    final result = await db.query(_roomsTable, orderBy: 'name ASC');
    return result.map(Room.fromLocalMap).toList();
  }

  Future<Room?> getRoomById(String id) async {
    final db = await database;
    final result = await db.query(
      _roomsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Room.fromLocalMap(result.first);
  }

  Future<void> deleteRoom(String id) async {
    final db = await database;
    await db.delete(_roomsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Amenity CRUD ----
  Future<void> upsertAmenity(Amenity amenity) async {
    final db = await database;
    await db.insert(
      _amenitiesTable,
      amenity.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertAmenities(List<Amenity> amenities) async {
    final db = await database;
    final batch = db.batch();
    for (final amenity in amenities) {
      batch.insert(
        _amenitiesTable,
        amenity.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Amenity>> getAmenities() async {
    final db = await database;
    final result = await db.query(_amenitiesTable, orderBy: 'name ASC');
    return result.map(Amenity.fromLocalMap).toList();
  }

  Future<void> deleteAmenity(String id) async {
    final db = await database;
    await db.delete(_amenitiesTable, where: 'id = ?', whereArgs: [id]);
  }

  // ---- User CRUD ----
  Future<void> upsertUser(AppUser user) async {
    final db = await database;
    await db.insert(
      _usersTable,
      user.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertUsers(List<AppUser> users) async {
    final db = await database;
    final batch = db.batch();
    for (final user in users) {
      batch.insert(
        _usersTable,
        user.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<AppUser?> getUserById(String id) async {
    final db = await database;
    final result = await db.query(
      _usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return AppUser.fromLocalMap(result.first);
  }

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final result = await db.query(_usersTable, orderBy: 'display_name ASC');
    return result.map(AppUser.fromLocalMap).toList();
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete(_usersTable, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Booking CRUD ----
  Future<void> upsertBooking(Booking booking) async {
    final db = await database;
    await db.insert(
      _bookingsTable,
      booking.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertBookings(List<Booking> bookings) async {
    final db = await database;
    final batch = db.batch();
    for (final booking in bookings) {
      batch.insert(
        _bookingsTable,
        booking.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Booking>> getBookings({
    String? roomId,
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    if (roomId != null) {
      whereClauses.add('room_id = ?');
      whereArgs.add(roomId);
    }

    if (userId != null) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }

    if (from != null) {
      whereClauses.add('end_time >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }

    if (to != null) {
      whereClauses.add('start_time <= ?');
      whereArgs.add(to.millisecondsSinceEpoch);
    }

    final result = await db.query(
      _bookingsTable,
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'start_time ASC',
    );
    return result.map(Booking.fromLocalMap).toList();
  }

  Future<void> deleteBooking(String id) async {
    final db = await database;
    await db.delete(_bookingsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBookingsForRoom(String roomId) async {
    final db = await database;
    await db.delete(_bookingsTable, where: 'room_id = ?', whereArgs: [roomId]);
  }

  Future<Booking?> getBookingById(String id) async {
    final db = await database;
    final result = await db.query(
      _bookingsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Booking.fromLocalMap(result.first);
  }

  Future<List<Booking>> getPendingBookings() async {
    final db = await database;
    final result = await db.query(
      _bookingsTable,
      where: 'sync_status != ?',
      whereArgs: [SyncStatus.synced],
    );
    return result.map(Booking.fromLocalMap).toList();
  }

  Future<void> markBookingSynced(String id) async {
    final db = await database;
    await db.update(
      _bookingsTable,
      {'sync_status': SyncStatus.synced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_bookingsTable);
      await txn.delete(_roomsTable);
      await txn.delete(_usersTable);
      await txn.delete(_amenitiesTable);
    });
  }
}

class _Migration {
  const _Migration({
    required this.targetVersion,
    required this.run,
  });

  final int targetVersion;
  final Future<void> Function(Database db) run;
}
