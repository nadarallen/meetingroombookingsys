import 'package:sqflite/sqflite.dart';

import '../../../../shared/services/local_db.dart';
import '../../domain/entities/meeting_room.dart';

class RoomLocalDataSource {
  Future<List<MeetingRoom>> getRooms() async {
    final db = await LocalDb.instance.database;
    final rows = await db.query('rooms', orderBy: 'capacity DESC');
    return rows
        .map((e) => MeetingRoom(
              id: e['id'] as String,
              name: e['name'] as String,
              capacity: e['capacity'] as int,
            ))
        .toList();
  }

  Future<void> cacheRooms(List<MeetingRoom> rooms) async {
    final db = await LocalDb.instance.database;
    final batch = db.batch();
    for (final r in rooms) {
      batch.insert(
        'rooms',
        {'id': r.id, 'name': r.name, 'capacity': r.capacity},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}

