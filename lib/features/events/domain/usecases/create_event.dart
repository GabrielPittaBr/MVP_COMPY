import '../../../../shared/models/event.dart';
import '../repositories/events_repository.dart';

class CreateEvent {
  const CreateEvent(this._repository);
  final EventsRepository _repository;

  Future<Event> call(Event draft) => _repository.createEvent(draft);
}
