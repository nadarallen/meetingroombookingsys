import '../entities/admin_audit_log.dart';
import '../repositories/admin_repository.dart';

class RecordAdminAuditLog {
  const RecordAdminAuditLog(this._repository);

  final AdminRepository _repository;

  Future<void> call(AdminAuditLog log) {
    return _repository.recordAuditLog(log);
  }
}
