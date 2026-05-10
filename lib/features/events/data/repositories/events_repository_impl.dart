import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_datasource.dart';
import '../datasources/in_memory_events_store.dart';

class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._remote);
  // ignore: unused_field
  final EventsRemoteDataSource _remote;

  @override
  Stream<List<Event>> watchAll() {
    if (!kUseFirebaseRepos) return InMemoryEventsStore.instance.watchAll();
    return const Stream<List<Event>>.empty();
  }

  @override
  Future<Event?> getById(String id) async {
    if (!kUseFirebaseRepos) return InMemoryEventsStore.instance.getById(id);
    return null;
  }

  @override
  Future<Event> joinEvent(String eventId) async {
    final store = InMemoryEventsStore.instance;
    final current = store.getById(eventId);
    if (current == null) {
      throw StateError('Evento $eventId não encontrado');
    }
    if (current.isFull) throw const EventFullException();
    return store.join(eventId, InMemoryEventsStore.currentUser);
  }

  @override
  Future<Event> createEvent(Event draft) async {
    return InMemoryEventsStore.instance.add(draft);
  }
}
