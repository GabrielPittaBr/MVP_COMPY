import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_datasource.dart';
import '../datasources/in_memory_events_store.dart';

class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._remote);
  final EventsRemoteDataSource? _remote;

  @override
  Stream<List<Event>> watchAll() {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.watchAll();
    }
    return _remote.watchAll().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromMap(doc.id, doc.data())).toList();
    });
  }

  @override
  Future<Event?> getById(String id) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.getById(id);
    }
    final doc = await _remote.fetchById(id);
    final data = doc.data();
    if (data == null) return null;
    return Event.fromMap(doc.id, data);
  }

  @override
  Future<Event> joinEvent(String eventId) async {
    if (!kUseFirebaseRepos || _remote == null) {
      final store = InMemoryEventsStore.instance;
      final current = store.getById(eventId);
      if (current == null) {
        throw StateError('Evento $eventId não encontrado');
      }
      if (current.isFull) throw const EventFullException();
      return store.join(eventId, InMemoryEventsStore.currentUser);
    }

    // Firestore path
    final doc = await _remote.fetchById(eventId);
    final data = doc.data();
    if (data == null) throw StateError('Evento $eventId não encontrado');
    final event = Event.fromMap(doc.id, data);
    if (event.isFull) throw const EventFullException();

    final userId = event.creator.id; // placeholder — o caller já valida
    await _remote.join(eventId, userId);

    // Re-fetch para retornar o estado atualizado.
    final updated = await _remote.fetchById(eventId);
    return Event.fromMap(updated.id, updated.data()!);
  }

  @override
  Future<Event> createEvent(Event draft) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.add(draft);
    }
    final docRef = await _remote.create(draft.toMap());
    // Retorna o evento com o ID gerado pelo Firestore.
    return Event(
      id: docRef.id,
      title: draft.title,
      sport: draft.sport,
      location: draft.location,
      coordinates: draft.coordinates,
      dateTime: draft.dateTime,
      skillLevel: draft.skillLevel,
      totalSpots: draft.totalSpots,
      remainingSpots: draft.remainingSpots,
      bannerUrl: draft.bannerUrl,
      creator: draft.creator,
      description: draft.description,
      participants: draft.participants,
    );
  }
}
