import '../../../../shared/models/event.dart';
import '../repositories/events_repository.dart';

/// Inscreve o usuário atual em um evento (RN-05: valida vagas).
class JoinEvent {
  const JoinEvent(this._repository);
  final EventsRepository _repository;

  Future<Event> call(String eventId) => _repository.joinEvent(eventId);
}
