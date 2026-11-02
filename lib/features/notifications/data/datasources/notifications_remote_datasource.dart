import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

/// `users/{uid}/notifications` no Firestore. Quem cria é o gatilho
/// `onEventEnded`; o cliente só lê e marca como lida.
class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  /// Teto da central: as mais recentes bastam.
  static const int limit = 50;

  CollectionReference<Map<String, dynamic>> _of(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) {
    return _of(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => <AppNotification>[
              for (final doc in snapshot.docs)
                if (fromFirestore(doc.id, doc.data()) case final n?) n,
            ]);
  }

  Future<void> markRead(String uid, String notificationId) {
    return _of(uid)
        .doc(notificationId)
        .update(<String, Object?>{'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> markAllRead(String uid, Iterable<String> notificationIds) {
    final batch = _firestore.batch();
    for (final id in notificationIds) {
      batch.update(
        _of(uid).doc(id),
        <String, Object?>{'readAt': FieldValue.serverTimestamp()},
      );
    }
    return batch.commit();
  }

  /// Converte o documento; tipo desconhecido vira `null` e some da lista.
  static AppNotification? fromFirestore(String id, Map<String, dynamic> data) {
    if (data['type'] != 'eventEnded') return null;
    return AppNotification(
      id: id,
      type: AppNotificationType.eventEnded,
      eventId: (data['eventId'] as String?) ?? '',
      eventTitle: (data['eventTitle'] as String?) ?? '',
      sport: (data['sport'] as String?) ?? '',
      creatorId: (data['creatorId'] as String?) ?? '',
      endedAutomatically: (data['endedAutomatically'] as bool?) ?? false,
      // O horário do servidor chega nulo no primeiro snapshot local.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
