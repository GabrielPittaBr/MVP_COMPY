import '../entities/app_notification.dart';

abstract interface class NotificationsRepository {
  /// Notificações de [uid], da mais nova para a mais antiga, em tempo real.
  Stream<List<AppNotification>> watch(String uid);

  /// Marca uma notificação como lida (horário do servidor no Firestore).
  Future<void> markRead(String uid, String notificationId);

  /// "Marcar todas como lidas", num lote só.
  Future<void> markAllRead(String uid, Iterable<String> notificationIds);
}
