import '../../../../shared/models/event.dart';
import '../repositories/events_repository.dart';

/// Eventos não encerrados de que o usuário participa, em tempo real.
class WatchJoinedActiveEvents {
  const WatchJoinedActiveEvents(this._repository);
  final EventsRepository _repository;

  Stream<List<Event>> call(String uid) => _repository.watchJoinedActive(uid);
}
