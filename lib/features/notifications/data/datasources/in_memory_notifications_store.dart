import 'dart:async';

import '../../../../features/home/data/datasources/mock_events.dart';
import '../../../../shared/models/event.dart';
import '../../domain/entities/app_notification.dart';

/// Notificações do modo mock. Faz o papel do gatilho `onEventEnded` (quem
/// chama é o `InMemoryEventsStore.end`) e da callable da avaliação, que
/// marca "Avaliado".
class InMemoryNotificationsStore {
  InMemoryNotificationsStore._() {
    // O evento encerrado das fixtures já nasce com a notificação, como se o
    // gatilho tivesse rodado quando ele terminou.
    for (final event in MockEvents.nearby) {
      final endedAt = event.endedAt;
      if (endedAt != null) createEventEnded(event, at: endedAt);
    }
  }

  static final InMemoryNotificationsStore instance =
      InMemoryNotificationsStore._();

  final Map<String, List<AppNotification>> _byUser =
      <String, List<AppNotification>>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<AppNotification> of(String uid) {
    final list = List<AppNotification>.of(_byUser[uid] ?? const [])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AppNotification>.unmodifiable(list);
  }

  Stream<List<AppNotification>> watch(String uid) async* {
    yield of(uid);
    yield* _changes.stream.map((_) => of(uid));
  }

  /// Uma notificação por participante, com o id determinístico; a do
  /// criador que encerrou à mão já nasce lida. Repetir não duplica.
  void createEventEnded(Event event, {required DateTime at}) {
    final id = eventEndedNotificationId(event.id);
    for (final uid in event.participantIds.toSet()) {
      final list = _byUser.putIfAbsent(uid, () => <AppNotification>[]);
      if (list.any((n) => n.id == id)) continue;
      list.add(AppNotification(
        id: id,
        type: AppNotificationType.eventEnded,
        eventId: event.id,
        eventTitle: event.title,
        sport: event.sport.name,
        creatorId: event.creator.id,
        endedAutomatically: event.endedAutomatically,
        createdAt: at,
        readAt: uid == event.creator.id && !event.endedAutomatically ? at : null,
      ));
    }
    _changes.add(null);
  }

  void markRead(String uid, String notificationId, {required DateTime at}) {
    _update(uid, (n) => n.id == notificationId && !n.isRead,
        (n) => n.copyWith(readAt: at));
  }

  void markAllRead(String uid, Iterable<String> ids, {required DateTime at}) {
    final wanted = ids.toSet();
    _update(uid, (n) => wanted.contains(n.id) && !n.isRead,
        (n) => n.copyWith(readAt: at));
  }

  /// O que a callable faz ao avaliar: "Avaliado", e lida se ainda não era.
  void complete(String uid, String eventId, {required DateTime at}) {
    final id = eventEndedNotificationId(eventId);
    _update(uid, (n) => n.id == id,
        (n) => n.copyWith(completedAt: at, readAt: n.readAt ?? at));
  }

  void _update(
    String uid,
    bool Function(AppNotification) test,
    AppNotification Function(AppNotification) change,
  ) {
    final list = _byUser[uid];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      if (test(list[i])) list[i] = change(list[i]);
    }
    _changes.add(null);
  }
}
