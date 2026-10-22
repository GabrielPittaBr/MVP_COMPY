import '../repositories/events_repository.dart';

/// O criador encerra o evento ao vivo (tarefa 14).
class EndEvent {
  const EndEvent(this._repository);
  final EventsRepository _repository;

  Future<void> call(String eventId) => _repository.endEvent(eventId);
}
