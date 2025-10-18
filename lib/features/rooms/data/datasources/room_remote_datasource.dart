import '../../../../shared/services/firestore_service.dart';
import '../../domain/entities/meeting_room.dart';

class RoomRemoteDataSource {
  Future<List<MeetingRoom>> fetchRooms() async {
    final col = FirestoreService.instance.collection('rooms');
    final snap = await col.get();
    return snap.docs
        .map((d) => MeetingRoom(
              id: d.id,
              name: d.data()['name'] as String? ?? 'Room',
              capacity: (d.data()['capacity'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }
}
