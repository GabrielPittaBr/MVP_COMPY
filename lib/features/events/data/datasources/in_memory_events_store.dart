import 'dart:async';

import '../../../../features/home/data/datasources/mock_events.dart';
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
    return List<Event>.unmodifiable(
      _events.where((e) =>
          filter.matchesSport(e.sport) &&
          filter.matchesSkillLevel(e.skillLevel) &&
          filter.matchesDay(e.dateTime)),
    );
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

  Event add(Event draft) {
    _events = <Event>[draft, ..._events];
    _controller.add(List<Event>.unmodifiable(_events));
    return draft;
  }
}
