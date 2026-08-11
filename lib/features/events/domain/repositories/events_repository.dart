import '../../../../shared/models/event.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/user_summary.dart';
import '../entities/events_filter.dart';

abstract interface class EventsRepository {
  /// Página de eventos ordenada por data. Repassar o [cursor] da página
  /// anterior busca a próxima (blocos de [pageSize] documentos).
  ///
  /// [filter] entra na consulta (`where` no Firestore). Filtrar depois de
  /// buscar quebraria a paginação: páginas quase vazias e scroll infinito
  /// que não carrega nada. O filtro vazio lista tudo.
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize,
    EventsFilter filter,
  });

  /// Eventos criados por [uid] — seção "Criados por mim" da aba Eventos.
  ///
  /// Vem inteira, sem cursor: o volume por usuário é baixo. Por isso, e ao
  /// contrário de [fetchPage], aqui o [filter] pode ser aplicado no cliente
  /// sem quebrar nada.
  Future<List<Event>> fetchCreatedBy(String uid, {EventsFilter filter});

  /// Eventos em que [uid] está inscrito — seção "Participando". Mesmas
  /// características de [fetchCreatedBy].
  Future<List<Event>> fetchJoinedBy(String uid, {EventsFilter filter});

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
