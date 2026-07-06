import '../../../../shared/models/event.dart';
import '../../../../shared/models/user_summary.dart';

abstract interface class EventsRepository {
  Stream<List<Event>> watchAll();
  Future<Event?> getById(String id);

  /// Adiciona [user] (o usuário autenticado) como participante e
  /// decrementa vagas. Idempotente para quem já participa.
  /// Lança [EventFullException] se o evento estiver lotado (RN-05).
  Future<Event> joinEvent(String eventId, UserSummary user);

  /// Cria um novo evento com os dados informados.
  Future<Event> createEvent(Event draft);
}

/// Exceção lançada ao tentar entrar em um evento sem vagas (RN-05).
class EventFullException implements Exception {
  const EventFullException();
  @override
  String toString() => 'Evento sem vagas restantes';
}
