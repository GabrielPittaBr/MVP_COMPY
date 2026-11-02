import '../../../../core/constants/app_flags.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/in_memory_notifications_store.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(
    this._remote, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final NotificationsRemoteDataSource? _remote;
  final DateTime Function() _clock;

  bool get _mock => !kUseFirebaseRepos || _remote == null;

  @override
  Stream<List<AppNotification>> watch(String uid) => _mock
      ? InMemoryNotificationsStore.instance.watch(uid)
      : _remote!.watch(uid);

  @override
  Future<void> markRead(String uid, String notificationId) async {
    if (_mock) {
      InMemoryNotificationsStore.instance
          .markRead(uid, notificationId, at: _clock());
      return;
    }
    await _remote!.markRead(uid, notificationId);
  }

  @override
  Future<void> markAllRead(String uid, Iterable<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    if (_mock) {
      InMemoryNotificationsStore.instance
          .markAllRead(uid, notificationIds, at: _clock());
      return;
    }
    await _remote!.markAllRead(uid, notificationIds);
  }
}
