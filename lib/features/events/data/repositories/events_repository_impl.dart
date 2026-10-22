import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_place_snapshot.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../../shared/models/user_summary.dart';
import '../../domain/entities/events_filter.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_datasource.dart';
import '../datasources/in_memory_events_store.dart';

/// D17 (tarefa 14): nenhuma lista devolve evento encerrado. As consultas
/// do Firestore ganham o limite inferior [openEventsNotBefore], e o que
/// passar dele já encerrado sai no cliente com [withoutEnded], usando o
/// [_clock] — o mesmo "agora" da tela e dos testes.
class EventsRepositoryImpl implements EventsRepository {
  EventsRepositoryImpl(this._remote, {DateTime Function() clock = DateTime.now})
      : _clock = clock;
  final EventsRemoteDataSource? _remote;
  final DateTime Function() _clock;

  @override
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize = 10,
    EventsFilter filter = const EventsFilter(),
  }) async {
    final now = _clock();
    if (!kUseFirebaseRepos || _remote == null) {
      // Mock: o cursor é o offset na lista (já filtrada) em memória.
      final all = withoutEnded(
        InMemoryEventsStore.instance.snapshotMatching(filter),
        now,
      );
      final offset = (cursor as int?) ?? 0;
      final items = all.skip(offset).take(pageSize).toList();
      final nextOffset = offset + items.length;
      return PagedResult<Event>(
        items: items,
        cursor: nextOffset,
        hasMore: nextOffset < all.length,
      );
    }

    final snapshot = await _remote.fetchPage(
      startAfter: cursor as DocumentSnapshot<Map<String, dynamic>>?,
      limit: pageSize,
      sportName: filter.sport?.name,
      skillLevelNames: <String>[
        for (final level in filter.matchingSkillLevels) level.name,
      ],
      dayStart: filter.dayStart,
      dayEnd: filter.dayEnd,
      notBefore: openEventsNotBefore(now),
    );
    return PagedResult<Event>(
      // A página pode encolher (ou esvaziar) com o filtro; o cursor e o
      // hasMore continuam olhando os documentos lidos, e quem pagina é que
      // decide buscar a próxima.
      items: withoutEnded(
        snapshot.docs.map((doc) => Event.fromMap(doc.id, doc.data())),
        now,
      ),
      // Último documento da página — cursor do startAfterDocument.
      cursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : cursor,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  @override
  Future<List<Event>> fetchCreatedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async {
    final now = _clock();
    if (!kUseFirebaseRepos || _remote == null) {
      return withoutEnded(
          InMemoryEventsStore.instance.createdBy(uid, filter), now);
    }
    return _matching(
      await _remote.fetchCreatedBy(uid, notBefore: openEventsNotBefore(now)),
      filter,
      now,
    );
  }

  @override
  Future<List<Event>> fetchJoinedBy(
    String uid, {
    EventsFilter filter = const EventsFilter(),
  }) async {
    final now = _clock();
    if (!kUseFirebaseRepos || _remote == null) {
      return withoutEnded(
          InMemoryEventsStore.instance.joinedBy(uid, filter), now);
    }
    return _matching(
      await _remote.fetchJoinedBy(uid, notBefore: openEventsNotBefore(now)),
      filter,
      now,
    );
  }

  /// Aplica o filtro depois de buscar — legítimo aqui porque as duas seções
  /// vêm inteiras (ver `EventsRemoteDataSource.fetchCreatedBy`); na lista
  /// paginada isso produziria páginas quase vazias.
  List<Event> _matching(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    EventsFilter filter,
    DateTime now,
  ) {
    return withoutEnded(
      snapshot.docs
          .map((doc) => Event.fromMap(doc.id, doc.data()))
          .where(filter.matches),
      now,
    );
  }

  @override
  Future<List<Event>> search(String query) async {
    final normalized = TextNormalizer.normalize(query);
    if (normalized.isEmpty) return const <Event>[];

    // Modalidades cujo nome começa com o termo digitado ("vol" → Vôlei).
    final matchedSports = Sport.values
        .where((s) => TextNormalizer.normalize(s.label).startsWith(normalized))
        .map((s) => s.name)
        .toList();

    // A busca filtra os encerrados só no cliente: a consulta por prefixo do
    // título já usa o intervalo em `titleLower`, e um segundo intervalo em
    // `dateTime` pediria um índice novo.
    final now = _clock();
    if (!kUseFirebaseRepos || _remote == null) {
      return withoutEnded(
        InMemoryEventsStore.instance.snapshot.where((e) =>
            TextNormalizer.normalize(e.title).contains(normalized) ||
            matchedSports.contains(e.sport.name)),
        now,
      );
    }

    // Duas consultas em paralelo: prefixo do título + modalidades.
    final snapshots = await Future.wait(
      <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _remote.searchByTitlePrefix(query.trim().toLowerCase()),
        if (matchedSports.isNotEmpty) _remote.searchBySports(matchedSports),
      ],
    );

    final byId = <String, Event>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        byId[doc.id] = Event.fromMap(doc.id, doc.data());
      }
    }
    final results = withoutEnded(byId.values, now)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return results;
  }

  @override
  Future<Event?> getById(String id) async {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.getById(id);
    }
    final doc = await _remote.fetchById(id);
    final data = doc.data();
    if (data == null) return null;
    return Event.fromMap(doc.id, data);
  }

  @override
  Stream<Event?> watchById(String id) {
    if (!kUseFirebaseRepos || _remote == null) {
      return InMemoryEventsStore.instance.watchById(id);
    }
    return _remote.watchById(id).map((doc) {
      final data = doc.data();
      return data == null ? null : Event.fromMap(doc.id, data);
    });
  }

  @override
  Future<Event> joinEvent(String eventId, UserSummary user) async {
    if (!kUseFirebaseRepos || _remote == null) {
      final store = InMemoryEventsStore.instance;
      final current = store.getById(eventId);
      if (current == null) {
        throw StateError('Evento $eventId não encontrado');
      }
      if (current.isFull) throw const EventFullException();
      return store.join(eventId, user);
    }

    // Firestore: a transação do datasource valida vagas e registra o
    // UserSummary real do usuário autenticado atomicamente (RN-05).
    await _remote.join(eventId, user.toMap());

    // Re-fetch para retornar o estado atualizado.
    final updated = await _remote.fetchById(eventId);
    return Event.fromMap(updated.id, updated.data()!);
  }

  @override
  Future<Event> createEvent(
    Event draft, {
    required SportPlace selectedPlace,
  }) async {
    if (!kUseFirebaseRepos || _remote == null) {
      if (selectedPlace.status != PlaceStatus.active) {
        throw const EventPlaceUnavailableException();
      }
      if (!selectedPlace.sports.contains(draft.sport)) {
        throw const EventPlaceSportUnsupportedException();
      }
      if (draft.placeId != selectedPlace.id ||
          draft.placeSnapshot != EventPlaceSnapshot.fromPlace(selectedPlace)) {
        throw const EventPlaceChangedException();
      }
      return InMemoryEventsStore.instance.add(draft);
    }
    return _remote.create(draft, selectedPlace: selectedPlace);
  }
}
