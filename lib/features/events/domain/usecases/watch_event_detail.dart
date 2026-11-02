import '../../../../shared/models/event.dart';
import '../repositories/events_repository.dart';

/// Detalhe de um evento em tempo real: join e encerramento chegam à tela
/// sem recarregar (tarefa 14).
class WatchEventDetail {
  const WatchEventDetail(this._repository);
  final EventsRepository _repository;

  Stream<Event?> call(String id) => _repository.watchById(id);
}
