import '../entities/meeting_room.dart';

abstract class RoomRepository {
  Future<List<MeetingRoom>> fetchRooms();
}

