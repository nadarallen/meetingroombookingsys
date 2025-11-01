import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/admin_broadcast.dart';
import '../../domain/entities/broadcast_targets.dart';
import '../../domain/usecases/get_broadcast_targets.dart';
import '../../domain/usecases/save_admin_broadcast.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../shared/services/notification_service.dart';

enum BroadcastAudience {
  all,
  department,
  admin,
}

class BroadcastNotificationViewModel extends ChangeNotifier {
  BroadcastNotificationViewModel({
    required GetBroadcastTargets getBroadcastTargets,
    required SaveAdminBroadcast saveAdminBroadcast,
  })  : _getBroadcastTargets = getBroadcastTargets,
        _saveAdminBroadcast = saveAdminBroadcast;

  final GetBroadcastTargets _getBroadcastTargets;
  final SaveAdminBroadcast _saveAdminBroadcast;

  BroadcastTargets? _targets;
  bool _loadingTargets = false;
  bool _sending = false;
  String? _error;

  BroadcastTargets? get targets => _targets;
  bool get isLoadingTargets => _loadingTargets;
  bool get isSending => _sending;
  String? get error => _error;
  Map<String, int> get departmentCounts =>
      _targets?.departmentCounts ?? const {};

  int audienceCount(BroadcastAudience audience, {String? department}) {
    final targets = _targets;
    if (targets == null) return 0;
    switch (audience) {
      case BroadcastAudience.all:
        return targets.activeUsers;
      case BroadcastAudience.department:
        if (department == null) return 0;
        return targets.departmentCounts[department] ?? 0;
      case BroadcastAudience.admin:
        return targets.activeAdmins;
    }
  }

  Future<void> loadTargets() async {
    if (_loadingTargets) return;
    _loadingTargets = true;
    _error = null;
    notifyListeners();

    try {
      _targets = await _getBroadcastTargets();
    } catch (error, stackTrace) {
      debugPrint('Failed to load broadcast targets: $error\n$stackTrace');
      _error = error.toString();
    } finally {
      _loadingTargets = false;
      notifyListeners();
    }
  }

  Future<void> sendBroadcast({
    required AuthViewModel authViewModel,
    required NotificationService notificationService,
    required String title,
    required String message,
    required BroadcastAudience audience,
    String? department,
    DateTime? scheduledAt,
  }) async {
    if (_sending) return;

    _sending = true;
    _error = null;
    notifyListeners();

    try {
      final user = authViewModel.user;
      if (user == null) {
        throw StateError('Unable to determine admin user.');
      }

      final targetType = _mapAudienceToTarget(audience);
      final targetValue = audience == BroadcastAudience.department
          ? department
          : null;
      final now = DateTime.now();
      final status = scheduledAt != null && scheduledAt.isAfter(now)
          ? 'scheduled'
          : 'sent';

      final broadcast = AdminBroadcast(
        id: const Uuid().v4(),
        title: title,
        message: message,
        targetType: targetType,
        targetValue: targetValue,
        status: status,
        scheduledAt: scheduledAt,
        sentAt: status == 'sent' ? now : null,
        createdAt: now,
        createdBy: user.id,
      );

      await _saveAdminBroadcast(broadcast);

      if (status == 'sent') {
        await notificationService.sendBroadcast(
          title: title,
          body: message,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to send broadcast: $error\n$stackTrace');
      _error = error.toString();
      rethrow;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  String _mapAudienceToTarget(BroadcastAudience audience) {
    switch (audience) {
      case BroadcastAudience.all:
        return 'all';
      case BroadcastAudience.department:
        return 'department';
      case BroadcastAudience.admin:
        return 'admin';
    }
  }
}
