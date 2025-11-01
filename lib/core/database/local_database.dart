import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models/admin_audit_log_record.dart';
import 'models/admin_broadcast_record.dart';
import 'models/amenity.dart';
import 'models/app_user.dart';
import 'models/booking.dart';
import 'models/room.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _databaseName = 'meeting_room_booking.db';
  static const _schemaVersion = 6;

  static const _roomsTable = 'rooms';
  static const _bookingsTable = 'bookings';
  static const _usersTable = 'users';
  static const _amenitiesTable = 'amenities';
  static const _adminBroadcastsTable = 'admin_broadcasts';
  static const _adminAuditLogsTable = 'admin_audit_logs';

  Database? _database;
  Completer<Database>? _opening;
  DatabaseFactory? _factory;

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
      final factory = _ensureFactory();
      final dbPath = await _resolveDatabasePath(factory);
      final directory = Directory(p.dirname(dbPath));

      // Ensure base directory exists (primarily for desktop / FFI).
      await directory.create(recursive: true);

      _database = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _schemaVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
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

  DatabaseFactory _ensureFactory() {
    if (_factory != null) {
      return _factory!;
    }

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      _factory = databaseFactoryFfi;
    } else {
      _factory = databaseFactory;
    }

    return _factory!;
  }

  Future<String> _resolveDatabasePath(DatabaseFactory factory) async {
    if (factory == databaseFactoryFfi) {
      final basePath = await databaseFactoryFfi.getDatabasesPath();
      return p.join(basePath, _databaseName);
    }

    final basePath = await getDatabasesPath();
    return p.join(basePath, _databaseName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_roomsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        location TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        amenity_ids TEXT,
        latitude REAL,
        longitude REAL,
        is_active INTEGER NOT NULL DEFAULT 1,
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
        is_active INTEGER NOT NULL DEFAULT 1,
        is_admin INTEGER NOT NULL DEFAULT 0
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
        no_show_risk_score INTEGER,
        checked_in INTEGER NOT NULL DEFAULT 0,
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
    await db.execute(
      'CREATE INDEX idx_bookings_status ON $_bookingsTable(status)',
    );
    await db.execute(
      'CREATE INDEX idx_rooms_active ON $_roomsTable(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_rooms_location ON $_roomsTable(latitude, longitude)',
    );
    await db.execute('''
      CREATE TABLE $_adminBroadcastsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_value TEXT,
        status TEXT NOT NULL,
        scheduled_at INTEGER,
        sent_at INTEGER,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_adminAuditLogsTable (
        id TEXT PRIMARY KEY,
        actor_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_admin_broadcasts_status ON $_adminBroadcastsTable(status)',
    );
    await db.execute(
      'CREATE INDEX idx_admin_broadcasts_schedule ON $_adminBroadcastsTable(scheduled_at)',
    );
    await db.execute(
      'CREATE INDEX idx_admin_audit_created_at ON $_adminAuditLogsTable(created_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final migrations = <_Migration>[
      _Migration(
        targetVersion: 2,
        run: (database) async {
          await database.execute(
            'ALTER TABLE $_roomsTable ADD COLUMN latitude REAL',
          );
          await database.execute(
            'ALTER TABLE $_roomsTable ADD COLUMN longitude REAL',
          );
        },
      ),
      _Migration(
        targetVersion: 3,
        run: (database) async {
          await database.execute(
            'ALTER TABLE $_roomsTable ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
          );
          await database.execute(
            'ALTER TABLE $_usersTable ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute(
            'ALTER TABLE $_bookingsTable ADD COLUMN no_show_risk_score INTEGER',
          );
          await database.execute(
            'ALTER TABLE $_bookingsTable ADD COLUMN checked_in INTEGER NOT NULL DEFAULT 0',
          );
        },
      ),
      _Migration(
        targetVersion: 4,
        run: (database) async {
          await database.execute(
            'ALTER TABLE $_roomsTable ADD COLUMN image_url TEXT',
          );
        },
      ),
      _Migration(
        targetVersion: 5,
        run: (database) async {
          // Add performance indexes
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_bookings_status ON $_bookingsTable(status)',
          );
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_rooms_active ON $_roomsTable(is_active)',
          );
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_rooms_location ON $_roomsTable(latitude, longitude)',
          );
        },
      ),
      _Migration(
        targetVersion: 6,
        run: (database) async {
          await database.execute('''
            CREATE TABLE IF NOT EXISTS $_adminBroadcastsTable (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              message TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_value TEXT,
              status TEXT NOT NULL,
              scheduled_at INTEGER,
              sent_at INTEGER,
              created_at INTEGER NOT NULL,
              created_by TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE IF NOT EXISTS $_adminAuditLogsTable (
              id TEXT PRIMARY KEY,
              actor_id TEXT NOT NULL,
              action_type TEXT NOT NULL,
              entity_type TEXT NOT NULL,
              entity_id TEXT,
              payload TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_admin_broadcasts_status ON $_adminBroadcastsTable(status)',
          );
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_admin_broadcasts_schedule ON $_adminBroadcastsTable(scheduled_at)',
          );
          await database.execute(
            'CREATE INDEX IF NOT EXISTS idx_admin_audit_created_at ON $_adminAuditLogsTable(created_at)',
          );
        },
      ),
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

  /// Checks for booking conflicts in the local database
  Future<bool> hasBookingConflict(Booking booking,
      {String? excludeBookingId}) async {
    final db = await database;
    final result = await db.query(
      _bookingsTable,
      where: '''
        room_id = ? 
        AND status != 'cancelled' 
        AND id != ?
        AND (
          (start_time < ? AND end_time > ?) OR
          (start_time < ? AND end_time > ?) OR
          (start_time >= ? AND end_time <= ?)
        )
      ''',
      whereArgs: [
        booking.roomId,
        excludeBookingId ?? booking.id,
        booking.endTime.millisecondsSinceEpoch,
        booking.startTime.millisecondsSinceEpoch,
        booking.startTime.millisecondsSinceEpoch,
        booking.endTime.millisecondsSinceEpoch,
        booking.startTime.millisecondsSinceEpoch,
        booking.endTime.millisecondsSinceEpoch,
      ],
    );

    return result.isNotEmpty;
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

  // Clear methods for development/testing
  Future<void> clearRooms() async {
    final db = await database;
    await db.delete(_roomsTable);
  }

  Future<void> clearBookings() async {
    final db = await database;
    await db.delete(_bookingsTable);
  }

  Future<void> clearUsers() async {
    final db = await database;
    await db.delete(_usersTable);
  }

  Future<void> clearAmenities() async {
    final db = await database;
    await db.delete(_amenitiesTable);
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

  Future<int> getPendingBookingsCount() async {
    final db = await database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_bookingsTable WHERE status = ?',
        ['pending'],
      ),
    );
    return result ?? 0;
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

  Future<void> upsertAdminBroadcast(AdminBroadcastRecord record) async {
    final db = await database;
    await db.insert(
      _adminBroadcastsTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdminBroadcastRecord>> getAdminBroadcasts({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      _adminBroadcastsTable,
      orderBy:
          'COALESCE(scheduled_at, created_at) DESC, created_at DESC',
      limit: limit,
    );
    return result.map(AdminBroadcastRecord.fromMap).toList();
  }

  Future<void> insertAdminAuditLog(AdminAuditLogRecord record) async {
    final db = await database;
    await db.insert(
      _adminAuditLogsTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdminAuditLogRecord>> getAdminAuditLogs({int limit = 100}) async {
    final db = await database;
    final result = await db.query(
      _adminAuditLogsTable,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map(AdminAuditLogRecord.fromMap).toList();
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
