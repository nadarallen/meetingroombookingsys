import '../entities/admin_broadcast.dart';
import '../repositories/admin_repository.dart';

class SaveAdminBroadcast {
  const SaveAdminBroadcast(this._repository);

  final AdminRepository _repository;

  Future<void> call(AdminBroadcast broadcast) {
    return _repository.saveBroadcast(broadcast);
  }
}
