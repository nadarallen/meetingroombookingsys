import '../../domain/entities/meeting_room.dart';
import '../../domain/repositories/room_repository.dart';
import '../datasources/room_local_datasource.dart';
import '../datasources/room_remote_datasource.dart';

class RoomRepositoryImpl implements RoomRepository {
  RoomRepositoryImpl(this.remote, this.local);
  final RoomRemoteDataSource remote;
  final RoomLocalDataSource local;

  @override
  Future<List<MeetingRoom>> fetchRooms() async {
    try {
      final rooms = await remote.fetchRooms();
      await local.cacheRooms(rooms);
      return rooms;
    } catch (_) {
      return local.getRooms();
    }
  }
}

