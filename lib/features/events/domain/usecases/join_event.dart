import '../../../../shared/models/event.dart';
import '../../../../shared/models/user_summary.dart';
import '../repositories/events_repository.dart';

/// Inscreve o usuário autenticado em um evento (RN-05: valida vagas).
class JoinEvent {
  const JoinEvent(this._repository);
  final EventsRepository _repository;

  Future<Event> call(String eventId, UserSummary user) =>
      _repository.joinEvent(eventId, user);
}
