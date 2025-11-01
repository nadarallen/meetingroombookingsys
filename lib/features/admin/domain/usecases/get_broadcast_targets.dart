import '../entities/broadcast_targets.dart';
import '../repositories/admin_repository.dart';

class GetBroadcastTargets {
  const GetBroadcastTargets(this._repository);

  final AdminRepository _repository;

  Future<BroadcastTargets> call() {
    return _repository.getBroadcastTargets();
  }
}
