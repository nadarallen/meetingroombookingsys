import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._();
  LocalDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'meeting_rooms.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          capacity INTEGER NOT NULL
        );
        ''');
        await db.execute('''
        CREATE TABLE IF NOT EXISTS bookings (
          id TEXT PRIMARY KEY,
          roomId TEXT NOT NULL,
          title TEXT NOT NULL,
          start INTEGER NOT NULL,
          end INTEGER NOT NULL
        );
        ''');
      },
    );
  }
}

