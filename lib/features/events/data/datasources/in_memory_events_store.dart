import 'dart:async';

import '../../../../features/home/data/datasources/mock_events.dart';
import '../../../../features/notifications/data/datasources/in_memory_notifications_store.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/events_filter.dart';

/// Repositório em memória que mantém o estado dos eventos para o MVP em
/// modo mock — emite uma nova snapshot via stream sempre que algo muda
/// (ex.: alguém clica em "Participar" e as vagas restantes diminuem).
///
/// Singleton para que múltiplas telas vejam a mesma fonte de verdade
/// (Home, Eventos e Detalhes).
class InMemoryEventsStore {
  InMemoryEventsStore._() {
    _events = List<Event>.from(MockEvents.nearby);
    _controller.add(List<Event>.unmodifiable(_events));
  }

  static final InMemoryEventsStore instance = InMemoryEventsStore._();

  late List<Event> _events;
  final StreamController<List<Event>> _controller =
      StreamController<List<Event>>.broadcast();

  Stream<List<Event>> watchAll() async* {
    yield List<Event>.unmodifiable(_events);
    yield* _controller.stream;
  }

  /// Snapshot imutável da lista atual — usado pela paginação e busca mock.
  List<Event> get snapshot => List<Event>.unmodifiable(_events);

  /// Snapshot já filtrada — espelha os `where` do Firestore para que a
  /// paginação mock percorra o mesmo conjunto que a consulta real
  /// percorreria. Filtro vazio devolve tudo.
  List<Event> snapshotMatching(EventsFilter filter) {
    if (filter.isEmpty) return snapshot;
    return List<Event>.unmodifiable(_events.where(filter.matches));
  }

  /// Eventos criados por [uid] — espelha
  /// `where('creator.id', isEqualTo: uid).orderBy('dateTime')`.
  List<Event> createdBy(String uid, EventsFilter filter) =>
      _sortedByDate((e) => e.creator.id == uid, filter);

  /// Eventos em que [uid] está inscrito — espelha
  /// `where('participantIds', arrayContains: uid).orderBy('dateTime')`.
  List<Event> joinedBy(String uid, EventsFilter filter) =>
      _sortedByDate((e) => e.participantIds.contains(uid), filter);

  /// [joinedBy] em tempo real, sem filtro da folha.
  Stream<List<Event>> watchJoinedBy(String uid) =>
      watchAll().map((_) => joinedBy(uid, const EventsFilter()));

  /// As duas seções não são paginadas, então (ao contrário da lista
  /// principal) podem ordenar em memória sem risco de cursor inconsistente.
  List<Event> _sortedByDate(bool Function(Event) test, EventsFilter filter) {
    final result = _events.where((e) => test(e) && filter.matches(e)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return List<Event>.unmodifiable(result);
  }

  /// Acompanha um evento — espelha o `doc(id).snapshots()` do Firestore,
  /// para o detalhe refletir join e encerramento sem recarregar.
  Stream<Event?> watchById(String id) =>
      watchAll().map((events) => _find(events, id)).distinct();

  static Event? _find(List<Event> events, String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  Event? getById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adiciona o usuário [user] aos participantes de [eventId] e
  /// decrementa as vagas restantes. Idempotente: se o usuário já está
  /// inscrito, devolve o evento sem alterações.
  Event join(String eventId, UserSummary user) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      throw StateError('Evento $eventId não encontrado');
    }
    final current = _events[index];
    if (current.participants.any((p) => p.id == user.id)) return current;
    if (current.isFull) {
      // O caller decide se traduz para EventFullException — mantemos o
      // store agnóstico ao tipo de erro de domínio.
      return current;
    }
    final updated = current.copyWith(
      participants: <UserSummary>[...current.participants, user],
      remainingSpots: current.remainingSpots - 1,
    );
    _events[index] = updated;
    _controller.add(List<Event>.unmodifiable(_events));
    return updated;
  }

  /// Encerra [eventId] em [at] — no mock, faz o papel do criador e da
  /// Function. Lança [StateError] se o evento já estava encerrado; o
  /// repositório traduz para a exceção de domínio.
  Event end(String eventId, {required DateTime at, bool automatic = false}) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      throw StateError('Evento $eventId não encontrado');
    }
    final current = _events[index];
    if (current.endedAt != null) {
      throw StateError('Evento $eventId já encerrado');
    }
    final ended = current.copyWith(endedAt: at, endedAutomatically: automatic);
    _events[index] = ended;
    _controller.add(List<Event>.unmodifiable(_events));
    // O papel do gatilho `onEventEnded`: avisar cada participante.
    InMemoryNotificationsStore.instance.createEventEnded(ended, at: at);
    return ended;
  }

  /// Registra que [uid] avaliou [eventId] — no mock, faz o papel da
  /// callable `submitEventRatings`, que grava o `ratedBy`.
  Event markRated(String eventId, String uid) {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      throw StateError('Evento $eventId não encontrado');
    }
    final current = _events[index];
    if (current.ratedBy.contains(uid)) return current;
    final rated = current.copyWith(ratedBy: <String>[...current.ratedBy, uid]);
    _events[index] = rated;
    _controller.add(List<Event>.unmodifiable(_events));
    return rated;
  }

  /// Grava [draft] como o Firestore faria: rascunho sem id (o formulário
  /// manda `id: ''`) ganha um id gerado, senão a rota de detalhe do evento
  /// recém-criado não teria o que abrir.
  Event add(Event draft) {
    final event =
        draft.id.isEmpty ? draft.copyWith(id: 'evt_local_${++_lastId}') : draft;
    _events = <Event>[event, ..._events];
    _controller.add(List<Event>.unmodifiable(_events));
    return event;
  }

  int _lastId = 0;
}
