import '../../../../shared/models/event.dart';
import '../repositories/events_repository.dart';

class GetEventDetail {
  const GetEventDetail(this._repository);
  final EventsRepository _repository;

  Future<Event?> call(String id) => _repository.getById(id);
}
