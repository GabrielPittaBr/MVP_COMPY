import '../../../../shared/models/event.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';

abstract interface class EventsRepository {
  /// Página de eventos ordenada por data. Repassar o [cursor] da página
  /// anterior busca a próxima (blocos de [pageSize] documentos).
  ///
  /// [sport] filtra a consulta na origem (`where` no Firestore). Filtrar
  /// depois de buscar quebraria a paginação: páginas quase vazias e scroll
  /// infinito que não carrega nada. `null` lista todas as modalidades.
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize,
    Sport? sport,
  });

  /// Busca eventos por nome (prefixo do título) ou modalidade esportiva.
  Future<List<Event>> search(String query);

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
