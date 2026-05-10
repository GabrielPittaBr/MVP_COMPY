import '../../../../shared/models/event.dart';

abstract interface class EventsRepository {
  Stream<List<Event>> watchAll();
  Future<Event?> getById(String id);

  /// Adiciona o usuário atual como participante e decrementa vagas.
  /// Lança [EventFullException] se o evento estiver lotado (RN-05).
  Future<Event> joinEvent(String eventId);

  /// Cria um novo evento com os dados informados.
  Future<Event> createEvent(Event draft);
}

/// Exceção lançada ao tentar entrar em um evento sem vagas (RN-05).
class EventFullException implements Exception {
  const EventFullException();
  @override
  String toString() => 'Evento sem vagas restantes';
}
