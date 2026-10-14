import '../../../../shared/models/event.dart';
import '../../../../shared/models/sport_place.dart';
import '../repositories/events_repository.dart';

class CreateEvent {
  const CreateEvent(this._repository);
  final EventsRepository _repository;

  Future<Event> call(
    Event draft, {
    required SportPlace selectedPlace,
  }) =>
      _repository.createEvent(draft, selectedPlace: selectedPlace);
}
