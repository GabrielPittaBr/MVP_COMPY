import '../../../../shared/models/event.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/sport_place.dart';
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

  /// Eventos não encerrados em que [uid] está inscrito, em tempo real e sem
  /// o filtro da folha (tarefa 14). Alimenta o card do evento ao vivo, que
  /// ignora o filtro, e a seção "Participando", que aplica o filtro no
  /// cliente.
  Stream<List<Event>> watchJoinedActive(String uid);

  /// Busca eventos por nome (prefixo do título) ou modalidade esportiva.
  Future<List<Event>> search(String query);

  Future<Event?> getById(String id);

  /// Acompanha um evento em tempo real; emite `null` se ele não existe.
  Stream<Event?> watchById(String id);

  /// Adiciona [user] (o usuário autenticado) como participante e
  /// decrementa vagas. Idempotente para quem já participa.
  /// Lança [EventFullException] se o evento estiver lotado (RN-05).
  Future<Event> joinEvent(String eventId, UserSummary user);

  /// Encerramento manual pelo criador (tarefa 14): grava o fim real com o
  /// horário do servidor e `endedAutomatically = false`.
  ///
  /// Lança [EventAlreadyEndedException] se o evento já estava encerrado —
  /// inclusive quando a regra recusa por ter passado da folga de 1h, caso
  /// em que a Function encerra por ele.
  Future<void> endEvent(String eventId);

  /// Cria um novo evento com os dados informados.
  Future<Event> createEvent(
    Event draft, {
    required SportPlace selectedPlace,
  });
}

class EventPlaceUnavailableException implements Exception {
  const EventPlaceUnavailableException();
  @override
  String toString() => 'O local não está mais ativo.';
}

class EventPlaceChangedException implements Exception {
  const EventPlaceChangedException();
  @override
  String toString() => 'O local mudou. Revise e selecione novamente.';
}

class EventPlaceSportUnsupportedException implements Exception {
  const EventPlaceSportUnsupportedException();
  @override
  String toString() => 'O local não oferece a modalidade selecionada.';
}

class EventCreationOfflineException implements Exception {
  const EventCreationOfflineException();
  @override
  String toString() => 'Reconecte-se para criar o evento.';
}

/// O evento já estava encerrado quando o criador tentou encerrar.
class EventAlreadyEndedException implements Exception {
  const EventAlreadyEndedException();
  @override
  String toString() => 'Este evento já foi encerrado.';
}

/// Exceção lançada ao tentar entrar em um evento sem vagas (RN-05).
class EventFullException implements Exception {
  const EventFullException();
  @override
  String toString() => 'Evento sem vagas restantes';
}
