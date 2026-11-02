import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

class WatchNotifications {
  const WatchNotifications(this._repository);
  final NotificationsRepository _repository;

  Stream<List<AppNotification>> call(String uid) => _repository.watch(uid);
}

class MarkNotificationRead {
  const MarkNotificationRead(this._repository);
  final NotificationsRepository _repository;

  Future<void> call(String uid, String notificationId) =>
      _repository.markRead(uid, notificationId);
}

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repository);
  final NotificationsRepository _repository;

  Future<void> call(String uid, Iterable<String> notificationIds) =>
      _repository.markAllRead(uid, notificationIds);
}
